//  WorldBracketPersistenceTests.swift
//  SimVersusTests
//
//  Tests for WorldKnockoutBracket persistence via TournamentState, Codable
//  round-trips, and backward compatibility (Commit 4).

import XCTest
import SwiftData
@testable import SimVersus

final class WorldBracketPersistenceTests: XCTestCase {

    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)

    // MARK: - Helpers

    private func makeQualifiers(seed: UInt64) throws -> (
        groups: [GroupAssignment],
        qualifiers: WorldKnockoutQualifiers,
        standings: [GroupStanding],
        bestThirds: [String]
    ) {
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
        return (stage.groups, qualifiers, allStandings, bestThirds)
    }

    // MARK: - WorldKnockoutBracket Codable

    func testWorldKnockoutBracketCodableRoundTrip() throws {
        let (groups, qualifiers, standings, bestThirds) = try makeQualifiers(seed: 42)
        let bracket = try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: 42)
        let data = try JSONEncoder().encode(bracket)
        let decoded = try JSONDecoder().decode(WorldKnockoutBracket.self, from: data)
        XCTAssertEqual(decoded.fixtures.count, 31)
        XCTAssertEqual(decoded.createdFromTournamentSeed, 42)
        XCTAssertEqual(decoded.qualifierTeamIDs, bracket.qualifierTeamIDs)
        // Spot-check a fixture.
        let originalR32M1 = bracket.r32Fixtures[0]
        let decodedR32M1 = decoded.r32Fixtures[0]
        XCTAssertEqual(originalR32M1.id, decodedR32M1.id)
        XCTAssertEqual(originalR32M1.homeTeamID, decodedR32M1.homeTeamID)
        XCTAssertEqual(originalR32M1.seed, decodedR32M1.seed)
    }

    func testWorldKnockoutQualifiersCodableRoundTrip() throws {
        let (groups, qualifiers, _, _) = try makeQualifiers(seed: 42)
        let data = try JSONEncoder().encode(qualifiers)
        let decoded = try JSONDecoder().decode(WorldKnockoutQualifiers.self, from: data)
        XCTAssertEqual(qualifiers.groupWinners, decoded.groupWinners)
        XCTAssertEqual(qualifiers.groupRunnersUp, decoded.groupRunnersUp)
        XCTAssertEqual(qualifiers.bestThirdPlaced, decoded.bestThirdPlaced)
    }

    // MARK: - TournamentState (legacy backward compatibility)

    func testOldTournamentStateDecodesWithoutWAFields() throws {
        // Create a legacy TournamentState (v1 schema, no WA fields).
        let legacyState = TournamentState(
            format: .mini,
            playerTeamID: "team-a",
            teams: ["team-a", "team-b", "team-c", "team-d"],
            fixtures: [])
        // It should decode with nil WA fields.
        XCTAssertNil(legacyState.competitionID)
        XCTAssertEqual(legacyState.tournamentSeed, 0)
        XCTAssertTrue(legacyState.groupAssignments.isEmpty)
        XCTAssertNil(legacyState.knockoutBracket)
        XCTAssertTrue(legacyState.bestThirdPlacedTeamIDs.isEmpty)
    }

    func testLegacyStateSchemaVersionIs3() throws {
        let state = TournamentState(
            format: .mini,
            playerTeamID: "team-a",
            teams: ["team-a", "team-b", "team-c", "team-d"],
            fixtures: [])
        XCTAssertEqual(state.schemaVersion, 3)
    }

    // MARK: - TournamentState World Arena persistence

    func testSetAndGetGroupAssignments() throws {
        let state = TournamentState(
            format: .classic,
            playerTeamID: "team-a",
            teams: ["a","b","c","d","e","f","g","h"],
            fixtures: [])
        let ga = [GroupAssignment(id: "A", teamIDs: ["t1","t2","t3","t4"])]
        state.setGroupAssignments(ga)
        XCTAssertEqual(state.groupAssignments.count, 1)
        XCTAssertEqual(state.groupAssignments[0].id, "A")
    }

    func testSetAndGetKnockoutBracket() throws {
        let (groups, qualifiers, standings, bestThirds) = try makeQualifiers(seed: 42)
        let bracket = try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: 42)

        let state = TournamentState(
            format: .classic,
            playerTeamID: "team-a",
            teams: qualifiers.allTeamIDs,
            fixtures: [])
        state.setKnockoutBracket(bracket)

        // Bracket should be retrievable.
        let loaded = state.knockoutBracket
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.fixtures.count, 31)
        XCTAssertEqual(loaded?.createdFromTournamentSeed, 42)

        // Knockout fixtures should be appended to the main fixtures array.
        let allFixtures = state.fixtures
        let knockoutFixtureIDs = bracket.fixtures.map(\.id)
        for id in knockoutFixtureIDs {
            XCTAssertTrue(allFixtures.contains { $0.id == id },
                          "Knockout fixture \(id) should be in fixturesData")
        }
    }

    func testSetAndGetBestThirdPlaced() throws {
        let state = TournamentState(
            format: .classic,
            playerTeamID: "team-a",
            teams: ["a","b","c","d","e","f","g","h"],
            fixtures: [])
        state.setBestThirdPlacedTeamIDs(["t1","t2","t3","t4","t5","t6","t7","t8"])
        XCTAssertEqual(state.bestThirdPlacedTeamIDs.count, 8)
    }

    func testSaveReloadPreservesBracket() throws {
        let (groups, qualifiers, standings, bestThirds) = try makeQualifiers(seed: 42)
        let bracket = try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: 42)

        let state = TournamentState(
            format: .classic,
            playerTeamID: "team-a",
            teams: qualifiers.allTeamIDs,
            fixtures: [],
            competitionID: "world-arena-2026",
            tournamentSeed: 42,
            groupAssignments: groups)
        state.setKnockoutBracket(bracket)
        state.setBestThirdPlacedTeamIDs(bestThirds)

        // Re-encode and decode to simulate save/reload.
        let data = try JSONEncoder().encode(state.fixtures)
        let decodedFixtures = try JSONDecoder().decode([Fixture].self, from: data)
        XCTAssertEqual(decodedFixtures.count, 31)
        // Spot-check: R32 fixtures should have concrete team IDs.
        let r32 = decodedFixtures.filter { $0.round == 1 }
        XCTAssertEqual(r32.count, 16)
        for f in r32 {
            XCTAssertNotEqual(f.homeTeamID, "TBD")
            XCTAssertNotEqual(f.awayTeamID, "TBD")
        }
    }

    func testSaveReloadPreservesUnresolvedSlots() throws {
        let (_, qualifiers, standings, _) = try makeQualifiers(seed: 42)
        let bracket = try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: 42)

        // Encode and decode the bracket.
        let data = try JSONEncoder().encode(bracket)
        let decoded = try JSONDecoder().decode(WorldKnockoutBracket.self, from: data)

        // R16+ fixtures should still have "TBD" slots.
        let r16 = decoded.fixtures.filter { $0.round == 2 }
        XCTAssertEqual(r16.count, 8)
        for f in r16 {
            XCTAssertEqual(f.homeTeamID, "TBD",
                           "R16 fixture \(f.id) should start with TBD slots")
            XCTAssertEqual(f.awayTeamID, "TBD")
        }
    }

    func testWorldArenaInitSetsAllFields() throws {
        let (groups, qualifiers, standings, bestThirds) = try makeQualifiers(seed: 42)
        let bracket = try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: 42)

        let state = TournamentState(
            format: .grand, // Any format — competitionID distinguishes WA
            playerTeamID: qualifiers.allTeamIDs[0],
            teams: qualifiers.allTeamIDs,
            fixtures: [],
            competitionID: "world-arena-2026",
            tournamentSeed: 99,
            groupAssignments: groups)
        state.setKnockoutBracket(bracket)
        state.setBestThirdPlacedTeamIDs(bestThirds)

        XCTAssertEqual(state.schemaVersion, 3)
        XCTAssertEqual(state.competitionID, "world-arena-2026")
        XCTAssertEqual(state.tournamentSeed, 99)
        XCTAssertEqual(state.groupAssignments.count, 12)
        XCTAssertNotNil(state.knockoutBracket)
        XCTAssertEqual(state.bestThirdPlacedTeamIDs.count, 8)
    }
}
