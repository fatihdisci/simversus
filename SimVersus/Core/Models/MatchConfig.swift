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
    /// Whether in-arena power-ups spawn. Off for tournament/ranked modes
    /// (CONSTITUTION §4.6); on for casual play.
    let powerUpsEnabled: Bool

    init(homeTeam: Team,
         awayTeam: Team,
         seed: UInt64 = .random(in: UInt64.min ... UInt64.max),
         duration: TimeInterval = PhysicsConstants.matchDuration,
         powerUpsEnabled: Bool = true) {
        self.homeTeam = homeTeam
        self.awayTeam = awayTeam
        self.seed = seed
        self.duration = duration
        self.powerUpsEnabled = powerUpsEnabled
    }
}
