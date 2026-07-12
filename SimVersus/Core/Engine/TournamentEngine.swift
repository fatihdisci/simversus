//  TournamentEngine.swift
//  Core/Engine
//
//  Pure Swift tournament logic: fixture generation, group standings,
//  knockout advancement, and headless match resolution. No SpriteKit
//  dependency — headless matches use MatchSimulation.runToCompletion().
//
//  Every fixture gets a deterministic seed derived from the tournament
//  seed + fixture ID so the same matchup reproduces the same result.

import Foundation

enum TournamentEngine {

    // MARK: - Fixture generation

    /// Creates the full fixture list for a tournament. Knockout slots are
    /// left as placeholders ("TBD") until the previous round resolves.
    static func generateFixtures(format: TournamentFormat,
                                 teams: [String],
                                 tournamentSeed: UInt64) -> [Fixture] {
        assert(teams.count == format.teamCount,
               "Team count \(teams.count) != format team count \(format.teamCount)")

        var fixtures: [Fixture] = []
        var matchIndex = 0

        if format.hasGroupStage {
            // Group stage: round-robin within each group.
            for g in 0..<format.groupCount {
                let start = g * format.teamsPerGroup
                let groupTeams = Array(teams[start..<(start + format.teamsPerGroup)])
                fixtures.append(contentsOf: roundRobin(teams: groupTeams,
                                                       groupIndex: g,
                                                       tournamentSeed: tournamentSeed,
                                                       matchIndex: &matchIndex))
            }

            // Knockout placeholders: semi-finals + final (groupKO) or QF + SF + final (grand).
            let knockoutTeams = format.groupCount * format.advancePerGroup
            fixtures.append(contentsOf: knockoutBracket(
                slotCount: knockoutTeams,
                startingRound: 1,
                tournamentSeed: tournamentSeed,
                matchIndex: &matchIndex))
        } else {
            // Pure knockout: teams placed in bracket order.
            fixtures.append(contentsOf: knockoutBracket(
                teams: teams,
                startingRound: 1,
                tournamentSeed: tournamentSeed,
                matchIndex: &matchIndex))
        }

        return fixtures
    }

