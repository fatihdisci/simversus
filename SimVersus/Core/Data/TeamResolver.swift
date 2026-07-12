//  TeamResolver.swift
//  Core/Data
//
//  Central team lookup shared by navigation and tournament coordinators.

import Foundation

struct TeamResolver {
    private let presetTeams: [Team]
    private let nationalTeams: [NationalTeamDefinition]

    init(teamStore: TeamStore = TeamStore(),
         nationalTeamStore: NationalTeamStore = NationalTeamStore()) {
        presetTeams = teamStore.allTeams
        nationalTeams = nationalTeamStore.allTeams
    }

    func find(_ teamID: String, customTeams: [CustomTeam] = []) -> Team? {
        if let preset = presetTeams.first(where: { $0.id == teamID }) { return preset }
        if let custom = customTeams.first(where: { $0.id.uuidString == teamID }) { return custom.asTeam }
        return nationalTeams.first(where: { $0.id == teamID })?.asTeam
    }

    func resolve(_ teamID: String, customTeams: [CustomTeam] = []) -> Team {
        find(teamID, customTeams: customTeams) ?? Team(
            id: teamID,
            nameKey: teamID,
            nameTR: teamID,
            nameEN: teamID,
            short: "???",
            primary: "#888888",
            secondary: "#444444",
            badgeShape: .star,
            tier: 0,
            baseStrength: 75,
            stats: .balanced,
            pattern: .solid)
    }
}
