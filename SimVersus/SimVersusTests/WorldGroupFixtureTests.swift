//  WorldGroupFixtureTests.swift
//  SimVersusTests
//
//  Commit 3A — the 72-fixture group schedule and the WorldGroupStage aggregate.

import XCTest
@testable import SimVersus

final class WorldGroupFixtureTests: XCTestCase {
    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)
    private let seed: UInt64 = 0xF1C7

    private func stage(_ s: UInt64) throws -> WorldGroupStage {
        try TournamentEngine.generateWorldGroupStage(definition: definition,
                                                     catalog: catalog,
                                                     tournamentSeed: s)
    }

    func testAggregateShape() throws {
        let stage = try stage(seed)
        XCTAssertEqual(stage.groups.count, 12)
        XCTAssertEqual(stage.fixtures.count, 72)
    }

    func testSixFixturesPerGroup() throws {
        let byGroup = Dictionary(grouping: try stage(seed).fixtures, by: { $0.groupIndex })
        XCTAssertEqual(byGroup.count, 12)
        XCTAssertTrue(byGroup.values.allSatisfy { $0.count == 6 })
    }

    func testThreeMatchdaysTwoMatchesEach() throws {
        for fixtures in Dictionary(grouping: try stage(seed).fixtures, by: { $0.groupIndex }).values {
            let byMatchday = Dictionary(grouping: fixtures, by: { $0.matchday ?? -1 })
            XCTAssertEqual(Set(byMatchday.keys), [1, 2, 3])
            XCTAssertTrue(byMatchday.values.allSatisfy { $0.count == 2 })
        }
    }

    func testEveryTeamPlaysExactlyThreeAndNeverTwiceInAMatchday() throws {
        for fixtures in Dictionary(grouping: try stage(seed).fixtures, by: { $0.groupIndex }).values {
            var appearances: [String: Int] = [:]
            for f in fixtures {
                appearances[f.homeTeamID, default: 0] += 1
                appearances[f.awayTeamID, default: 0] += 1
            }
            XCTAssertEqual(appearances.count, 4)
            XCTAssertTrue(appearances.values.allSatisfy { $0 == 3 })

            for md in 1...3 {
                let day = fixtures.filter { $0.matchday == md }
                let teams = day.flatMap { [$0.homeTeamID, $0.awayTeamID] }
                XCTAssertEqual(Set(teams).count, teams.count, "a team plays twice on matchday \(md)")
            }
        }
    }

    func testFixtureIDsUniqueAndReadable() throws {
        let fixtures = try stage(seed).fixtures
        let ids = fixtures.map(\.id)
        XCTAssertEqual(Set(ids).count, 72)
        XCTAssertTrue(ids.allSatisfy { $0.hasPrefix("WA-G") })
        XCTAssertTrue(ids.contains("WA-GA-MD1-M1"))
        XCTAssertTrue(ids.contains("WA-GL-MD3-M2"))
    }

    func testAllSeedsNonzero() throws {
        XCTAssertTrue(try stage(seed).fixtures.allSatisfy { $0.seed != 0 })
    }

    func testAllGroupSlotsAreConcreteTeams() throws {
        for f in try stage(seed).fixtures {
            XCTAssertEqual(f.round, 0)
            XCTAssertNotNil(f.matchday)
            XCTAssertNotEqual(f.homeTeamID, "TBD")
            XCTAssertNotEqual(f.awayTeamID, "TBD")
            if case .team = f.homeSource {} else { XCTFail("home slot not concrete") }
            if case .team = f.awaySource {} else { XCTFail("away slot not concrete") }
        }
    }

    func testHomeAwayBalancePerGroup() throws {
        // Balanced single round-robin: two teams host twice, two host once.
        for fixtures in Dictionary(grouping: try stage(seed).fixtures, by: { $0.groupIndex }).values {
            var homeCount: [String: Int] = [:]
            for f in fixtures { homeCount[f.homeTeamID, default: 0] += 1 }
            XCTAssertEqual(homeCount.values.sorted(), [1, 1, 2, 2])
        }
    }

    func testSameSeedProducesIdenticalStage() throws {
        XCTAssertEqual(try stage(seed), try stage(seed))
    }

    func testWorldGroupStageCodableRoundTrips() throws {
        let original = try stage(seed)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WorldGroupStage.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testLegacyFixtureWithoutMatchdayStillDecodes() throws {
        // A pre-Commit-3 fixture JSON has no "matchday" key; it must decode to nil.
        let legacy = #"{"id":"G0-M0","homeTeamID":"a","awayTeamID":"b","round":0,"matchIndex":0,"seed":42}"#
        let f = try JSONDecoder().decode(Fixture.self, from: Data(legacy.utf8))
        XCTAssertNil(f.matchday)
        XCTAssertEqual(f.id, "G0-M0")
    }
}
