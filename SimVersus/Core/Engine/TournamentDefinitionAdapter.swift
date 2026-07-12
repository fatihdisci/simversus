//  TournamentDefinitionAdapter.swift
//  Core/Engine
//
//  Converts the legacy TournamentFormat enum into a TournamentDefinition so
//  the engine can treat all tournaments uniformly. Standard club formats
//  (mini/classic/groupKO/grand) are mapped here; special tournaments like
//  World Arena 2026 are loaded from their own JSON definition.

import Foundation

enum TournamentDefinitionAdapter {

    /// Converts a legacy TournamentFormat into a TournamentDefinition.
    static func adapt(_ format: TournamentFormat) -> TournamentDefinition {
        let teamCount = format.teamCount
        let groupCount = format.groupCount

        let groups: [GroupDefinition]
        if groupCount > 0 {
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            groups = (0..<groupCount).map { i in
                GroupDefinition(id: String(letters[i]),
                                teamIDs: [],
                                advanceDirectCount: format.advancePerGroup)
            }
        } else {
            groups = []
        }

        let knockoutSlotCount: Int
        if groupCount > 0 {
            knockoutSlotCount = groupCount * format.advancePerGroup
        } else {
            knockoutSlotCount = teamCount
        }
        // Round names are localization KEYS resolved from the slot count
        // (32→[r32,r16,QF,SF,Final], 16→[r16,QF,SF,Final], …). No user-facing
        // strings are baked in here — they come from the String Catalog.
        let roundNameKeys = TournamentRoundKey.keys(forSlotCount: knockoutSlotCount)

        return TournamentDefinition(
            id: format.rawValue,
            kind: .standard,
            displayNameKey: displayNameKey(for: format),
            teamCatalogID: "teams",
            teamCount: teamCount,
            pots: [],  // standard formats have no pots
            groups: groups,
            knockout: KnockoutDefinition(
                slotCount: knockoutSlotCount,
                roundNameKeys: roundNameKeys,
                hasThirdPlaceMatch: false),
            branding: TournamentBranding(
                accentColor: "#E8A21D",
                subtitleKey: nil,
                disclaimerKey: nil,
                backgroundAsset: nil))
    }

    private static func displayNameKey(for format: TournamentFormat) -> String {
        switch format {
        case .mini:    return "tournament.format.mini"
        case .classic: return "tournament.format.classic"
        case .groupKO: return "tournament.format.groupKO"
        case .grand:   return "tournament.format.grand"
        }
    }
}
