//  Trophy.swift
//  Core/Models
//
//  A tournament trophy won by the player. Persisted with SwiftData so the
//  trophy cabinet survives across launches. Team name is denormalized so
//  trophies remain even if a custom team is deleted.

import Foundation
import SwiftData

@Model
final class Trophy {
    var id: UUID
    /// TournamentFormat.rawValue.
    var formatRaw: String
    /// The team ID that won (preset team.id or custom team UUID string).
    var teamID: String
    /// Denormalized team name at time of win.
    var teamName: String
    /// Denormalized team short code.
    var teamShort: String
    /// Denormalized primary colour hex.
    var primaryHex: String
    /// Denormalized secondary colour hex.
    var secondaryHex: String
    /// BadgeShape.rawValue.
    var badgeShapeRaw: String
    /// Whether the winning team was a custom team.
    var isCustomTeam: Bool
    /// When the tournament was won.
    var wonAt: Date

    /// The badge shape at time of win.
    var badgeShape: BadgeShape { BadgeShape(rawValue: badgeShapeRaw) ?? .star }

    init(id: UUID = UUID(),
         format: TournamentFormat,
         teamID: String,
         teamName: String,
         teamShort: String,
         primaryHex: String,
         secondaryHex: String,
         badgeShape: BadgeShape,
         isCustomTeam: Bool,
         wonAt: Date = .now) {
        self.id = id
        self.formatRaw = format.rawValue
        self.teamID = teamID
        self.teamName = teamName
        self.teamShort = teamShort
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.badgeShapeRaw = badgeShape.rawValue
        self.isCustomTeam = isCustomTeam
        self.wonAt = wonAt
    }

    var format: TournamentFormat {
        TournamentFormat(rawValue: formatRaw) ?? .mini
    }
}
