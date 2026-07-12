//  MatchPreferences.swift
//  Core/Models
//
//  User-adjustable match settings. Duration maps directly onto
//  `MatchConfig.duration`; the HUD scales that real-time interval onto
//  90 display minutes. `PhysicsConstants` stays untouched (CONSTITUTION §6).

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