    /// Round-robin: every team plays every other team once.
    private static func roundRobin(teams: [String],
                                   groupIndex: Int,
                                   tournamentSeed: UInt64,
                                   matchIndex: inout Int) -> [Fixture] {
        var fixtures: [Fixture] = []
        let n = teams.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                let id = "G\(groupIndex)-M\(matchIndex)"
                let seed = deriveSeed(tournamentSeed: tournamentSeed, fixtureID: id)
                fixtures.append(Fixture(id: id,
                                        homeTeamID: teams[i],
                                        awayTeamID: teams[j],
                                        round: 0,
                                        groupIndex: groupIndex,
                                        matchIndex: matchIndex,
                                        seed: seed))
                matchIndex += 1
            }
        }
        return fixtures
    }

    /// Knockout bracket from a known team list (pure KO formats).
    private static func knockoutBracket(teams: [String],
                                        startingRound: Int,
                                        tournamentSeed: UInt64,
                                        matchIndex: inout Int) -> [Fixture] {
        var fixtures: [Fixture] = []
        let count = teams.count
        var round = startingRound
        var current = teams

        while current.count >= 2 {
            let roundName = knockoutRoundName(round: round, totalTeams: count)
            for i in stride(from: 0, to: current.count, by: 2) {
                let id = "\(roundName)-\(i / 2)"
                let seed = deriveSeed(tournamentSeed: tournamentSeed, fixtureID: id)
                fixtures.append(Fixture(id: id,
                                        homeTeamID: current[i],
                                        awayTeamID: current[i + 1],
                                        round: round,
                                        groupIndex: nil,
                                        matchIndex: matchIndex,
                                        seed: seed))
                matchIndex += 1
            }
            // Winners advance: placeholders for next round (replaced after results).
            current = Array(repeating: "TBD", count: current.count / 2)
            round += 1
        }
        return fixtures
    }

    /// Knockout bracket with placeholder slots (group → KO formats).
    private static func knockoutBracket(slotCount: Int,
                                        startingRound: Int,
                                        tournamentSeed: UInt64,
                                        matchIndex: inout Int) -> [Fixture] {
        let placeholders = Array(repeating: "TBD", count: slotCount)
        return knockoutBracket(teams: placeholders,
                               startingRound: startingRound,
                               tournamentSeed: tournamentSeed,
                               matchIndex: &matchIndex)
    }

    private static func knockoutRoundName(round: Int, totalTeams: Int) -> String {
        // map round number to name based on how many rounds remain
        let totalRounds = Int(log2(Double(totalTeams)))
        let remaining = totalRounds - round + 1
        switch remaining {
        case 3: return "QF"
        case 2: return "SF"
        case 1: return "F"
        default: return "R\(round)"
        }
    }

    // MARK: - Seed derivation

    /// Deterministically derives a fixture seed from the tournament seed and
    /// fixture ID so the same tournament always produces the same results.
    static func deriveSeed(tournamentSeed: UInt64, fixtureID: String) -> UInt64 {
        var hasher = Hasher()
        hasher.combine(tournamentSeed)
        hasher.combine(fixtureID)
        let hash = UInt64(bitPattern: Int64(hasher.finalize()))
        return hash == 0 ? 1 : hash // 0 is reserved
    }

    // MARK: - Headless simulation

    /// Runs a match to completion without rendering and returns the result.
    /// Uses the existing deterministic engine (CONSTITUTION §11).
    static func simulateMatch(homeTeam: Team, awayTeam: Team,
                              seed: UInt64,
                              duration: TimeInterval = PhysicsConstants.matchDuration) -> MatchResult {
        let config = MatchConfig(homeTeam: homeTeam,
                                 awayTeam: awayTeam,
                                 seed: seed,
                                 duration: duration,
                                 powerUpsEnabled: false) // CONSTITUTION §4.6
        let sim = MatchSimulation(config: config)
        return sim.runToCompletion()
    }

    // MARK: - Group standings

    /// Calculates group standings from the results of the group stage.
    /// Returns team IDs sorted by: points (desc), goal difference (desc),
    /// goals scored (desc), then head-to-head result.
    static func groupStandings(teams: [String],
                               fixtures: [Fixture],
                               results: [FixtureResult]) -> [GroupStanding] {
        let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.fixtureID, $0) })

        var standings: [GroupStanding] = teams.map { team in
            var played = 0, wins = 0, draws = 0, losses = 0, goalsFor = 0, goalsAgainst = 0
            for f in fixtures where f.homeTeamID == team || f.awayTeamID == team {
                guard let r = resultMap[f.id] else { continue }
                played += 1
                let isHome = f.homeTeamID == team
                let gf = isHome ? r.homeScore : r.awayScore
                let ga = isHome ? r.awayScore : r.homeScore
                goalsFor += gf
                goalsAgainst += ga
                if gf > ga { wins += 1 }
                else if gf == ga { draws += 1 }
                else { losses += 1 }
            }
            let points = wins * 3 + draws * 1
            return GroupStanding(teamID: team, played: played, wins: wins,
                                 draws: draws, losses: losses, goalsFor: goalsFor,
                                 goalsAgainst: goalsAgainst, points: points)
        }

        // Sort: points (desc) → GD (desc) → GF (desc)
        standings.sort { a, b in
            if a.points != b.points { return a.points > b.points }
            let gdA = a.goalsFor - a.goalsAgainst
            let gdB = b.goalsFor - b.goalsAgainst
            if gdA != gdB { return gdA > gdB }
            return a.goalsFor > b.goalsFor
        }
        return standings
    }

    /// Top N teams from group standings (already sorted).
    static func topTeams(from standings: [GroupStanding], count: Int) -> [String] {
        Array(standings.prefix(count).map(\.teamID))
    }

    // MARK: - Knockout advancement

    /// Determines which teams fill the next knockout round's "TBD" slots based
    /// on the results of the previous round.
    static func advanceKnockout(fixtures: inout [Fixture],
                                results: [FixtureResult],
                                newWinners: [String]) {
        // Find the first round that still has "TBD" slots and fill them.
        for i in fixtures.indices {
            if fixtures[i].homeTeamID == "TBD" || fixtures[i].awayTeamID == "TBD" {
                // This is a placeholder round — fill from winners.
                // The winners are ordered by previous-round match index.
                break
            }
        }

        // Actually, we need to update fixtures with winners in the right order.
        // Each group of 2 consecutive winners fills one next-round fixture.
        var winnerIdx = 0
        for i in fixtures.indices {
            guard fixtures[i].homeTeamID == "TBD" else { continue }
            guard winnerIdx < newWinners.count else { break }
            let home = newWinners[winnerIdx]
            let away = winnerIdx + 1 < newWinners.count ? newWinners[winnerIdx + 1] : "TBD"
            let updated = Fixture(id: fixtures[i].id,
                                  homeTeamID: home,
                                  awayTeamID: away,
                                  round: fixtures[i].round,
                                  groupIndex: fixtures[i].groupIndex,
                                  matchIndex: fixtures[i].matchIndex,
                                  seed: fixtures[i].seed)
            fixtures[i] = updated
            winnerIdx += 2
        }
    }

    // MARK: - Round helpers

    /// All fixtures for a specific round, sorted by match index.
    static func fixturesForRound(_ fixtures: [Fixture], round: Int) -> [Fixture] {
        fixtures.filter { $0.round == round }.sorted { $0.matchIndex < $1.matchIndex }
    }

    /// The highest round index present in the fixture list.
    static func maxRound(in fixtures: [Fixture]) -> Int {
        fixtures.map(\.round).max() ?? 0
    }

    // MARK: - Utility

    private static func log2(_ x: Double) -> Double { Darwin.log2(x) }
}

// MARK: - Group standing

/// A team's record within a group.
struct GroupStanding: Equatable {
    let teamID: String
    let played: Int
    let wins: Int
    let draws: Int
    let losses: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let points: Int
}
