//  NationalTeamStore.swift
//  Core/Data
//
//  Loads the national team catalog from the bundled JSON. Follows the same
//  pattern as TeamStore — missing/malformed data is a programmer error and
//  triggers fatalError.

import Foundation

struct NationalTeamStore {
    /// All 48 national teams, in file order.
    let allTeams: [NationalTeamDefinition]

    /// Teams grouped by pot for seeded draws.
    var teamsByPot: [Int: [NationalTeamDefinition]] {
        Dictionary(grouping: allTeams) { $0.pot }
    }

    /// Teams pre-assigned to a specific group.
    var preassignedTeams: [NationalTeamDefinition] {
        allTeams.filter { $0.group != nil }
    }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "national_teams_2026",
                                    withExtension: "json") else {
            fatalError("national_teams_2026.json is missing from the app bundle.")
        }
        do {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(NationalTeamsFile.self, from: data)
            allTeams = envelope.teams
        } catch {
            fatalError("Failed to decode national_teams_2026.json: \(error)")
        }
    }

    /// Looks up a team by ID.
    func find(_ id: String) -> NationalTeamDefinition? {
        allTeams.first { $0.id == id }
    }
}

/// Envelope matching the top level of national_teams_2026.json.
private struct NationalTeamsFile: Codable {
    let schemaVersion: Int
    let teams: [NationalTeamDefinition]
}
