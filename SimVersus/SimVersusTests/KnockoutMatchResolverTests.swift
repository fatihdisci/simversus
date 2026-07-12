//  KnockoutMatchResolverTests.swift
//  SimVersusTests
//
//  Commit 3B — deterministic knockout resolution (regulation / extra time /
//  penalties) and the backward-compatible FixtureResult migration.

import XCTest
@testable import SimVersus

final class KnockoutMatchResolverTests: XCTestCase {
    private let catalog = NationalTeamStore()
    private lazy var home = catalog.allTeams[0].asTeam
    private lazy var away = catalog.allTeams[1].asTeam
    private let seed: UInt64 = 0x0DDBA11

    private func fixture(_ id: String = "WA-R32-M0") -> Fixture {
        Fixture(id: id, homeTeamID: home.id, awayTeamID: away.id,
                round: 1, groupIndex: nil, matchIndex: 0, seed: 42)
    }

    private func regulation(_ h: Int, _ a: Int) -> MatchResult {
        MatchResult(homeTeamID: home.id, awayTeamID: away.id, homeScore: h, awayScore: a, goals: [])
    }

    // MARK: - Regulation

    func testDecisiveRegulationKeepsResultAndWinner() {
        let outcome = KnockoutMatchResolver.resolve(
            fixture: fixture(), homeTeam: home, awayTeam: away,
            regulationResult: regulation(2, 1), tournamentSeed: seed)
        XCTAssertEqual(outcome.winnerTeamID, home.id)
        XCTAssertEqual(outcome.fixtureResult.resolution, .regulation)
        XCTAssertEqual(outcome.fixtureResult.homeScore, 2)
        XCTAssertEqual(outcome.fixtureResult.awayScore, 1)
        XCTAssertNil(outcome.fixtureResult.homePenaltyScore)
        XCTAssertNil(outcome.fixtureResult.awayPenaltyScore)
    }

    func testAwayRegulationWinner() {
        let outcome = KnockoutMatchResolver.resolve(
            fixture: fixture(), homeTeam: home, awayTeam: away,
            regulationResult: regulation(0, 3), tournamentSeed: seed)
        XCTAssertEqual(outcome.winnerTeamID, away.id)
        XCTAssertEqual(outcome.fixtureResult.resolution, .regulation)
    }

    // MARK: - Draw always resolves

    func testRegulationDrawAlwaysProducesConcreteWinner() {
        // Try many fixtures/seeds — a drawn regulation must never stay drawn.
        for i in 0..<40 {
            let outcome = KnockoutMatchResolver.resolve(
                fixture: fixture("WA-R32-M\(i)"), homeTeam: home, awayTeam: away,
                regulationResult: regulation(1, 1), tournamentSeed: seed &+ UInt64(i))
            XCTAssertTrue([home.id, away.id].contains(outcome.winnerTeamID))
            XCTAssertNotEqual(outcome.fixtureResult.resolution, .regulation)
            if outcome.fixtureResult.resolution == .penalties {
                XCTAssertNotNil(outcome.fixtureResult.homePenaltyScore)
                XCTAssertNotNil(outcome.fixtureResult.awayPenaltyScore)
                XCTAssertNotEqual(outcome.fixtureResult.homePenaltyScore,
                                  outcome.fixtureResult.awayPenaltyScore)
            } else {
                XCTAssertEqual(outcome.fixtureResult.resolution, .extraTime)
                XCTAssertNil(outcome.fixtureResult.homePenaltyScore)
                XCTAssertNil(outcome.fixtureResult.awayPenaltyScore)
            }
            // The stored scoreline stays the regulation draw.
            XCTAssertEqual(outcome.fixtureResult.homeScore, outcome.fixtureResult.awayScore)
        }
    }

    func testSameFixtureAndSeedGiveSameResolution() {
        let a = KnockoutMatchResolver.resolve(
            fixture: fixture(), homeTeam: home, awayTeam: away,
            regulationResult: regulation(1, 1), tournamentSeed: seed)
        let b = KnockoutMatchResolver.resolve(
            fixture: fixture(), homeTeam: home, awayTeam: away,
            regulationResult: regulation(1, 1), tournamentSeed: seed)
        XCTAssertEqual(a, b)
    }

