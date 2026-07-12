//  TournamentFormat.swift
//  Core/Models
//
//  Four tournament formats with their structural properties. The engine uses
//  these to generate fixtures, group tables, and knockout brackets.

import Foundation

enum TournamentFormat: String, Codable, CaseIterable {
    /// 4-team single elimination: semi-final → final (2 player matches)
    case mini
    /// 8-team single elimination: quarter → semi → final (3 player matches)
    case classic
    /// 8 teams: 2 groups × 4, top 2 → semi-finals (3–5 player matches)
    case groupKO
    /// 16 teams: 4 groups × 4, top 2 → quarter-finals (4–7 player matches)
    case grand
}

extension TournamentFormat {
    /// Total number of teams in this format.
    var teamCount: Int {
        switch self {
        case .mini: return 4
        case .classic, .groupKO: return 8
        case .grand: return 16
        }
    }

    /// Number of groups (0 for pure knockout).
    var groupCount: Int {
        switch self {
        case .mini, .classic: return 0
        case .groupKO: return 2
        case .grand: return 4
        }
    }

    /// Teams per group (0 for pure knockout).
    var teamsPerGroup: Int {
        guard groupCount > 0 else { return 0 }
        return teamCount / groupCount
    }

    /// Number of teams that advance from each group.
    var advancePerGroup: Int { 2 }

    /// True when this format has a group stage before the knockout phase.
    var hasGroupStage: Bool { groupCount > 0 }

    /// Ordered knockout round names for bracket rendering.
    var knockoutRoundNames: [String] {
        switch self {
        case .mini:
            return ["Yarı Final", "Final"]
        case .classic:
            return ["Çeyrek Final", "Yarı Final", "Final"]
        case .groupKO:
            return ["Yarı Final", "Final"]
        case .grand:
            return ["Çeyrek Final", "Yarı Final", "Final"]
        }
    }

    /// Localized display name for the format selector.
    var displayName: String {
        switch self {
        case .mini:     return String(localized: "tournament.format.mini")
        case .classic:  return String(localized: "tournament.format.classic")
        case .groupKO:  return String(localized: "tournament.format.groupKO")
        case .grand:    return String(localized: "tournament.format.grand")
        }
    }

    /// Access requirement for this format.
    var isFree: Bool {
        switch self {
        case .mini, .classic: return true
        case .groupKO, .grand: return false
        }
    }
}
