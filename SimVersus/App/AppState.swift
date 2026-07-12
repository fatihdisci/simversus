//  AppState.swift
//  App
//
//  App-wide observable state. Tracks how many matches have been completed
//  (persisted; Part 1e reads it to drive the interstitial cadence every 3rd
//  match) and the user's match-duration preference.

import SwiftUI

final class AppState: ObservableObject {
    private enum Keys {
        static let matchesPlayedCount = "matchesPlayedCount"
        static let matchDuration = "matchDurationOption"
    }

    /// Total number of completed matches. Persisted across launches via
    /// `UserDefaults` and incremented by the match flow in Part 1d.
    @Published var matchesPlayedCount: Int {
        didSet {
            UserDefaults.standard.set(matchesPlayedCount, forKey: Keys.matchesPlayedCount)
        }
    }

    /// User-chosen match length (Settings). Feeds `MatchConfig.duration`.
    @Published var matchDuration: MatchDurationOption {
        didSet {
            UserDefaults.standard.set(matchDuration.rawValue, forKey: Keys.matchDuration)
        }
    }

    init() {
        let defaults = UserDefaults.standard
        // `integer(forKey:)` returns 0 when the key is absent — the correct
        // default for a fresh install.
        matchesPlayedCount = defaults.integer(forKey: Keys.matchesPlayedCount)
        matchDuration = defaults.string(forKey: Keys.matchDuration).flatMap(MatchDurationOption.init) ?? .normal
    }
}
