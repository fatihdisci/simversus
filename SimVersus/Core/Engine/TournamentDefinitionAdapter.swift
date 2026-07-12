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
        let roundNames: [String]
        if groupCount > 0 {
            knockoutSlotCount = groupCount * format.advancePerGroup
        } else {
            knockoutSlotCount = teamCount
        }
        // Build round names from the number of slots: 32→5 rounds, 16→4, 8→3, 4→2
        let totalRounds = Int(log2(Double(knockoutSlotCount)))
        switch totalRounds {
        case 1: roundNames = ["Final"]
        case 2: roundNames = ["Yarı Final", "Final"]
        case 3: roundNames = ["Çeyrek Final", "Yarı Final", "Final"]
        case 4: roundNames = ["Son 16", "Çeyrek Final", "Yarı Final", "Final"]
        case 5: roundNames = ["Son 32", "Son 16", "Çeyrek Final", "Yarı Final", "Final"]
        default: roundNames = (1...totalRounds).map { "Tur \($0)" }
        }

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
                roundNames: roundNames,
                hasThirdPlaceMatch: false),
            branding: TournamentBranding(
                accentColor: "#E8A21D",
                subtitleKey: nil,
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

    private static func log2(_ x: Double) -> Double { Darwin.log2(x) }
}
