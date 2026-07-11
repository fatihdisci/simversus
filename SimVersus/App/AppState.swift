//  AppState.swift
//  App
//
//  App-wide observable state. Tracks how many matches have been completed
//  (persisted; Part 1e reads it to drive the interstitial cadence every 3rd
//  match) and the user's match speed / duration preferences (Phase 2d).

import SwiftUI

final class AppState: ObservableObject {
    private enum Keys {
        static let matchesPlayedCount = "matchesPlayedCount"
        static let matchSpeed = "matchSpeedOption"
        static let matchDuration = "matchDurationOption"
    }

    /// Total number of completed matches. Persisted across launches via
    /// `UserDefaults` and incremented by the match flow in Part 1d.
    @Published var matchesPlayedCount: Int {
        didSet {
            UserDefaults.standard.set(matchesPlayedCount, forKey: Keys.matchesPlayedCount)
        }
    }

    /// User-chosen match playback speed (Settings). Applied via
    /// `SKScene.speed`; `PhysicsConstants` never changes.
    @Published var matchSpeed: MatchSpeedOption {
        didSet {
            UserDefaults.standard.set(matchSpeed.rawValue, forKey: Keys.matchSpeed)
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
        matchSpeed = defaults.string(forKey: Keys.matchSpeed).flatMap(MatchSpeedOption.init) ?? .x1
        matchDuration = defaults.string(forKey: Keys.matchDuration).flatMap(MatchDurationOption.init) ?? .normal
    }
}
