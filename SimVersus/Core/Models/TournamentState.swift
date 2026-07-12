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
    /// v2 = adds FixtureSlotSource, v3 = adds World Arena persistence fields
    /// (competitionID, tournamentSeed, groupAssignments, knockoutBracket,
    /// bestThirdPlacedTeamIDs).
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

    // MARK: - World Arena persistence (Commit 4)

    /// Identifies the competition definition (nil = legacy standard tournament).
    /// "world-arena-2026" for World Arena.
    var competitionID: String?
    /// Deterministic tournament seed so the bracket can be reproduced after
    /// save/resume without reshuffling.
    var tournamentSeed: UInt64
    /// World Arena group assignments, JSON-encoded [GroupAssignment] (nil for legacy).
    var groupAssignmentsData: Data?
    /// World Arena knockout bracket, JSON-encoded WorldKnockoutBracket (nil for legacy).
    var knockoutBracketData: Data?
    /// World Arena best third-placed qualifier team IDs, JSON-encoded [String] (nil for legacy).
    var bestThirdPlacedTeamIDsData: Data?

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

    // MARK: - World Arena transient accessors

    /// Decoded World Arena group assignments (empty for legacy).
    var groupAssignments: [GroupAssignment] {
        guard let data = groupAssignmentsData else { return [] }
        return (try? JSONDecoder().decode([GroupAssignment].self, from: data)) ?? []
    }

    /// Decoded World Arena knockout bracket (nil for legacy or if not yet generated).
    var knockoutBracket: WorldKnockoutBracket? {
        guard let data = knockoutBracketData else { return nil }
        return try? JSONDecoder().decode(WorldKnockoutBracket.self, from: data)
    }

    /// Decoded best third-placed qualifier team IDs (empty for legacy).
    var bestThirdPlacedTeamIDs: [String] {
        guard let data = bestThirdPlacedTeamIDsData else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    /// Sets the World Arena group assignments.
    func setGroupAssignments(_ assignments: [GroupAssignment]) {
        groupAssignmentsData = (try? JSONEncoder().encode(assignments)) ?? Data()
    }

    /// Sets the World Arena knockout bracket.
    func setKnockoutBracket(_ bracket: WorldKnockoutBracket) {
        knockoutBracketData = (try? JSONEncoder().encode(bracket)) ?? Data()
        // Append these fixtures to the main fixtures array if not already present.
        var current = fixtures
        let existingIDs = Set(current.map(\.id))
        for f in bracket.fixtures where !existingIDs.contains(f.id) {
            current.append(f)
        }
        fixturesData = (try? JSONEncoder().encode(current)) ?? Data()
    }

    /// Sets the best third-placed qualifier team IDs.
    func setBestThirdPlacedTeamIDs(_ ids: [String]) {
        bestThirdPlacedTeamIDsData = (try? JSONEncoder().encode(ids)) ?? Data()
    }

    // MARK: - Init

    init(format: TournamentFormat, playerTeamID: String,
         teams: [String], fixtures: [Fixture],
         competitionID: String? = nil,
         tournamentSeed: UInt64 = 0,
         groupAssignments: [GroupAssignment]? = nil) {
        self.schemaVersion = 3
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
        // World Arena
        self.competitionID = competitionID
        self.tournamentSeed = tournamentSeed
        self.groupAssignmentsData = groupAssignments.flatMap { try? JSONEncoder().encode($0) }
        self.knockoutBracketData = nil
        self.bestThirdPlacedTeamIDsData = nil
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
