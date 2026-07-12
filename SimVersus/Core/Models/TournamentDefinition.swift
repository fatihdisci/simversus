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
    /// Ordered String Catalog KEYS for each round's display name
    /// (e.g. "tournament.round.r32"). Renamed from `roundNames` in Commit 2.1:
    /// the array now carries localization keys, never pre-localized strings, so
    /// no user-facing Turkish/English text is baked into the model.
    let roundNameKeys: [String]
    /// Whether to include a third-place (bronze) match.
    let hasThirdPlaceMatch: Bool
}

struct TournamentBranding: Codable, Equatable {
    /// Accent colour for the tournament UI (hex).
    let accentColor: String
    /// Optional subtitle shown in the lobby (String Catalog key).
    let subtitleKey: String?
    /// Optional brand-safety disclaimer (String Catalog key).
    let disclaimerKey: String?
    /// Optional background asset name.
    let backgroundAsset: String?
}

/// String Catalog keys for knockout round names. Single source of truth shared
/// by `TournamentDefinitionAdapter` and every `TournamentDefinition` factory —
/// no round name is spelled out as a literal string anywhere else.
enum TournamentRoundKey {
    static let r32 = "tournament.round.r32"
    static let r16 = "tournament.round.r16"
    static let quarterFinal = "tournament.round.quarterFinal"
    static let semiFinal = "tournament.round.semiFinal"
    static let final = "tournament.round.final"
    /// Format key taking a 1-based round number, used only when a bespoke
    /// tournament has more rounds than the named set (currently unreachable for
    /// the shipped formats). Consumers format it with the round index.
    static let generic = "tournament.round.generic"

    /// Named round keys for a single-elimination bracket of `slotCount` teams,
    /// e.g. 32 → [r32, r16, QF, SF, Final]. Falls back to the generic key when
    /// the depth exceeds the named set.
    static func keys(forSlotCount slotCount: Int) -> [String] {
        let totalRounds = Int(Foundation.log2(Double(max(slotCount, 1))))
        switch totalRounds {
        case 1: return [final]
        case 2: return [semiFinal, final]
        case 3: return [quarterFinal, semiFinal, final]
        case 4: return [r16, quarterFinal, semiFinal, final]
        case 5: return [r32, r16, quarterFinal, semiFinal, final]
        default: return Array(repeating: generic, count: max(totalRounds, 1))
        }
    }
}
