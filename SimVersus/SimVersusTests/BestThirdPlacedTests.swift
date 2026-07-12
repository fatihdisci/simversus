//  BestThirdPlacedTests.swift
//  SimVersusTests
//
//  Commit 3A — ranking the twelve third-placed teams and picking the eight
//  best that qualify for the Round of 32.

import XCTest
@testable import SimVersus

final class BestThirdPlacedTests: XCTestCase {
    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)
    private let seed: UInt64 = 0xB3573

    private func drawnStage() throws -> WorldGroupStage {
        try TournamentEngine.generateWorldGroupStage(definition: definition,
                                                     catalog: catalog,
                                                     tournamentSeed: seed)
    }

    /// A deterministic scoreline for a fixture, derived from its own seed so the
    /// whole group stage is reproducible without running the physics engine.
    private func syntheticResult(for f: Fixture) -> FixtureResult {
        let h = Int(f.seed % 4)
        let a = Int((f.seed >> 8) % 4)
        let winner: String? = h > a ? f.homeTeamID : (a > h ? f.awayTeamID : nil)
        return FixtureResult(fixtureID: f.id, homeScore: h, awayScore: a,
                             winnerTeamID: winner, goals: [], isSimulated: true)
    }

    private func completeResults(_ stage: WorldGroupStage) -> [FixtureResult] {
        stage.fixtures.map(syntheticResult)
    }

    func testExactlyTwelveThirdPlacedTeams() throws {
        let stage = try drawnStage()
        let thirds = WorldGroupStageEngine.rankThirdPlacedTeams(
            groups: stage.groups, fixtures: stage.fixtures,
            results: completeResults(stage), tournamentSeed: seed)
        XCTAssertEqual(thirds.count, 12)
        XCTAssertEqual(Set(thirds.map(\.teamID)).count, 12)
    }

    func testEachThirdIsActuallyThirdInItsGroup() throws {
        let stage = try drawnStage()
        let results = completeResults(stage)
        let thirdsByGroup = Dictionary(uniqueKeysWithValues: WorldGroupStageEngine
            .rankThirdPlacedTeams(groups: stage.groups, fixtures: stage.fixtures,
                                  results: results, tournamentSeed: seed)
            .compactMap { s -> (String, String)? in s.groupID.map { ($0, s.teamID) } })

        for group in stage.groups {
            let table = WorldGroupStageEngine.standings(for: group, fixtures: stage.fixtures,
                                                        results: results, tournamentSeed: seed)
            XCTAssertEqual(thirdsByGroup[group.id], table[2].teamID)
        }
    }

    func testExactlyEightUniqueQualifiers() throws {
        let stage = try drawnStage()
        let qualifiers = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures,
            results: completeResults(stage), tournamentSeed: seed)
        XCTAssertEqual(qualifiers.count, 8)
        XCTAssertEqual(Set(qualifiers).count, 8)
    }

    func testQualifiersAreTheTopEightRankedThirds() throws {
        let stage = try drawnStage()
        let results = completeResults(stage)
        let ranked = WorldGroupStageEngine.rankThirdPlacedTeams(
            groups: stage.groups, fixtures: stage.fixtures, results: results, tournamentSeed: seed)
        let qualifiers = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures, results: results, tournamentSeed: seed)
        XCTAssertEqual(qualifiers, Array(ranked.prefix(8).map(\.teamID)))
    }

    func testRankingIsMonotonicByPoints() throws {
        let stage = try drawnStage()
        let ranked = WorldGroupStageEngine.rankThirdPlacedTeams(
            groups: stage.groups, fixtures: stage.fixtures,
            results: completeResults(stage), tournamentSeed: seed)
        for i in 1..<ranked.count {
            XCTAssertGreaterThanOrEqual(ranked[i - 1].points, ranked[i].points,
                                        "third-place ranking must be non-increasing by points")
        }
    }

    func testIncompleteGroupStageThrows() throws {
        let stage = try drawnStage()
        var results = completeResults(stage)
        results.removeLast()   // one match unplayed → not all groups complete
        XCTAssertThrowsError(try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures,
            results: results, tournamentSeed: seed)) { error in
            XCTAssertEqual(error as? WorldGroupStageError, .groupStageIncomplete)
        }
    }

    func testSameSeedSameQualifierOrder() throws {
        let stage = try drawnStage()
        let results = completeResults(stage)
        let a = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures, results: results, tournamentSeed: seed)
        let b = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: stage.groups, fixtures: stage.fixtures, results: results, tournamentSeed: seed)
        XCTAssertEqual(a, b)
    }
}
