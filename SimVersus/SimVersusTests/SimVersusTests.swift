//  SimVersusTests.swift
//  SimVersusTests
//
//  Placeholder suite so the test target compiles and links against the app
//  module. Part 1c replaces this with the match-engine determinism and
//  goal-band tests (`MatchEngineTests`).

import XCTest
@testable import SimVersus

final class SimVersusTests: XCTestCase {
    func testAppStateInitialises() {
        let state = AppState()
        XCTAssertGreaterThanOrEqual(state.matchesPlayedCount, 0)
    }
}
