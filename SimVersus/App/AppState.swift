//  AppState.swift
//  App
//
//  App-wide observable state. For Part 1a it only tracks how many matches
//  have been completed; the value is persisted and Part 1e reads it to drive
//  the interstitial cadence (every 3rd match).

import SwiftUI

final class AppState: ObservableObject {
    private enum Keys {
        static let matchesPlayedCount = "matchesPlayedCount"
    }

    /// Total number of completed matches. Persisted across launches via
    /// `UserDefaults` and incremented by the match flow in Part 1d.
    @Published var matchesPlayedCount: Int {
        didSet {
            UserDefaults.standard.set(matchesPlayedCount, forKey: Keys.matchesPlayedCount)
        }
    }

    init() {
        // `integer(forKey:)` returns 0 when the key is absent — the correct
        // default for a fresh install.
        matchesPlayedCount = UserDefaults.standard.integer(forKey: Keys.matchesPlayedCount)
    }
}
