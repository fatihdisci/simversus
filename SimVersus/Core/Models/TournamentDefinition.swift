//  TournamentDefinition.swift
//  Core/Models
//
//  Data-driven tournament definition. Replaces hardcoded TournamentFormat
//  switch cases for special tournaments. Standard formats (mini/classic/
//  groupKO/grand) are converted via TournamentDefinitionAdapter.
//
//  A definition fully describes the structure — groups, knockout rounds,
//  branding — so the engine and UI can remain generic.

import Foundation

struct TournamentDefinition: Codable, Identifiable {
    /// Stable ID, e.g. "world2026".
    let id: String
    /// Tournament category.
    let kind: TournamentKind
    /// String Catalog key for the display name.
    let displayNameKey: String
    /// Team catalog resource name (e.g. "national_teams_2026").
    let teamCatalogID: String
    /// Total number of teams.
    let teamCount: Int
    /// Seeding pots. Each inner array is one pot of team IDs for the draw.
    let pots: [[String]]
    /// Group definitions, ordered.
    let groups: [GroupDefinition]
    /// Knockout stage definition.
    let knockout: KnockoutDefinition
    /// Visual branding for this tournament.
    let branding: TournamentBranding
}

struct KnockoutDefinition: Codable, Equatable {
    /// Number of teams entering the knockout stage.
    let slotCount: Int
    /// Ordered round names for display.
    let roundNames: [String]
    /// Whether to include a third-place match.
    let hasThirdPlaceMatch: Bool
}

struct TournamentBranding: Codable, Equatable {
    /// Accent colour for the tournament UI (hex).
    let accentColor: String
    /// Optional subtitle shown in the lobby.
    let subtitleKey: String?
    /// Optional background asset name.
    let backgroundAsset: String?
}
