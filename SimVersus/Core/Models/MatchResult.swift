//  MatchResult.swift
//  Core/Models
//
//  The outcome of a match: final score, the goals in order, and the winner.

import Foundation

/// A single goal: the display minute it was scored and the team that scored it.
struct Goal: Equatable, Codable, Hashable {
    let minute: Int
    let teamID: String
}

struct MatchResult: Equatable, Codable, Hashable {
    let homeTeamID: String
    let awayTeamID: String
    let homeScore: Int
    let awayScore: Int
    /// Goals in chronological order.
    let goals: [Goal]

    /// The winning team's id, or `nil` for a draw.
    var winnerTeamID: String? {
        if homeScore > awayScore { return homeTeamID }
        if awayScore > homeScore { return awayTeamID }
        return nil
    }

    var isDraw: Bool { homeScore == awayScore }
}
