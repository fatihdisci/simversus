//  TeamStore.swift
//  Core/Data
//
//  Loads team data from the bundled teams.json. This is app-authored bundle
//  data, so a missing or malformed file is a programmer error — we `fatalError`
//  rather than fall back silently.

import Foundation

struct TeamStore {
    /// All teams, in file order.
    let allTeams: [Team]

    /// MVP teams (tier 1) — the only teams shown in the UI in Phase 1.
    var mvpTeams: [Team] { allTeams.filter { $0.tier == 1 } }

    init(bundle: Bundle = .main) {
        guard let url = bundle.url(forResource: "teams", withExtension: "json") else {
            fatalError("teams.json is missing from the app bundle.")
        }
        do {
            let data = try Data(contentsOf: url)
            allTeams = try JSONDecoder().decode(TeamsFile.self, from: data).teams
        } catch {
            fatalError("Failed to decode teams.json: \(error)")
        }
    }
}

/// Envelope matching the top level of teams.json. The `_comment` field is
/// intentionally ignored by the decoder.
private struct TeamsFile: Codable {
    let schemaVersion: Int
    let teams: [Team]
}
