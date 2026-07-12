//  WorldKnockoutQualifierTests.swift
//  SimVersusTests
//
//  Tests for WorldKnockoutQualifiers extraction and validation (Commit 4).

import XCTest
@testable import SimVersus

final class WorldKnockoutQualifierTests: XCTestCase {

    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)

    // MARK: - Helpers

    /// Runs a full group stage and returns standings per group plus the best-third list.
    private func runGroupStage(seed: UInt64) throws -> (
        groups: [GroupAssignment],
        standings: [String: [GroupStanding]],
        bestThirds: [String],
        fixtures: [Fixture],
        results: [FixtureResult]
    ) {
        let stage = try TournamentEngine.generateWorldGroupStage(
            definition: definition, catalog: catalog, tournamentSeed: seed)
        let groups = stage.groups
        var allFixtures = stage.fixtures

        // Simulate all 72 group fixtures.
        var results: [FixtureResult] = []
        for f in allFixtures {
            let result = syntheticResult(for: f)
            results.append(result)
        }

        // Compute standings for each group.
        var standings: [String: [GroupStanding]] = [:]
        for group in groups {
            standings[group.id] = WorldGroupStageEngine.standings(
                for: group, fixtures: allFixtures, results: results,
                tournamentSeed: seed)
        }
        let bestThirds = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: groups, fixtures: allFixtures, results: results,
            tournamentSeed: seed)

        return (groups, standings, bestThirds, allFixtures, results)
    }

    /// Produces a deterministic result from a fixture's seed without physics.
    private func syntheticResult(for fixture: Fixture) -> FixtureResult {
        let raw = fixture.seed
        let homeScore = Int((raw >> 3) % 5)
        let awayScore = Int((raw >> 7) % 5)
        let winner: String? = homeScore > awayScore ? fixture.homeTeamID
            : awayScore > homeScore ? fixture.awayTeamID : nil
        return FixtureResult(
            fixtureID: fixture.id, homeScore: homeScore, awayScore: awayScore,
            winnerTeamID: winner, goals: [], isSimulated: true,
            resolution: .regulation, homePenaltyScore: nil, awayPenaltyScore: nil)
    }

    // MARK: - Count tests

    func testTwelveGroupWinners() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        XCTAssertEqual(qualifiers.groupWinners.count, 12)
    }

    func testTwelveRunnersUp() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        XCTAssertEqual(qualifiers.groupRunnersUp.count, 12)
    }

    func testEightBestThirds() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        XCTAssertEqual(qualifiers.bestThirdPlaced.count, 8)
    }

    func testAllThirtyTwoUnique() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        let all = qualifiers.allTeamIDs
        XCTAssertEqual(all.count, 32)
        XCTAssertEqual(Set(all).count, 32, "All 32 qualifiers must be unique")
    }

    // MARK: - Uniqueness enforcement

    func testDuplicateTeamAcrossWinnersAndRunnersUpThrows() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        // Manually inject a duplicate: copy winner A into runners-up.
        var dupStandings = standings
        let winnerA = standings["A"]![0].teamID
        var groupA = dupStandings["A"]!
        groupA[1] = GroupStanding(teamID: winnerA, played: 3, wins: 1,
                                  draws: 1, losses: 1, goalsFor: 2,
                                  goalsAgainst: 2, points: 4, groupID: "A")
        dupStandings["A"] = groupA
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: dupStandings,
            bestThirdPlacedTeamIDs: bestThirds)) { error in
            guard case .duplicateQualifier = error as? WorldBracketError else {
                XCTFail("Expected duplicateQualifier, got \(error)")
                return
            }
        }
    }

    func testDuplicateBestThirdThrows() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        // Replace a best-third with a group winner.
        let dupThirds = Array(bestThirds.dropLast()) + [standings["A"]![0].teamID]
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: dupThirds)) { error in
            guard case .duplicateQualifier = error as? WorldBracketError else {
                XCTFail("Expected duplicateQualifier, got \(error)")
                return
            }
        }
    }

    // MARK: - Missing / incomplete group

    func testMissingGroupThrows() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        var partial = standings
        partial.removeValue(forKey: "C")
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: partial,
            bestThirdPlacedTeamIDs: bestThirds)) { error in
            guard case .missingGroup = error as? WorldBracketError else {
                XCTFail("Expected missingGroup, got \(error)")
                return
            }
        }
    }

    func testIncompleteGroupThrows() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        var partial = standings
        partial["D"] = [standings["D"]![0]] // only one team
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: partial,
            bestThirdPlacedTeamIDs: bestThirds)) { error in
            guard case .incompleteGroup = error as? WorldBracketError else {
                XCTFail("Expected incompleteGroup, got \(error)")
                return
            }
        }
    }

    // MARK: - Determinism

    func testSameSeedSameQualifiers() throws {
        let a = try runGroupStage(seed: 123)
        let b = try runGroupStage(seed: 123)
        let qa = try WorldKnockoutQualifiers.make(
            groups: a.groups, standingsByGroup: a.standings,
            bestThirdPlacedTeamIDs: a.bestThirds)
        let qb = try WorldKnockoutQualifiers.make(
            groups: b.groups, standingsByGroup: b.standings,
            bestThirdPlacedTeamIDs: b.bestThirds)
        XCTAssertEqual(qa, qb)
    }

    // MARK: - Order preservation

    func testWinnersOrderedByGroup() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        // Winners should be in A…L order.
        let expectedOrder = ["A","B","C","D","E","F","G","H","I","J","K","L"]
        for (i, groupID) in expectedOrder.enumerated() {
            let winner = qualifiers.groupWinners[i]
            let groupStanding = standings[groupID]!
            XCTAssertEqual(winner, groupStanding[0].teamID,
                           "Winner \(i) should be from group \(groupID)")
        }
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let (groups, standings, bestThirds, _, _) = try runGroupStage(seed: 42)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        let data = try JSONEncoder().encode(qualifiers)
        let decoded = try JSONDecoder().decode(WorldKnockoutQualifiers.self, from: data)
        XCTAssertEqual(qualifiers, decoded)
    }

    func testInvalidQualifierCountThrows() throws {
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: [], standingsByGroup: [:],
            bestThirdPlacedTeamIDs: [])) { error in
            guard case .invalidQualifierCount = error as? WorldBracketError else {
                XCTFail("Expected invalidQualifierCount, got \(error)")
                return
            }
        }
    }

    func testTooFewBestThirdsThrows() throws {
        let (groups, standings, _, _, _) = try runGroupStage(seed: 42)
        XCTAssertThrowsError(try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: ["a","b","c"])) { error in
            guard case .invalidQualifierCount = error as? WorldBracketError else {
                XCTFail("Expected invalidQualifierCount, got \(error)")
                return
            }
        }
    }
}
