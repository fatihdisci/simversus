//  TournamentStandingRanker.swift
//  Core/Engine
//
//  The single source of truth for ordering group standings (Commit 3). Replaces
//  ad-hoc sort closures scattered through the engine with one comparator so
//  every World Arena ranking — within a group and across groups for the best
//  third-placed teams — obeys the same rules.
//
//  World Arena ordering (highest first):
//    1. Points
//    2. Goal difference
//    3. Goals scored
//    4. Wins
//    5. Head-to-head — ONLY when exactly two teams remain tied (see note)
//    6. Deterministic seeded tiebreak (from the tournament seed, never alphabetical)
//
//  Head-to-head note: applying pairwise head-to-head across three or more tied
//  teams produces a non-transitive order that breaks `sort`. So H2H is applied
//  only to two-team ties; three-or-more-way ties fall straight through to the
//  seeded tiebreak, which is a genuine total order.

import Foundation

/// Context the ranker needs beyond the standings themselves: how two teams met
/// (for the two-team tiebreak) and a deterministic per-team seed value.
struct StandingRankContext {
    /// Direct meeting result: +1 if `a` finished ahead of `b`, -1 if `b` ahead,
    /// 0 if drawn, nil if they never met (or are in different groups).
    let headToHead: (_ a: String, _ b: String) -> Int?
    /// A stable per-team value derived from the tournament seed. Compared as the
    /// final tiebreak; identical input + seed always yields the same order.
    let seededTiebreak: (_ teamID: String) -> UInt64

    /// Cross-group context: no head-to-head (teams never played), only the
    /// seeded tiebreak. Used for ranking the best third-placed teams.
    static func crossGroup(tournamentSeed: UInt64, namespace: String) -> StandingRankContext {
        StandingRankContext(
            headToHead: { _, _ in nil },
            seededTiebreak: { teamID in
                TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                             fixtureID: "\(namespace)-\(teamID)")
            })
    }
}

enum TournamentStandingRanker {

    /// Returns the standings ordered by the World Arena rules. Deterministic:
    /// same standings + same context always produce the same order.
    static func rank(_ standings: [GroupStanding], context: StandingRankContext) -> [GroupStanding] {
        // Precompute the seeded tiebreak once per team — never inside the sort.
        let tiebreak = Dictionary(uniqueKeysWithValues:
            standings.map { ($0.teamID, context.seededTiebreak($0.teamID)) })

        var ordered = standings.sorted { numericPrecedes($0, $1, tiebreak: tiebreak) }
        applyTwoTeamHeadToHead(&ordered, context: context)
        return ordered
    }

    /// Strict-weak (in fact total) ordering on the numeric keys plus the seeded
    /// tiebreak and, as an absolute last resort, the team ID. Exposed for tests
    /// that assert transitivity/stability. Returns true when `a` should rank
    /// ahead of `b`.
    static func numericPrecedes(_ a: GroupStanding, _ b: GroupStanding,
                                tiebreak: [String: UInt64]) -> Bool {
        if a.points != b.points { return a.points > b.points }
        if a.goalDifference != b.goalDifference { return a.goalDifference > b.goalDifference }
        if a.goalsFor != b.goalsFor { return a.goalsFor > b.goalsFor }
        if a.wins != b.wins { return a.wins > b.wins }
        let ta = tiebreak[a.teamID] ?? 0
        let tbv = tiebreak[b.teamID] ?? 0
        if ta != tbv { return ta < tbv }        // lower derived value ranks higher
        return a.teamID < b.teamID               // absolute deterministic final key
    }

    /// True when two standings tie on all four numeric keys (points, GD, GF, wins).
    private static func tiedOnNumericKeys(_ a: GroupStanding, _ b: GroupStanding) -> Bool {
        a.points == b.points
            && a.goalDifference == b.goalDifference
            && a.goalsFor == b.goalsFor
            && a.wins == b.wins
    }

    /// For each run of teams tied on the numeric keys that has EXACTLY two
    /// members, order them by their head-to-head result if decisive. Runs of
    /// three or more are left in seeded order (avoids non-transitive H2H chains).
    private static func applyTwoTeamHeadToHead(_ s: inout [GroupStanding],
                                               context: StandingRankContext) {
        var i = 0
        while i < s.count {
            var j = i + 1
            while j < s.count && tiedOnNumericKeys(s[i], s[j]) { j += 1 }
            if j - i == 2, let h = context.headToHead(s[i].teamID, s[i + 1].teamID), h != 0 {
                // A negative result means the second team beat the first — swap so
                // the head-to-head winner sits first.
                if h < 0 { s.swapAt(i, i + 1) }
            }
            i = j
        }
    }
}
