//  TeamMatchupTests.swift
//  SimVersusTests
//
//  Verifies team loading and the selection invariant: a team can never be
//  chosen on both sides.

import XCTest
@testable import SimVersus

final class TeamMatchupTests: XCTestCase {
    private let teams = TeamStore().mvpTeams

    func testStoreProvidesSixMVPTeams() {
        XCTAssertEqual(teams.count, 6)
        XCTAssertTrue(teams.allSatisfy { $0.tier == 1 })
    }

    func testSameTeamCannotBePickedOnBothSides() {
        let team = teams[0]
        var matchup = TeamMatchup()
        matchup.selectHome(team)
        matchup.selectAway(team)   // blocked — it is the home pick
        XCTAssertEqual(matchup.home, team)
        XCTAssertNil(matchup.away)
        XCTAssertFalse(matchup.isReady)
    }

    func testReadyWhenBothSidesChosenDistinctly() {
        var matchup = TeamMatchup()
        matchup.selectHome(teams[0])
        matchup.selectAway(teams[1])
        XCTAssertTrue(matchup.isReady)
    }

    func testTappingSelectedTeamClearsIt() {
        var matchup = TeamMatchup()
        matchup.selectHome(teams[0])
        matchup.selectHome(teams[0])   // toggle off
        XCTAssertNil(matchup.home)
    }
}
