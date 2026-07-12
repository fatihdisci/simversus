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
    /// fixture ID using FNV-1a 64-bit. Unlike Swift's Hasher, this produces
    /// identical output across process launches — same tournamentSeed + same
    /// fixtureID always yields the same UInt64 (CONSTITUTION §11).
    static func deriveSeed(tournamentSeed: UInt64, fixtureID: String) -> UInt64 {
        TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed, fixtureID: fixtureID)
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

    // MARK: - World Arena group stage

    /// Facade over `WorldGroupStageEngine`: draws the 48-team field and generates
    /// all 72 group fixtures as one aggregate. Leaves the legacy mini/classic/
    /// groupKO/grand flow untouched. Throws if the definition is not a valid
    /// 4-pot × 12-group / 48-team World Arena shape.
    static func generateWorldGroupStage(definition: TournamentDefinition,
                                        catalog: NationalTeamStore,
                                        tournamentSeed: UInt64) throws -> WorldGroupStage {
        let groups = try WorldGroupStageEngine.drawGroups(definition: definition,
                                                          teams: catalog.allTeams,
                                                          tournamentSeed: tournamentSeed)
        let fixtures = WorldGroupStageEngine.generateFixtures(groups: groups,
                                                              tournamentSeed: tournamentSeed)
        return WorldGroupStage(groups: groups, fixtures: fixtures)
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

        // Sort: 1. points → 2. wins → 3. GD → 4. GF → 5. H2H → 6. seed tiebreak
        standings.sort { a, b in
            if a.points != b.points { return a.points > b.points }
            if a.wins != b.wins { return a.wins > b.wins }
            let gdA = a.goalsFor - a.goalsAgainst
            let gdB = b.goalsFor - b.goalsAgainst
            if gdA != gdB { return gdA > gdB }
            if a.goalsFor != b.goalsFor { return a.goalsFor > b.goalsFor }
            // Head-to-head: check direct result between these two teams.
            if let h2h = headToHead(a.teamID, b.teamID, fixtures: fixtures, resultMap: resultMap) {
                if h2h != 0 { return h2h > 0 }
            }
            // Deterministic seed tiebreak (last resort).
            return a.teamID < b.teamID
        }
        return standings
    }

    /// Top N teams from group standings (already sorted).
    static func topTeams(from standings: [GroupStanding], count: Int) -> [String] {
        Array(standings.prefix(count).map(\.teamID))
    }

    // MARK: - Knockout advancement

    /// Fills the next knockout round's unresolved slots using the provided
    /// winners. Slots are resolved by their FixtureSlotSource: a group rank
    /// source consumes the corresponding team from the advancing list; a
    /// "winner of" source resolves after the referenced fixture completes.
    /// This replaces the old "TBD" sequential fill with typed slot resolution.
    static func advanceKnockout(fixtures: inout [Fixture],
                                results: [FixtureResult],
                                newWinners: [String]) {
        let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.fixtureID, $0) })

        for i in fixtures.indices {
            let f = fixtures[i]

            // Only fill slots in the next round (round > current max-resolved).
            guard f.round > 0, f.homeTeamID == "TBD" || f.awayTeamID == "TBD" else { continue }

            let homeResolved = resolveSlot(f.homeSource, winners: newWinners,
                                           resultMap: resultMap,
                                           fallbackID: f.homeTeamID)
            let awayResolved = resolveSlot(f.awaySource, winners: newWinners,
                                           resultMap: resultMap,
                                           fallbackID: f.awayTeamID)

            if homeResolved != f.homeTeamID || awayResolved != f.awayTeamID {
                fixtures[i] = f.withTeams(home: homeResolved, away: awayResolved)
            }
        }

        // Fallback: if no sources were stored (legacy tournaments), fill
        // sequentially as before.
        if !fixtures.contains(where: { $0.homeTeamID == "TBD" || $0.awayTeamID == "TBD" }) {
            return
        }
        var winnerIdx = 0
        for i in fixtures.indices where fixtures[i].homeTeamID == "TBD" {
            guard winnerIdx < newWinners.count else { break }
            let home = newWinners[winnerIdx]
            let away = winnerIdx + 1 < newWinners.count ? newWinners[winnerIdx + 1] : "TBD"
            fixtures[i] = fixtures[i].withTeams(home: home, away: away)
            winnerIdx += 2
        }
    }

    /// Resolves a single FixtureSlotSource to a concrete team ID.
    private static func resolveSlot(_ source: FixtureSlotSource,
                                    winners: [String],
                                    resultMap: [String: FixtureResult],
                                    fallbackID: String) -> String {
        switch source {
        case .team(let id):
            return id
        case .groupRank(let groupIndex, let rank):
            // `winners` is ordered [G0R0, G0R1, G1R0, G1R1, ...]
            // per-group advance count determines stride.
            // For now the caller pre-orders winners correctly.
            let idx = groupIndex * 2 + rank // assumes advancePerGroup=2
            return idx < winners.count ? winners[idx] : "TBD"
        case .bestThirdPlace(let rank):
            return rank < winners.count ? winners[rank] : "TBD"
        case .winner(let fixtureID):
            if let result = resultMap[fixtureID] {
                return result.winnerTeamID
                    ?? (result.homeScore >= result.awayScore
                        ? fallbackID : fallbackID)
            }
            return "TBD"
        case .pending:
            return fallbackID == "TBD" ? "TBD" : fallbackID
        }
    }

    // MARK: - Head-to-head tiebreak

    /// Returns the net goal difference for teamA vs teamB in their direct
    /// encounter. Positive = teamA ahead, negative = teamB ahead, nil = no
    /// direct fixture found or drawn match.
    private static func headToHead(_ teamA: String, _ teamB: String,
                                   fixtures: [Fixture],
                                   resultMap: [String: FixtureResult]) -> Int? {
        for f in fixtures {
            guard (f.homeTeamID == teamA && f.awayTeamID == teamB)
                    || (f.homeTeamID == teamB && f.awayTeamID == teamA),
                  let r = resultMap[f.id] else { continue }
            let isAHome = f.homeTeamID == teamA
            let goalsA = isAHome ? r.homeScore : r.awayScore
            let goalsB = isAHome ? r.awayScore : r.homeScore
            if goalsA > goalsB { return 1 }
            if goalsB > goalsA { return -1 }
            return 0 // draw in H2H
        }
        return nil
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

/// A team's record within a group. Codable + Identifiable so standings can be
/// persisted and diffed; `goalDifference` is computed (never stored twice).
/// `groupID` is optional context — nil for legacy callers, set by the World
/// Arena engine so a standing knows which group it belongs to.
struct GroupStanding: Codable, Equatable, Identifiable {
    let teamID: String
    let played: Int
    let wins: Int
    let draws: Int
    let losses: Int
    let goalsFor: Int
    let goalsAgainst: Int
    let points: Int
    /// Which group this record belongs to (e.g. "A"). Optional for backward
    /// compatibility with the legacy `TournamentEngine.groupStandings` caller.
    var groupID: String?

    var id: String { teamID }

    /// Goals scored minus conceded — computed, so it can never drift from the
    /// stored goal totals.
    var goalDifference: Int { goalsFor - goalsAgainst }

    init(teamID: String, played: Int, wins: Int, draws: Int, losses: Int,
         goalsFor: Int, goalsAgainst: Int, points: Int, groupID: String? = nil) {
        self.teamID = teamID
        self.played = played
        self.wins = wins
        self.draws = draws
        self.losses = losses
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.points = points
        self.groupID = groupID
    }
}
