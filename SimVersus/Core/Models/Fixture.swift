//  Fixture.swift
//  Core/Models
//
//  Lightweight Codable types for tournament fixtures and results. These are
//  stored as JSON blobs inside TournamentState (not as separate @Model entities)
//  so the tournament state is a single atomic unit.

import Foundation

/// A single tournament match — group stage or knockout.
struct Fixture: Codable, Equatable, Identifiable {
    /// Unique within the tournament (e.g. "G0-M0", "QF-2").
    var id: String
    var homeTeamID: String
    var awayTeamID: String
    /// 0 = group stage, 1 = first knockout round, 2 = second, ...
    var round: Int
    /// Which group (0-based), nil for knockout rounds.
    var groupIndex: Int?
    /// Position within the round/group for bracket ordering.
    var matchIndex: Int
    /// Deterministic seed for the match engine.
    var seed: UInt64

    init(id: String, homeTeamID: String, awayTeamID: String,
         round: Int, groupIndex: Int?, matchIndex: Int, seed: UInt64) {
        self.id = id
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.round = round
        self.groupIndex = groupIndex
        self.matchIndex = matchIndex
        self.seed = seed
    }
}

/// The result of a tournament fixture, once played or simulated.
struct FixtureResult: Codable, Equatable {
    var fixtureID: String
    var homeScore: Int
    var awayScore: Int
    /// The team ID that advanced / won. Nil for a group-stage draw
    /// (both teams get 1 point, neither "won" the fixture).
    var winnerTeamID: String?
    /// Goals in chronological order (same format as MatchResult.goals).
    var goals: [Goal]
    /// True when the match was headless-simulated (player did not watch).
    var isSimulated: Bool

    var isDraw: Bool { homeScore == awayScore }
}

// MARK: - FixtureResult + MatchResult bridging

extension FixtureResult {
    /// Convert a full MatchResult into a storable FixtureResult.
    init(from result: MatchResult, fixtureID: String, isSimulated: Bool) {
        self.fixtureID = fixtureID
        self.homeScore = result.homeScore
        self.awayScore = result.awayScore
        self.winnerTeamID = result.winnerTeamID
        self.goals = result.goals
        self.isSimulated = isSimulated
    }

    /// Reconstruct a MatchResult-compatible value for the result screen.
    var asMatchResult: MatchResult {
        MatchResult(homeTeamID: "", awayTeamID: "",
                    homeScore: homeScore, awayScore: awayScore, goals: goals)
    }
}
