//  WorldGroupDrawTests.swift
//  SimVersusTests
//
//  Commit 3A — the deterministic 48-team World Arena group draw.

import XCTest
@testable import SimVersus

final class WorldGroupDrawTests: XCTestCase {
    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)
    private let seed: UInt64 = 0xA11CE

    private func draw(_ s: UInt64) throws -> [GroupAssignment] {
        try WorldGroupStageEngine.drawGroups(definition: definition,
                                             teams: catalog.allTeams,
                                             tournamentSeed: s)
    }

    func testTwelveGroups() throws {
        XCTAssertEqual(try draw(seed).count, 12)
    }

    func testGroupIDsAreAtoL() throws {
        XCTAssertEqual(try draw(seed).map(\.id), Array("ABCDEFGHIJKL").map(String.init))
    }

    func testFourTeamsPerGroup() throws {
        XCTAssertTrue(try draw(seed).allSatisfy { $0.teamIDs.count == 4 })
    }

    func testFortyEightUniqueTeams() throws {
        let ids = try draw(seed).flatMap(\.teamIDs)
        XCTAssertEqual(ids.count, 48)
        XCTAssertEqual(Set(ids).count, 48)
    }

    func testEachGroupHasOneTeamFromEachPot() throws {
        let potByID = Dictionary(uniqueKeysWithValues: catalog.allTeams.map { ($0.id, $0.pot) })
        for group in try draw(seed) {
            let pots = group.teamIDs.compactMap { potByID[$0] }.sorted()
            XCTAssertEqual(pots, [1, 2, 3, 4], "group \(group.id) must hold one team per pot")
        }
    }

    func testSameSeedProducesIdenticalGroups() throws {
        XCTAssertEqual(try draw(seed), try draw(seed))
    }

    func testDifferentSeedChangesAtLeastOneGroup() throws {
        XCTAssertNotEqual(try draw(0x1111), try draw(0x2222))
    }

    func testMalformedDefinitionThrows() {
        // A standard club definition has no pots → not a valid World Arena draw.
        let bad = TournamentDefinitionAdapter.adapt(.grand)
        XCTAssertThrowsError(try WorldGroupStageEngine.drawGroups(
            definition: bad, teams: catalog.allTeams, tournamentSeed: seed))
    }
}
