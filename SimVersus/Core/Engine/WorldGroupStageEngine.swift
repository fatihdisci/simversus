//  WorldGroupStageEngine.swift
//  Core/Engine
//
//  Pure Swift group-stage engine for World Arena 2026 (Commit 3). No SpriteKit,
//  SwiftUI or SwiftData dependency. Produces a deterministic 48-team draw,
//  72 group fixtures, group standings and the best-third ranking.
//
//  This is a deterministic game draw, not an implementation of official
//  confederation draw constraints (no confederation separation is applied).
//
//  Determinism: all randomness flows through `SeededRandomNumberGenerator`
//  seeded from `TournamentSeedDeriver` (FNV-1a). No `Hasher`, no UUID ordering,
//  no `SystemRandomNumberGenerator`, no global `random()`.

import Foundation

enum WorldGroupStageError: Error, Equatable {
    /// The definition/catalog did not describe a 4-pot × 12-group / 48-team draw.
    case malformedDefinition(String)
    /// A qualifier query was made before every group finished its six matches.
    case groupStageIncomplete
}

enum WorldGroupStageEngine {

    // MARK: - Structural constants (named — no magic numbers)

    /// Teams per World Arena group.
    static let teamsPerGroup = 4
    /// Group fixtures per group (single round-robin of 4 → C(4,2)).
    static let fixturesPerGroup = 6
    /// Matchdays per group.
    static let matchdayCount = 3

    /// Single round-robin schedule for a 4-team group, expressed as index pairs
    /// into the group's `teamIDs` (home, away). Balanced so two teams get two
    /// home games and two get one — every team plays exactly once per matchday.
    ///
    ///   MD1:  T0 v T3,  T1 v T2
    ///   MD2:  T2 v T0,  T3 v T1
    ///   MD3:  T0 v T1,  T2 v T3
    private static let roundRobinSchedule: [(matchday: Int, matches: [(home: Int, away: Int)])] = [
        (1, [(0, 3), (1, 2)]),
        (2, [(2, 0), (3, 1)]),
        (3, [(0, 1), (2, 3)]),
    ]

    // MARK: - Draw

    /// Draws 48 teams into 12 groups, one team from each of the 4 pots per group.
    /// Each pot is shuffled with a pot-namespaced seeded RNG, then dealt A…L.
    /// Same `tournamentSeed` ⇒ identical groups; different seeds are expected to
    /// change at least one group.
    static func drawGroups(definition: TournamentDefinition,
                           teams: [NationalTeamDefinition],
                           tournamentSeed: UInt64) throws -> [GroupAssignment] {
        let groupIDs = definition.groups.map(\.id)
        let groupCount = groupIDs.count
        let pots = definition.pots

        guard groupCount > 0 else {
            throw WorldGroupStageError.malformedDefinition("no groups declared")
        }
        guard pots.count == teamsPerGroup else {
            throw WorldGroupStageError.malformedDefinition(
                "expected \(teamsPerGroup) pots, got \(pots.count)")
        }
        guard pots.allSatisfy({ $0.count == groupCount }) else {
            throw WorldGroupStageError.malformedDefinition(
                "each pot must hold exactly \(groupCount) teams")
        }
        let knownIDs = Set(teams.map(\.id))
        guard pots.allSatisfy({ $0.allSatisfy(knownIDs.contains) }) else {
            throw WorldGroupStageError.malformedDefinition("pot references an unknown team")
        }

        // Deal one team from each pot into each group.
        var groupTeamIDs = Array(repeating: [String](), count: groupCount)
        for (potIndex, pot) in pots.enumerated() {
            var rng = SeededRandomNumberGenerator(
                seed: TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                   fixtureID: "draw-pot-\(potIndex)"))
            let shuffled = pot.shuffled(using: &rng)
            for (groupIndex, teamID) in shuffled.enumerated() {
                groupTeamIDs[groupIndex].append(teamID)
            }
        }

