//  CustomTeam.swift
//  Core/Models
//
//  A user-created team, persisted with SwiftData. Enum/struct values are stored
//  as primitives (raw strings + Ints) to keep the SwiftData schema simple and
//  migration-friendly; the typed accessors rebuild `BadgeShape`, `KitPattern`
//  and `TeamStats` on read. `asTeam` adapts it to the `Team` the engine and UI
//  already consume, so a custom team drops straight into a match (baseStrength
//  fixed at 75 per CONSTITUTION §4.6 — identity comes from stats, not strength).

import Foundation
import SwiftData

@Model
final class CustomTeam {
    /// Stable identity — also becomes the adapted `Team.id`.
    var id: UUID
    /// User-entered display name (validated by `TeamNameValidator`).
    var name: String
    var primaryHex: String
    var secondaryHex: String
    var badgeShapeRaw: String
    var patternRaw: String
    var weightLevel: Int
    var speedLevel: Int
    var sizeLevel: Int
    var createdAt: Date

    init(id: UUID = UUID(),
         name: String,
         primaryHex: String,
         secondaryHex: String,
         badgeShape: BadgeShape,
         pattern: KitPattern,
         stats: TeamStats,
         createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.primaryHex = primaryHex
        self.secondaryHex = secondaryHex
        self.badgeShapeRaw = badgeShape.rawValue
        self.patternRaw = pattern.rawValue
        self.weightLevel = stats.weight
        self.speedLevel = stats.speed
        self.sizeLevel = stats.size
        self.createdAt = createdAt
    }

    // MARK: Typed accessors (degrade gracefully on bad data)

    var badgeShape: BadgeShape { BadgeShape(rawValue: badgeShapeRaw) ?? .star }
    var pattern: KitPattern { KitPattern(rawValue: patternRaw) ?? .solid }
    var stats: TeamStats { TeamStats(weight: weightLevel, speed: speedLevel, size: sizeLevel) }

    /// Short code shown on the badge — first three alphanumerics of the name.
    var short: String { Self.shortCode(from: name) }

    /// Adapts this custom team to the `Team` the engine + UI consume. The
    /// user's name is passed as `nameKey` too; a missing localization key
    /// simply renders the raw string, which is exactly what we want here.
    var asTeam: Team {
        Team(id: id.uuidString,
             nameKey: name,
             nameTR: name,
             nameEN: name,
             short: short,
             primary: primaryHex,
             secondary: secondaryHex,
             badgeShape: badgeShape,
             tier: 0,
             baseStrength: 75,
             stats: stats,
             pattern: pattern)
    }

    static func shortCode(from name: String) -> String {
        let letters = name.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let code = String(String.UnicodeScalarView(letters.prefix(3)))
        return code.isEmpty ? "CUS" : code
    }
}
