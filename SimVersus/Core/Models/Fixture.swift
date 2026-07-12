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
    /// Matchday (1-based) within a group's round-robin. Nil for knockout
    /// fixtures and for legacy group fixtures created before Commit 3 — the
    /// optional keeps old persisted JSON decodable (synthesized `decodeIfPresent`).
    var matchday: Int?
    /// Deterministic seed for the match engine.
    var seed: UInt64
    /// Encoded FixtureSlotSource for home slot (nil = backward-compatible).
    var _homeSourceData: Data?
    /// Encoded FixtureSlotSource for away slot (nil = backward-compatible).
    var _awaySourceData: Data?

    init(id: String, homeTeamID: String, awayTeamID: String,
         round: Int, groupIndex: Int?, matchIndex: Int, seed: UInt64,
         matchday: Int? = nil,
         homeSource: FixtureSlotSource? = nil,
         awaySource: FixtureSlotSource? = nil) {
        self.id = id
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.round = round
        self.groupIndex = groupIndex
        self.matchIndex = matchIndex
        self.matchday = matchday
        self.seed = seed
        self._homeSourceData = homeSource.flatMap { try? JSONEncoder().encode($0) }
        self._awaySourceData = awaySource.flatMap { try? JSONEncoder().encode($0) }
    }

    /// Creates a new fixture with updated team IDs, preserving the original seed,
    /// matchday and slot sources.
    func withTeams(home: String, away: String) -> Fixture {
        Fixture(id: id, homeTeamID: home, awayTeamID: away,
                round: round, groupIndex: groupIndex,
                matchIndex: matchIndex, seed: seed, matchday: matchday,
                homeSource: _homeSourceData.flatMap { try? JSONDecoder().decode(FixtureSlotSource.self, from: $0) },
                awaySource: _awaySourceData.flatMap { try? JSONDecoder().decode(FixtureSlotSource.self, from: $0) })
    }
}

/// How a fixture reached a decisive result. Group-stage matches are always
/// `.regulation`; a knockout tie is broken by `.extraTime` or `.penalties`.
enum MatchResolution: String, Codable, Equatable {
    case regulation
    case extraTime
    case penalties
}

/// The result of a tournament fixture, once played or simulated.
///
/// Codable is CUSTOM (see the extension below) so results persisted before
/// Commit 3 — which have no `resolution`/penalty keys — still decode: a missing
/// `resolution` defaults to `.regulation` and missing penalty scores to nil.
struct FixtureResult: Equatable {
    var fixtureID: String
    var homeScore: Int
    var awayScore: Int
    /// The team ID that advanced / won. Nil for a group-stage draw
    /// (both teams get 1 point, neither "won" the fixture). For a knockout
    /// fixture this is ALWAYS a concrete team ID (a knockout never stays drawn).
    var winnerTeamID: String?
    /// Goals in chronological order (same format as MatchResult.goals).
    var goals: [Goal]
    /// True when the match was headless-simulated (player did not watch).
    var isSimulated: Bool
    /// How the result was reached. Group stage / regulation wins are `.regulation`.
    var resolution: MatchResolution = .regulation
    /// Shootout tally — only present when `resolution == .penalties`.
    var homePenaltyScore: Int?
    var awayPenaltyScore: Int?

    /// A draw on the regulation scoreline (ignores shootout tallies).
    var isDraw: Bool { homeScore == awayScore }
}

// MARK: - Backward-compatible Codable

extension FixtureResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case fixtureID, homeScore, awayScore, winnerTeamID, goals, isSimulated
        case resolution, homePenaltyScore, awayPenaltyScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fixtureID = try c.decode(String.self, forKey: .fixtureID)
        homeScore = try c.decode(Int.self, forKey: .homeScore)
        awayScore = try c.decode(Int.self, forKey: .awayScore)
        winnerTeamID = try c.decodeIfPresent(String.self, forKey: .winnerTeamID)
        goals = try c.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        isSimulated = try c.decodeIfPresent(Bool.self, forKey: .isSimulated) ?? false
        // New in Commit 3 — default for older records.
        resolution = try c.decodeIfPresent(MatchResolution.self, forKey: .resolution) ?? .regulation
        homePenaltyScore = try c.decodeIfPresent(Int.self, forKey: .homePenaltyScore)
        awayPenaltyScore = try c.decodeIfPresent(Int.self, forKey: .awayPenaltyScore)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(fixtureID, forKey: .fixtureID)
        try c.encode(homeScore, forKey: .homeScore)
        try c.encode(awayScore, forKey: .awayScore)
        try c.encodeIfPresent(winnerTeamID, forKey: .winnerTeamID)
        try c.encode(goals, forKey: .goals)
        try c.encode(isSimulated, forKey: .isSimulated)
        try c.encode(resolution, forKey: .resolution)
        try c.encodeIfPresent(homePenaltyScore, forKey: .homePenaltyScore)
        try c.encodeIfPresent(awayPenaltyScore, forKey: .awayPenaltyScore)
    }
}

// MARK: - FixtureResult + MatchResult bridging

extension FixtureResult {
    /// Convert a full MatchResult into a storable FixtureResult (regulation).
    init(from result: MatchResult, fixtureID: String, isSimulated: Bool) {
        self.fixtureID = fixtureID
        self.homeScore = result.homeScore
        self.awayScore = result.awayScore
        self.winnerTeamID = result.winnerTeamID
        self.goals = result.goals
        self.isSimulated = isSimulated
        self.resolution = .regulation
        self.homePenaltyScore = nil
        self.awayPenaltyScore = nil
    }

    /// Reconstruct a MatchResult-compatible value for the result screen.
    var asMatchResult: MatchResult {
        MatchResult(homeTeamID: "", awayTeamID: "",
                    homeScore: homeScore, awayScore: awayScore, goals: goals)
    }
}
