//  MatchPreferences.swift
//  Core/Models
//
//  User-adjustable match presentation settings (Phase 2d). Both are pure
//  presentation knobs applied outside the deterministic engine: duration
//  maps onto `MatchConfig.duration` (already a real-seconds parameter the
//  HUD scales onto 90 display minutes) and speed maps onto `MatchScene`'s
//  `SKScene.speed`. `PhysicsConstants` stays untouched (CONSTITUTION §6).

import Foundation

enum MatchDurationOption: String, CaseIterable, Identifiable {
    case short, normal, long

    var id: String { rawValue }

    /// Real seconds of play.
    var seconds: TimeInterval {
        switch self {
        case .short: return 20
        case .normal: return PhysicsConstants.matchDuration
        case .long: return 45
        }
    }

    var titleKey: String {
        switch self {
        case .short: return "settings.duration.short"
        case .normal: return "settings.duration.normal"
        case .long: return "settings.duration.long"
        }
    }
}

enum MatchSpeedOption: String, CaseIterable, Identifiable {
    case x1, x2, x4

    var id: String { rawValue }

    /// Applied to the match scene via `SKScene.speed`.
    var multiplier: Double {
        switch self {
        case .x1: return 1
        case .x2: return 2
        case .x4: return 4
        }
    }

    var titleKey: String {
        switch self {
        case .x1: return "settings.speed.1x"
        case .x2: return "settings.speed.2x"
        case .x4: return "settings.speed.4x"
        }
    }
}
