//  WorldArena2026.swift
//  Core/Models
//
//  The concrete World Arena 2026 tournament definition — a 48-nation event with
//  12 groups of 4, top two advancing directly, resolving into a 32-team
//  knockout. This is the data model only (Commit 2.1); the group fixture engine,
//  best-third resolver and Round-of-32 wiring are intentionally out of scope and
//  land in a later commit.

import Foundation

extension TournamentDefinition {

    /// Structural parameters for World Arena 2026. Kept as named constants so no
    /// magic numbers leak into the factory.
    enum WorldArena {
        static let id = "world-arena-2026"
        static let teamCatalogID = "national_teams_2026"
        static let teamCount = 48
        static let groupCount = 12          // groups A…L
        static let teamsPerGroup = 4
        static let advancePerGroup = 2      // top two of each group advance directly
        /// Round of 32: 24 group winners/runners-up + 8 best third-placed teams.
        /// The best-third selection is a later commit; here we only declare the
        /// slot count the bracket must fill.
        static let knockoutSlotCount = 32
        static let potCount = 4
        static let accentColor = "#F2C230"  // World Arena gold (accent.warning token)

        static let displayNameKey = "tournament.worldArena.name"
        static let subtitleKey = "tournament.worldArena.subtitle"
        static let disclaimerKey = "tournament.worldArena.disclaimer"

        /// Group identifiers A…L, derived from `groupCount`.
        static var groupIDs: [String] {
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
            return (0..<groupCount).map { String(letters[$0]) }
        }
    }

    /// Builds the World Arena 2026 definition from the national team catalog.
    /// Pots are read straight from the catalog (which already carries a `pot`
    /// per team) so the seeding source stays single-sourced with the JSON.
    ///
    /// The bracket is single-elimination without a bronze final:
    /// `hasThirdPlaceMatch` is `false` by deliberate design decision — the
    /// knockout drama funnels to one final, matching the club formats.
    static func worldArena2026(catalog: NationalTeamStore = NationalTeamStore()) -> TournamentDefinition {
        let potsByNumber = catalog.teamsByPot
        let pots: [[String]] = (1...WorldArena.potCount).map { potNumber in
            (potsByNumber[potNumber] ?? []).map(\.id)
        }

        let groups = WorldArena.groupIDs.map { id in
            GroupDefinition(id: id,
                            teamIDs: [],                       // filled by the draw (later commit)
                            advanceDirectCount: WorldArena.advancePerGroup)
        }

        return TournamentDefinition(
            id: WorldArena.id,
            kind: .nations2026,
            displayNameKey: WorldArena.displayNameKey,
            teamCatalogID: WorldArena.teamCatalogID,
            teamCount: WorldArena.teamCount,
            pots: pots,
            groups: groups,
            knockout: KnockoutDefinition(
                slotCount: WorldArena.knockoutSlotCount,
                roundNameKeys: TournamentRoundKey.keys(forSlotCount: WorldArena.knockoutSlotCount),
                hasThirdPlaceMatch: false),
            branding: TournamentBranding(
                accentColor: WorldArena.accentColor,
                subtitleKey: WorldArena.subtitleKey,
                disclaimerKey: WorldArena.disclaimerKey,
                backgroundAsset: nil))
    }
}
