//  TournamentState.swift
//  Core/Models
//
//  @Model entity that holds the entire lifecycle of one tournament. Fixtures and
//  results are stored as JSON blobs so the tournament is a single atomic
//  SwiftData row — easy to persist, resume, and delete.

import Foundation
import SwiftData

@Model
final class TournamentState {
    /// Schema version for forward/backward compatibility. v1 = original,
    /// v2 = adds FixtureSlotSource, v3 = adds competitionID/tournamentSeed.
    var schemaVersion: Int
    /// Stable identifier for the tournament run.
    var id: UUID
    /// TournamentFormat.rawValue so it survives the enum.
    var formatRaw: String
    /// The team the player chose as "their" team.
    var playerTeamID: String
    /// All team IDs in this tournament, JSON-encoded [String].
    var teamsData: Data
    /// Fixtures for every stage, JSON-encoded [Fixture].
    var fixturesData: Data
    /// Results played so far, JSON-encoded [FixtureResult].
    var resultsData: Data
    /// TournamentPhase.rawValue.
    var phaseRaw: String
    /// Current knockout round index (0 = groups or first KO round).
    var currentRound: Int
    /// When the tournament was created.
    var startedAt: Date
    /// When the tournament ended (nil while in progress).
    var completedAt: Date?

    // MARK: - Decoded accessors (transient)

    var teams: [String] {
        (try? JSONDecoder().decode([String].self, from: teamsData)) ?? []
    }

    var fixtures: [Fixture] {
        (try? JSONDecoder().decode([Fixture].self, from: fixturesData)) ?? []
    }

    var results: [FixtureResult] {
        (try? JSONDecoder().decode([FixtureResult].self, from: resultsData)) ?? []
    }

    var format: TournamentFormat {
        TournamentFormat(rawValue: formatRaw) ?? .mini
    }

    var phase: TournamentPhase {
        TournamentPhase(rawValue: phaseRaw) ?? .pending
    }

    /// Fixtures that are either the player's own team match, or optionally
    /// all remaining unplayed fixtures.
    func playerFixtures() -> [Fixture] {
        fixtures.filter { $0.homeTeamID == playerTeamID || $0.awayTeamID == playerTeamID }
    }

    /// The next unplayed fixture involving the player's team, if any.
    func nextPlayerFixture() -> Fixture? {
        let playedIDs = Set(results.map(\.fixtureID))
        return playerFixtures().first { !playedIDs.contains($0.id) }
    }

    /// True when every fixture has a result.
    var isComplete: Bool {
        let playedIDs = Set(results.map(\.fixtureID))
        return fixtures.allSatisfy { playedIDs.contains($0.id) }
    }

    // MARK: - Init

    init(format: TournamentFormat, playerTeamID: String,
         teams: [String], fixtures: [Fixture]) {
        self.schemaVersion = 1
        self.id = UUID()
        self.formatRaw = format.rawValue
        self.playerTeamID = playerTeamID
        self.teamsData = (try? JSONEncoder().encode(teams)) ?? Data()
        self.fixturesData = (try? JSONEncoder().encode(fixtures)) ?? Data()
        self.resultsData = Data() // empty at creation
        self.phaseRaw = TournamentPhase.groupStage.rawValue
        self.currentRound = 0
        self.startedAt = .now
        self.completedAt = nil
    }

    // MARK: - Mutation helpers

    func appendResult(_ result: FixtureResult) {
        var current = results
        current.append(result)
        resultsData = (try? JSONEncoder().encode(current)) ?? Data()
    }

    func setPhase(_ newPhase: TournamentPhase) {
        phaseRaw = newPhase.rawValue
    }

    func advanceRound() {
        currentRound += 1
    }
}

// MARK: - Tournament phase

enum TournamentPhase: String, Codable {
    /// Not yet started (team selection).
    case pending
    /// Group stage in progress (only for groupKO / grand).
    case groupStage
    /// Knockout rounds in progress.
    case knockout
    /// Tournament finished.
    case finished
}
