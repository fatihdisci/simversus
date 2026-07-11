//  TeamStatsTests.swift
//  SimVersusTests
//
//  Guards the team-stat invariants: every preset spends exactly the fixed
//  budget, the neutral profile equals the baseline constants, and the
//  level→value mapping stays in sync with PhysicsConstants.

import XCTest
@testable import SimVersus

final class TeamStatsTests: XCTestCase {

    /// Every team loaded from teams.json must spend exactly the fixed budget
    /// with each stat in range — catches typos in the JSON profiles.
    func testAllTeamsHaveValidStatBudget() {
        for team in TeamStore().allTeams {
            XCTAssertTrue(team.stats.isValid,
                          "\(team.id) has invalid stats \(team.stats) (must sum to \(PhysicsConstants.statBudget), each 1...5)")
        }
    }

    /// The neutral 3/3/3 profile must resolve to the documented baseline values.
    func testBalancedProfileMatchesBaseline() {
        let s = TeamStats.balanced
        XCTAssertEqual(s.mass, PhysicsConstants.ballMass)
        XCTAssertEqual(s.radius, PhysicsConstants.ballRadius)
        XCTAssertEqual(s.targetSpeed, PhysicsConstants.targetBallSpeed)
    }

    /// A team missing its `stats` block decodes to the balanced default.
    func testMissingStatsDefaultsToBalanced() throws {
        let json = """
        { "id": "x", "nameKey": "k", "nameTR": "t", "nameEN": "e", "short": "X",
          "primary": "#000000", "secondary": "#FFFFFF", "badgeShape": "star",
          "tier": 1, "baseStrength": 75 }
        """.data(using: .utf8)!
        let team = try JSONDecoder().decode(Team.self, from: json)
        XCTAssertEqual(team.stats, .balanced)
    }

    /// Stat bands are ordered and centred on the baseline (level 3 = index 2).
    func testBandsAreMonotonicAndCentred() {
        XCTAssertEqual(PhysicsConstants.massByLevel.count, 5)
        XCTAssertEqual(PhysicsConstants.targetSpeedByLevel.count, 5)
        XCTAssertEqual(PhysicsConstants.ballRadiusByLevel.count, 5)
        XCTAssertEqual(PhysicsConstants.massByLevel[2], PhysicsConstants.ballMass)
        XCTAssertEqual(PhysicsConstants.ballRadiusByLevel[2], PhysicsConstants.ballRadius)
        XCTAssertEqual(PhysicsConstants.targetSpeedByLevel[2], PhysicsConstants.targetBallSpeed)
        XCTAssertEqual(PhysicsConstants.massByLevel, PhysicsConstants.massByLevel.sorted())
        XCTAssertEqual(PhysicsConstants.targetSpeedByLevel, PhysicsConstants.targetSpeedByLevel.sorted())
        XCTAssertEqual(PhysicsConstants.ballRadiusByLevel, PhysicsConstants.ballRadiusByLevel.sorted())
    }

    /// Different profiles must yield different physical bodies (sanity that the
    /// mapping actually varies) — heavier/bigger/faster resolve higher.
    func testDistinctProfilesDiffer() {
        let light = TeamStats(weight: 1, speed: 1, size: 5)
        let heavy = TeamStats(weight: 5, speed: 5, size: 1)
        XCTAssertLessThan(light.mass, heavy.mass)
        XCTAssertLessThan(light.targetSpeed, heavy.targetSpeed)
        XCTAssertGreaterThan(light.radius, heavy.radius)
    }
}
