//  WorldBracketPropagationTests.swift
//  SimVersusTests
//
//  Tests for materialize, result validation, round completion, and
//  full-bracket champion resolution (Commit 4).

import XCTest
@testable import SimVersus

final class WorldBracketPropagationTests: XCTestCase {

    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)

    // MARK: - Helpers

    private func makeBracket(seed: UInt64) throws -> WorldKnockoutBracket {
        let stage = try TournamentEngine.generateWorldGroupStage(
            definition: definition, catalog: catalog, tournamentSeed: seed)
        var results: [FixtureResult] = []
        for f in stage.fixtures {
            let raw = f.seed
            results.append(FixtureResult(
                fixtureID: f.id, homeScore: Int((raw >> 3) % 5),
                awayScore: Int((raw >> 7) % 5), winnerTeamID: nil,
                goals: [], isSimulated: true))
        }
        var standings: [String: [GroupStanding]] = [:]
        var allStandings: [GroupStanding] = []
        for group in stage.groups {
            let s = WorldGroupStageEngine.standings(
                for: group, fixtures: stage.fixtures, results: results,
                tournamentSeed: seed)
            standings[group.id] = s
            allStandings.append(contentsOf: s)
        }
        let bestThirds = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures, results: results,
            tournamentSeed: seed)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: stage.groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        return try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: allStandings, tournamentSeed: seed)
    }

    /// Returns a decisive regulation result for a knockout fixture.
    private func knockoutResult(for fixture: Fixture, homeWins: Bool) -> FixtureResult {
        let winner = homeWins ? fixture.homeTeamID : fixture.awayTeamID
        return FixtureResult(
            fixtureID: fixture.id,
            homeScore: homeWins ? 2 : 1,
            awayScore: homeWins ? 1 : 2,
            winnerTeamID: winner,
            goals: [], isSimulated: true,
            resolution: .regulation,
            homePenaltyScore: nil, awayPenaltyScore: nil)
    }

    /// Builds a SlotResolutionContext from knockout results.
    private func makeContext(results: [FixtureResult]) -> TournamentEngine.SlotResolutionContext {
        TournamentEngine.SlotResolutionContext(
            groupRankings: [],
            bestThirdPlacedTeamIDs: [],
            fixtureResults: Dictionary(uniqueKeysWithValues: results.map { ($0.fixtureID, $0) }))
    }

    // MARK: - Materialize tests

    func testMaterializeResolvesWinnerSource() throws {
        let bracket = try makeBracket(seed: 42)
        // Play one R32 match.
        let r32m1 = bracket.r32Fixtures[0]
        let result = knockoutResult(for: r32m1, homeWins: true)
        let context = makeContext(results: [result])
        let updated = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        // The corresponding R16 fixture should now have the winner in one slot.
        let r16m1 = updated.first { $0.id == "WA-R16-M1" }!
        XCTAssertTrue(r16m1.homeTeamID == r32m1.homeTeamID
                      || r16m1.awayTeamID == r32m1.homeTeamID,
                      "R16-M1 should inherit the R32-M1 winner")
    }

    func testMaterializeIsIdempotent() throws {
        let bracket = try makeBracket(seed: 42)
        let results = bracket.r32Fixtures.map { knockoutResult(for: $0, homeWins: ($0.matchIndex % 2 == 0)) }
        let context = makeContext(results: results)
        let a = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        let b = WorldBracketResolver.materialize(a, context: context)
        // Second call should produce identical result.
        for i in a.indices {
            XCTAssertEqual(a[i].homeTeamID, b[i].homeTeamID,
                           "Mismatch at fixture \(a[i].id)")
            XCTAssertEqual(a[i].awayTeamID, b[i].awayTeamID)
        }
    }

    func testMissingWinnerKeepsSlotUnresolved() throws {
        let bracket = try makeBracket(seed: 42)
        // Play R32-M1 with a DRAW (nil winner) — shouldn't happen in knockout,
        // but tests that materialize doesn't fabricate a winner.
        let r32m1 = bracket.r32Fixtures[0]
        let drawResult = FixtureResult(
            fixtureID: r32m1.id, homeScore: 1, awayScore: 1,
            winnerTeamID: nil, goals: [], isSimulated: true)
        let context = makeContext(results: [drawResult])
        let updated = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        // R16-M1 should still be TBD because there's no winner.
        let r16m1 = updated.first { $0.id == "WA-R16-M1" }!
        XCTAssertEqual(r16m1.homeTeamID, "TBD")
    }

    func testAfterTwoLinkedR32ResultsR16BecomesPlayable() throws {
        let bracket = try makeBracket(seed: 42)
        let r32m1 = bracket.r32Fixtures.first { $0.id == "WA-R32-M1" }!
        let r32m2 = bracket.r32Fixtures.first { $0.id == "WA-R32-M2" }!
        let results = [
            knockoutResult(for: r32m1, homeWins: true),
            knockoutResult(for: r32m2, homeWins: false),
        ]
        let context = makeContext(results: results)
        let updated = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        let r16m1 = updated.first { $0.id == "WA-R16-M1" }!
        // Both slots should now be concrete.
        XCTAssertNotEqual(r16m1.homeTeamID, "TBD")
        XCTAssertNotEqual(r16m1.awayTeamID, "TBD")
        XCTAssertNotEqual(r16m1.homeTeamID, r16m1.awayTeamID)
    }

    // MARK: - Round completion

    func testIsRoundCompleteAfterAllFixturesPlayed() throws {
        let bracket = try makeBracket(seed: 42)
        let results = bracket.r32Fixtures.map { knockoutResult(for: $0, homeWins: true) }
        XCTAssertTrue(WorldBracketResolver.isRoundComplete(1, bracket: bracket, results: results))
    }

    func testIsRoundCompleteFalseWhenPartial() throws {
        let bracket = try makeBracket(seed: 42)
        let partial = [knockoutResult(for: bracket.r32Fixtures[0], homeWins: true)]
        XCTAssertFalse(WorldBracketResolver.isRoundComplete(1, bracket: bracket, results: partial))
    }

    func testNextPlayableFixturesOnlyUnplayedResolved() throws {
        let bracket = try makeBracket(seed: 42)
        // No results yet — R32 is playable (all concrete teams).
        let playable = WorldBracketResolver.nextPlayableFixtures(
            in: bracket, results: [])
        XCTAssertEqual(playable.count, 16)
        XCTAssertTrue(playable.allSatisfy { $0.round == 1 })
    }

    func testNextPlayableReturnsNextRoundAfterR32Complete() throws {
        let bracket = try makeBracket(seed: 42)
        let results = bracket.r32Fixtures.map { knockoutResult(for: $0, homeWins: true) }
        let context = makeContext(results: results)
        let updated = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        let updatedBracket = WorldKnockoutBracket(
            fixtures: updated,
            createdFromTournamentSeed: bracket.createdFromTournamentSeed,
            qualifierTeamIDs: bracket.qualifierTeamIDs)
        let playable = WorldBracketResolver.nextPlayableFixtures(
            in: updatedBracket, results: results)
        // All R16 fixtures should now be playable.
        XCTAssertEqual(playable.count, 8)
        XCTAssertTrue(playable.allSatisfy { $0.round == 2 })
    }

    // MARK: - Champion

    func testChampionNilBeforeFinal() throws {
        let bracket = try makeBracket(seed: 42)
        XCTAssertNil(WorldBracketResolver.championTeamID(in: bracket, results: []))
    }

    func testChampionAfterFinalResult() throws {
        let bracket = try makeBracket(seed: 42)
        guard let final = bracket.final else { XCTFail("No final"); return }
        let result = knockoutResult(for: final, homeWins: true)
        let champion = WorldBracketResolver.championTeamID(in: bracket, results: [result])
        XCTAssertEqual(champion, final.homeTeamID)
    }

    // MARK: - Validator tests

    func testValidatorAcceptsValidResult() throws {
        let bracket = try makeBracket(seed: 42)
        let r32m1 = bracket.r32Fixtures[0]
        let result = knockoutResult(for: r32m1, homeWins: true)
        XCTAssertNoThrow(try WorldBracketValidator.validate(
            result, against: bracket, existingResults: []))
    }

    func testValidatorRejectsUnknownFixture() throws {
        let bracket = try makeBracket(seed: 42)
        let badResult = FixtureResult(
            fixtureID: "nonexistent", homeScore: 2, awayScore: 1,
            winnerTeamID: "X", goals: [], isSimulated: true)
        XCTAssertThrowsError(try WorldBracketValidator.validate(
            badResult, against: bracket, existingResults: [])) { error in
            guard case .invalidResult = error as? WorldBracketError else {
                XCTFail("Expected invalidResult"); return
            }
        }
    }

    func testValidatorRejectsInvalidWinner() throws {
        let bracket = try makeBracket(seed: 42)
        let r32m1 = bracket.r32Fixtures[0]
        let badResult = FixtureResult(
            fixtureID: r32m1.id, homeScore: 2, awayScore: 1,
            winnerTeamID: "not-a-team-in-this-fixture",
            goals: [], isSimulated: true)
        XCTAssertThrowsError(try WorldBracketValidator.validate(
            badResult, against: bracket, existingResults: [])) { error in
            guard case .invalidResult = error as? WorldBracketError else {
                XCTFail("Expected invalidResult"); return
            }
        }
    }

    func testValidatorAllowsIdenticalDuplicate() throws {
        let bracket = try makeBracket(seed: 42)
        let r32m1 = bracket.r32Fixtures[0]
        let result = knockoutResult(for: r32m1, homeWins: true)
        try WorldBracketValidator.validate(result, against: bracket, existingResults: [result])
        // Should not throw for identical result.
    }

    func testValidatorRejectsConflictingDuplicate() throws {
        let bracket = try makeBracket(seed: 42)
        let r32m1 = bracket.r32Fixtures[0]
        let first = FixtureResult(
            fixtureID: r32m1.id, homeScore: 3, awayScore: 0,
            winnerTeamID: r32m1.homeTeamID, goals: [], isSimulated: true)
        let second = FixtureResult(
            fixtureID: r32m1.id, homeScore: 0, awayScore: 3,
            winnerTeamID: r32m1.awayTeamID, goals: [], isSimulated: true)
        try WorldBracketValidator.validate(first, against: bracket, existingResults: [])
        XCTAssertThrowsError(try WorldBracketValidator.validate(
            second, against: bracket, existingResults: [first])) { error in
            guard case .invalidResult = error as? WorldBracketError else {
                XCTFail("Expected invalidResult"); return
            }
        }
    }

    // MARK: - Full bracket simulation

    /// Runs a full knockout bracket, playing every fixture and returning the champion.
    private func runFullBracket(seed: UInt64) throws -> (bracket: WorldKnockoutBracket, champion: String) {
        let bracket = try makeBracket(seed: seed)
        var results: [FixtureResult] = []
        var fixtures = bracket.fixtures

        for round in 1...5 {
            // Materialize FIRST so all slots are concrete before we try to play.
            let context = makeContext(results: results)
            fixtures = WorldBracketResolver.materialize(fixtures, context: context)

            // Now get the (freshly materialized) round fixtures.
            let currentRoundFixtures = fixtures.filter { $0.round == round }
            guard !currentRoundFixtures.isEmpty else { break }

            // Play each fixture in this round.
            for f in currentRoundFixtures {
                guard f.homeTeamID != "TBD", f.awayTeamID != "TBD" else {
                    // If still TBD after materialize, the referenced fixture's
                    // result is missing — skip (shouldn't happen if all previous
                    // rounds are played).
                    continue
                }
                // Home wins if matchIndex is even (deterministic rule).
                let result = knockoutResult(for: f, homeWins: (f.matchIndex % 2 == 0))
                results.append(result)
            }
        }

        let updatedBracket = WorldKnockoutBracket(
            fixtures: fixtures,
            createdFromTournamentSeed: bracket.createdFromTournamentSeed,
            qualifierTeamIDs: bracket.qualifierTeamIDs)
        guard let champion = WorldBracketResolver.championTeamID(
            in: updatedBracket, results: results) else {
            throw WorldBracketError.unresolvedSlot("No champion after full bracket")
        }
        return (updatedBracket, champion)
    }

    func testFullBracketProducesExactlyOneChampion() throws {
        let (_, champion) = try runFullBracket(seed: 42)
        XCTAssertFalse(champion.isEmpty)
        XCTAssertNotEqual(champion, "TBD")
    }

    func testSameTournamentSeedSameChampion() throws {
        let a = try runFullBracket(seed: 100)
        let b = try runFullBracket(seed: 100)
        XCTAssertEqual(a.champion, b.champion,
                       "Same seed must produce same champion")
    }

    func testTwentyFullBracketsComplete() throws {
        for seed in 1...20 {
            let (bracket, champion) = try runFullBracket(seed: UInt64(seed))
            XCTAssertFalse(champion.isEmpty, "Seed \(seed): empty champion")
            // Champion should be one of the 32 qualifiers.
            XCTAssertTrue(bracket.qualifierTeamIDs.contains(champion),
                          "Seed \(seed): champion \(champion) not in qualifiers")
        }
    }
}
