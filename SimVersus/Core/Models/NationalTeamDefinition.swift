//  NationalTeamDefinition.swift
//  Core/Models
//
//  A national team entry for special international tournaments (Faz 3W).
//  Stored as a JSON catalog, NOT in the club teams.json. Adapted to the
//  existing Team model via asTeam for the match engine.
//
//  Brand safety: colours are flag-inspired but not exact pantone matches.
//  Badge shapes use the existing 5 abstract geometric shapes. No federation
//  logos, real emblems, or animal symbols (CONSTITUTION §4.2).

import Foundation
import SwiftUI

struct NationalTeamDefinition: Codable, Identifiable, Hashable {
    /// Stable identifier, e.g. "nation-tr", "nation-br".
    let id: String
    /// ISO 3166-1 alpha-2 code.
    let isoCode: String
    /// Asset catalog name for the flag image.
    let flagAsset: String
    /// String Catalog key for the localised name.
    let nameKey: String
    /// Turkish display name.
    let nameTR: String
    /// English display name.
    let nameEN: String
    /// 3-letter short code (ISO-derived or custom).
    let shortCode: String
    /// Primary colour (hex, flag-inspired).
    let primary: String
    /// Secondary colour (hex).
    let secondary: String
    /// Optional tertiary accent (hex).
    let tertiary: String?
    /// Abstract badge shape.
    let badgeShape: BadgeShape
    /// Kit pattern.
    let pattern: KitPattern
    /// Mechanical stats (sum = 9).
    let stats: TeamStats
    /// Seeding pot (1 = strongest, 4 = weakest).
    let pot: Int
    /// Pre-assigned group (nil = determined by draw).
    let group: String?

    // MARK: - Team adapter

    /// Bridges this national team into the existing Team model so it can be
    /// fed directly to MatchSimulation and all existing UI components.
    var asTeam: Team {
        Team(id: id,
             nameKey: nameKey,
             nameTR: nameTR,
             nameEN: nameEN,
             short: shortCode,
             primary: primary,
             secondary: secondary,
             badgeShape: badgeShape,
             tier: 0,            // national teams are not in the club tier system
             baseStrength: 75,
             stats: stats,
             pattern: pattern)
    }

    /// Display colour resolved from primary hex.
    var primaryColor: Color { Color(hex: primary) }
    /// Display colour resolved from secondary hex.
    var secondaryColor: Color { Color(hex: secondary) }
    /// Display colour resolved from tertiary hex, falls back to secondary.
    var tertiaryColor: Color {
        tertiary.flatMap { Color(hex: $0) } ?? secondaryColor
    }
}
