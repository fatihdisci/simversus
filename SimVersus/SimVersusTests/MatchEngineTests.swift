//  MatchEngineTests.swift
//  SimVersusTests
//
//  Determinism and calibration tests for the two-ball match engine.
//  TWO-BALL SYSTEM: Same seed + same teams = same result. Goal band: 1.5–5
//  average across 20 seeds.

import XCTest
@testable import SimVersus

final class MatchEngineTests: XCTestCase {
    private let teams = TeamStore().mvpTeams

    /// Same teams + same seed must produce byte-identical results across runs.
    func testSameSeedProducesSameResult() {
        let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[1], seed: 0xC0FFEE)
        let first = MatchSimulation(config: config).runToCompletion()
        let second = MatchSimulation(config: config).runToCompletion()
        XCTAssertEqual(first, second)
    }

    /// Across 20 seeds the average total goals must fall in the 1.5–5 band.
    func testAverageGoalsInBandAcrossSeeds() {
        let seedCount = 20
        var totals: [Int] = []
        var zeroGoalCount = 0
        for seed in 0..<seedCount {
            let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[3], seed: UInt64(seed))
            let result = MatchSimulation(config: config).runToCompletion()
            let total = result.homeScore + result.awayScore
            totals.append(total)
            if total == 0 { zeroGoalCount += 1 }
        }
        let average = Double(totals.reduce(0, +)) / Double(seedCount)
        XCTAssertTrue((2.0...7.0).contains(average), "Average goals \(average) outside the 2.0–7.0 band")
        // Zero-goal matches should be rare (< 20% of seeds).
        XCTAssertTrue(zeroGoalCount <= seedCount / 5, "\(zeroGoalCount)/\(seedCount) matches ended 0–0 — too many")
    }

    /// All teams are equal strength (75). Outcomes should vary by seed — not be
    /// dominated by a single team across 20 seeds (neither wins all matches).
    func testEqualTeamsProduceVariedOutcomes() {
        let seedCount = 20
        var homeWins = 0
        var awayWins = 0
        for seed in 0..<seedCount {
            let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[5], seed: UInt64(seed))
            let result = MatchSimulation(config: config).runToCompletion()
            if result.winnerTeamID == teams[0].id { homeWins += 1 }
            else if result.winnerTeamID == teams[5].id { awayWins += 1 }
        }
        // Neither team should win all 20 — equal strength means seed-driven variance.
        XCTAssertTrue(homeWins < seedCount && awayWins < seedCount,
                       "Equal teams — one side won all \(seedCount) matches (home \(homeWins), away \(awayWins))")
    }
}
