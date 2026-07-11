//  PowerUpTests.swift
//  SimVersusTests
//
//  Power-ups must stay deterministic and must honour the enable flag (off for
//  tournament/ranked per CONSTITUTION §4.6).

import XCTest
@testable import SimVersus

final class PowerUpTests: XCTestCase {
    private let teams = TeamStore().mvpTeams

    /// With power-ups disabled, none ever appear on the pitch and the match
    /// still runs to completion.
    func testDisabledNeverSpawns() {
        let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[1],
                                 seed: 42, powerUpsEnabled: false)
        let sim = MatchSimulation(config: config)
        for _ in 0..<20_000 where !sim.isFinished {
            sim.step()
            XCTAssertTrue(sim.activePowerUps.isEmpty, "no pickups should exist when disabled")
        }
    }

    /// With power-ups enabled, pickups do appear over the course of play.
    func testEnabledSpawnsPickups() {
        let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[1], seed: 42)
        let sim = MatchSimulation(config: config)
        var everSpawned = false
        // ~60 simulated seconds is well past several spawn intervals.
        for _ in 0..<(60 * 120) where !sim.isFinished {
            sim.step()
            if !sim.activePowerUps.isEmpty { everSpawned = true; break }
        }
        XCTAssertTrue(everSpawned, "pickups should spawn when enabled")
    }

    /// Same seed + power-ups on must still reproduce byte-identical results.
    func testDeterministicWithPowerUps() {
        let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[2], seed: 123)
        let a = MatchSimulation(config: config).runToCompletion()
        let b = MatchSimulation(config: config).runToCompletion()
        XCTAssertEqual(a, b)
    }

    /// Enabling power-ups actually changes play versus disabling them (same seed).
    func testPowerUpsAffectOutcome() {
        var differed = false
        for seed in UInt64(0)..<8 {
            let on = MatchSimulation(config: MatchConfig(homeTeam: teams[0], awayTeam: teams[3], seed: seed)).runToCompletion()
            let off = MatchSimulation(config: MatchConfig(homeTeam: teams[0], awayTeam: teams[3], seed: seed, powerUpsEnabled: false)).runToCompletion()
            if on != off { differed = true; break }
        }
        XCTAssertTrue(differed, "power-ups should influence the match on at least one seed")
    }
}
