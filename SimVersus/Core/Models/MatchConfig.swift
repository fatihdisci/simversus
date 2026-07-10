//  MatchConfig.swift
//  Core/Models
//
//  Everything needed to run a match. The `seed` makes the match reproducible:
//  same teams + same seed = same result (CONSTITUTION §7).

import Foundation

struct MatchConfig: Equatable, Hashable {
    let homeTeam: Team
    let awayTeam: Team
    let seed: UInt64
    /// Simulated seconds of play (shown as minutes). Defaults to a full match.
    let duration: TimeInterval

    init(homeTeam: Team,
         awayTeam: Team,
         seed: UInt64 = .random(in: UInt64.min ... UInt64.max),
         duration: TimeInterval = PhysicsConstants.matchDuration) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.seed = seed
        self.duration = duration
    }
}
