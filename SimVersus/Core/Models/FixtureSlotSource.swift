//  FixtureSlotSource.swift
//  Core/Models
//
//  Replaces the fragile "TBD" magic-string bracket advancement with typed,
//  deterministic slots. Each fixture's two sides carry a source that resolves
//  to a concrete team ID after the referenced match or group completes.

import Foundation

/// Describes how a team qualifies for a knockout fixture slot.
enum FixtureSlotSource: Codable, Equatable, Hashable {
    /// A concrete team already known (group stage or preset bracket).
    case team(String)
    /// The team that finishes at this rank (0-based) in this group.
    case groupRank(groupIndex: Int, rank: Int)
    /// The Nth best third-placed team across all groups (0-based).
    case bestThirdPlace(rank: Int)
    /// The winner of the referenced fixture.
    case winner(of: String)
    /// Slot not yet determined (e.g. bracket not generated).
    case pending
}

// MARK: - Fixture extension

extension Fixture {
    /// The source for the home slot. Stored alongside homeTeamID for
    /// backward compatibility; team IDs still serve as the display value
    /// but the source tells the engine *how* to fill the slot.
    var homeSource: FixtureSlotSource {
        if let decoded = _homeSourceData.flatMap({ try? JSONDecoder().decode(FixtureSlotSource.self, from: $0) }) {
            return decoded
        }
        // Backward-compatible: if no source stored, the team ID IS the source.
        return homeTeamID == "TBD" ? .pending : .team(homeTeamID)
    }

    /// The source for the away slot.
    var awaySource: FixtureSlotSource {
        if let decoded = _awaySourceData.flatMap({ try? JSONDecoder().decode(FixtureSlotSource.self, from: $0) }) {
            return decoded
        }
        return awayTeamID == "TBD" ? .pending : .team(awayTeamID)
    }

    /// True when both slots are concrete teams (no pending/waiting sources).
    var isResolved: Bool {
        homeTeamID != "TBD" && awayTeamID != "TBD"
    }

    /// True when this fixture's slots are placeholders needing resolution.
    var needsResolution: Bool {
        (homeTeamID == "TBD" || homeTeamID.isEmpty) &&
        (awayTeamID == "TBD" || awayTeamID.isEmpty)
    }
}