    // MARK: - Penalty shootout (direct)

    func testShootoutIsAlwaysDecisiveAndDeterministic() {
        for i in 0..<200 {
            let id = "WA-R32-M\(i)"
            let s = KnockoutMatchResolver.resolvePenalties(fixtureID: id, tournamentSeed: seed)
            XCTAssertNotEqual(s.home, s.away, "shootout \(id) ended level")
            XCTAssertEqual(s.home >= 0 && s.away >= 0, true)
            // Deterministic.
            XCTAssertTrue(KnockoutMatchResolver.resolvePenalties(fixtureID: id, tournamentSeed: seed) == s)
        }
    }

    func testShootoutProbabilityIsSymmetric() {
        var homeWins = 0, awayWins = 0
        for i in 0..<1000 {
            let s = KnockoutMatchResolver.resolvePenalties(fixtureID: "sym-\(i)", tournamentSeed: seed)
            if s.home > s.away { homeWins += 1 } else { awayWins += 1 }
        }
        let ratio = Double(homeWins) / Double(homeWins + awayWins)
        XCTAssertGreaterThan(ratio, 0.42)
        XCTAssertLessThan(ratio, 0.58)
    }

    // MARK: - FixtureResult migration

    func testLegacyFixtureResultDecodesAsRegulation() throws {
        // A pre-Commit-3 result JSON: no resolution / penalty keys.
        let legacy = #"{"fixtureID":"G0-M0","homeScore":2,"awayScore":1,"winnerTeamID":"a","goals":[],"isSimulated":true}"#
        let decoded = try JSONDecoder().decode(FixtureResult.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.resolution, .regulation)
        XCTAssertNil(decoded.homePenaltyScore)
        XCTAssertNil(decoded.awayPenaltyScore)
        XCTAssertEqual(decoded.winnerTeamID, "a")
    }

    func testPenaltyResultRoundTripsThroughCodable() throws {
        var result = FixtureResult(fixtureID: "WA-R32-M0", homeScore: 1, awayScore: 1,
                                   winnerTeamID: home.id, goals: [], isSimulated: true)
        result.resolution = .penalties
        result.homePenaltyScore = 4
        result.awayPenaltyScore = 3
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(FixtureResult.self, from: data)
        XCTAssertEqual(decoded, result)
        XCTAssertEqual(decoded.resolution, .penalties)
        XCTAssertEqual(decoded.homePenaltyScore, 4)
        XCTAssertEqual(decoded.awayPenaltyScore, 3)
    }

    // MARK: - Typed slot resolution (Part I)

    func testTypedWinnerSlotResolves() {
        let result = FixtureResult(fixtureID: "WA-R32-M0", homeScore: 2, awayScore: 1,
                                   winnerTeamID: "team-x", goals: [], isSimulated: true)
        let context = TournamentEngine.SlotResolutionContext(
            groupRankings: [["a", "b"], ["c", "d"]],
            bestThirdPlacedTeamIDs: ["e", "f"],
            fixtureResults: ["WA-R32-M0": result])
        XCTAssertEqual(TournamentEngine.resolveSlot(.winner(of: "WA-R32-M0"), context: context),
                       .resolved("team-x"))
        XCTAssertEqual(TournamentEngine.resolveSlot(.groupRank(groupIndex: 1, rank: 0), context: context),
                       .resolved("c"))
        XCTAssertEqual(TournamentEngine.resolveSlot(.bestThirdPlace(rank: 1), context: context),
                       .resolved("f"))
        XCTAssertEqual(TournamentEngine.resolveSlot(.winner(of: "missing"), context: context),
                       .unresolved)
        XCTAssertEqual(TournamentEngine.resolveSlot(.groupRank(groupIndex: 9, rank: 0), context: context),
                       .unresolved)
        XCTAssertEqual(TournamentEngine.resolveSlot(.pending, context: context), .unresolved)
    }
}