        let assignments = zip(groupIDs, groupTeamIDs).map {
            GroupAssignment(id: $0.0, teamIDs: $0.1)
        }

        // Post-conditions: 12×4, all 48 unique.
        let allIDs = assignments.flatMap(\.teamIDs)
        guard assignments.allSatisfy({ $0.teamIDs.count == teamsPerGroup }),
              Set(allIDs).count == allIDs.count,
              allIDs.count == groupCount * teamsPerGroup else {
            throw WorldGroupStageError.malformedDefinition("draw produced an invalid group set")
        }
        return assignments
    }

    // MARK: - Fixtures

    /// Generates the 72 group fixtures (6 per group, 3 matchdays × 2 matches).
    /// Fixture IDs are stable and readable ("WA-GA-MD1-M1"); each carries a seed
    /// derived from the tournament seed + fixture ID, and concrete `.team` slot
    /// sources (never TBD/pending).
    static func generateFixtures(groups: [GroupAssignment],
                                 tournamentSeed: UInt64) -> [Fixture] {
        var fixtures: [Fixture] = []
        var matchIndex = 0

        for (groupIndex, group) in groups.enumerated() {
            precondition(group.teamIDs.count == teamsPerGroup,
                         "World Arena groups must contain exactly \(teamsPerGroup) teams")
            let t = group.teamIDs
            for day in roundRobinSchedule {
                for (slot, pair) in day.matches.enumerated() {
                    let homeID = t[pair.home]
                    let awayID = t[pair.away]
                    let id = "WA-G\(group.id)-MD\(day.matchday)-M\(slot + 1)"
                    let seed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                            fixtureID: id)
                    fixtures.append(Fixture(id: id,
                                            homeTeamID: homeID,
                                            awayTeamID: awayID,
                                            round: 0,
                                            groupIndex: groupIndex,
                                            matchIndex: matchIndex,
                                            seed: seed,
                                            matchday: day.matchday,
                                            homeSource: .team(homeID),
                                            awaySource: .team(awayID)))
                    matchIndex += 1
                }
            }
        }
        return fixtures
    }

    // MARK: - Standings

    /// Standings for one group, ranked by the central `TournamentStandingRanker`.
    /// Only played fixtures count; duplicate results are de-duplicated (and flagged
    /// in debug builds) so a team is never counted twice.
    static func standings(for group: GroupAssignment,
                          fixtures: [Fixture],
                          results: [FixtureResult],
                          tournamentSeed: UInt64) -> [GroupStanding] {
        let groupTeams = Set(group.teamIDs)
        let groupFixtures = fixtures.filter {
            groupTeams.contains($0.homeTeamID) && groupTeams.contains($0.awayTeamID)
        }
        let resultMap = dedupedResultMap(results)

        let raw: [GroupStanding] = group.teamIDs.map { team in
            var played = 0, wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0
            for f in groupFixtures where f.homeTeamID == team || f.awayTeamID == team {
                guard let r = resultMap[f.id] else { continue }
                played += 1
                let isHome = f.homeTeamID == team
                let gf = isHome ? r.homeScore : r.awayScore
                let ga = isHome ? r.awayScore : r.homeScore
                goalsFor += gf
                goalsAgainst += ga
                if gf > ga { wins += 1 } else if gf == ga { draws += 1 } else { losses += 1 }
            }
            return GroupStanding(teamID: team, played: played, wins: wins, draws: draws,
                                 losses: losses, goalsFor: goalsFor, goalsAgainst: goalsAgainst,
                                 points: wins * 3 + draws, groupID: group.id)
        }

        let context = StandingRankContext(
            headToHead: { a, b in headToHead(a, b, fixtures: groupFixtures, resultMap: resultMap) },
            seededTiebreak: { teamID in
                TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                             fixtureID: "standing-tiebreak-\(teamID)")
            })
        return TournamentStandingRanker.rank(raw, context: context)
    }

    // MARK: - Best third-placed teams

    /// The twelve third-placed teams, ranked against each other. No head-to-head
    /// is used (third-placed teams from different groups never met); ordering is
    /// points → GD → GF → wins → seeded tiebreak.
    static func rankThirdPlacedTeams(groups: [GroupAssignment],
                                     fixtures: [Fixture],
                                     results: [FixtureResult],
                                     tournamentSeed: UInt64) -> [GroupStanding] {
        let thirds: [GroupStanding] = groups.compactMap { group in
            let table = standings(for: group, fixtures: fixtures,
                                  results: results, tournamentSeed: tournamentSeed)
            // A World Arena group always has four teams, so index 2 exists.
            return table.count >= 3 ? table[2] : nil
        }
        let context = StandingRankContext.crossGroup(tournamentSeed: tournamentSeed,
                                                     namespace: "third-tiebreak")
        return TournamentStandingRanker.rank(thirds, context: context)
    }

    /// The eight best third-placed team IDs that qualify for the Round of 32.
    /// Throws `groupStageIncomplete` unless every group has played all six
    /// matches — it never returns a partial/guessed list.
    static func bestThirdPlacedQualifiers(groups: [GroupAssignment],
                                          fixtures: [Fixture],
                                          results: [FixtureResult],
                                          tournamentSeed: UInt64) throws -> [String] {
        let resultMap = dedupedResultMap(results)
        for group in groups {
            let groupTeams = Set(group.teamIDs)
            let groupFixtures = fixtures.filter {
                groupTeams.contains($0.homeTeamID) && groupTeams.contains($0.awayTeamID)
            }
            let complete = groupFixtures.count == fixturesPerGroup
                && groupFixtures.allSatisfy { resultMap[$0.id] != nil }
            guard complete else { throw WorldGroupStageError.groupStageIncomplete }
        }

        let ranked = rankThirdPlacedTeams(groups: groups, fixtures: fixtures,
                                          results: results, tournamentSeed: tournamentSeed)
        let qualifiers = ranked.prefix(bestThirdQualifierCount).map(\.teamID)
        guard qualifiers.count == bestThirdQualifierCount,
              Set(qualifiers).count == qualifiers.count else {
            throw WorldGroupStageError.groupStageIncomplete
        }
        return Array(qualifiers)
    }

    /// Best third-placed teams that advance (24 direct + 8 best thirds = 32).
    static let bestThirdQualifierCount = 8

    // MARK: - Helpers

    /// Builds a fixtureID → result map, de-duplicating repeated results. In debug
    /// builds a duplicate is a hard signal (assertion); in release the first
    /// result wins so a team is never double-counted.
    private static func dedupedResultMap(_ results: [FixtureResult]) -> [String: FixtureResult] {
        var map: [String: FixtureResult] = [:]
        map.reserveCapacity(results.count)
        for r in results {
            if map[r.fixtureID] != nil {
                assertionFailure("Duplicate FixtureResult for \(r.fixtureID)")
                continue
            }
            map[r.fixtureID] = r
        }
        return map
    }

    /// Head-to-head between two teams within a set of fixtures: +1 if `a` won the
    /// direct meeting, -1 if `b` won, 0 if drawn, nil if they did not meet.
    private static func headToHead(_ a: String, _ b: String,
                                   fixtures: [Fixture],
                                   resultMap: [String: FixtureResult]) -> Int? {
        for f in fixtures {
            let direct = (f.homeTeamID == a && f.awayTeamID == b)
                || (f.homeTeamID == b && f.awayTeamID == a)
            guard direct, let r = resultMap[f.id] else { continue }
            let aHome = f.homeTeamID == a
            let ga = aHome ? r.homeScore : r.awayScore
            let gb = aHome ? r.awayScore : r.homeScore
            if ga > gb { return 1 }
            if gb > ga { return -1 }
            return 0
        }
        return nil
    }
}
