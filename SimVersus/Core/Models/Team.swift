//  Team.swift
//  Core/Models
//
//  Team model. Fields map 1:1 to teams.json — do not add or remove fields.

import SwiftUI

/// Abstract badge shapes (DESIGN_TOKENS). Purely geometric — never an animal
/// or a real-club emblem.
enum BadgeShape: String, Codable, CaseIterable {
    case star, chevron, wave, diamond, ring
}

/// A single team. Decoded directly from `teams.json`.
struct Team: Codable, Identifiable, Hashable {
    let id: String
    /// String Catalog key for the localized name (`team.<id>.name`).
    let nameKey: String
    /// Turkish name — the source for the catalog entry (display uses `nameKey`).
    let nameTR: String
    /// English name — the source for the catalog entry (display uses `nameKey`).
    let nameEN: String
    /// Short code shown on the badge (e.g. "IYR").
    let short: String
    /// Primary colour as a hex string.
    let primary: String
    /// Secondary colour as a hex string.
    let secondary: String
    let badgeShape: BadgeShape
    /// 1 = active in the MVP, 2 = unlocked later (Phase 4b).
    let tier: Int
    let baseStrength: Int

    /// Primary colour resolved from `primary`.
    var primaryColor: Color { Color(hex: primary) }
    /// Secondary colour resolved from `secondary`.
    var secondaryColor: Color { Color(hex: secondary) }
}
