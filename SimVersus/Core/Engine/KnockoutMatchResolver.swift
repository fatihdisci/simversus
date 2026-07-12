//  KnockoutMatchResolver.swift
//  Core/Engine
//
//  Pure Swift resolver that turns a (possibly drawn) knockout regulation result
//  into a decisive outcome (Commit 3). A knockout fixture can NEVER stay drawn:
//  a level regulation score goes to deterministic extra time and, if still level,
//  a deterministic penalty shootout.
//
//  Determinism: extra time reuses the deterministic MatchSimulation with an
//  extra-time-namespaced derived seed; penalties are decided by seeds derived
//  per kick from the tournament seed. Same fixture + same seed ⇒ same outcome.
//  Team stats give NO penalty advantage — both sides use one success rate.

import Foundation

/// A decisive knockout result plus the guaranteed-concrete winner.
struct KnockoutMatchOutcome: Equatable {
    let fixtureResult: FixtureResult
    /// Always a concrete team ID — a knockout never ends drawn.
    let winnerTeamID: String
}

enum KnockoutMatchResolver {

    // MARK: - Tunables (named — no magic numbers)

    /// Extra-time length fed to the headless simulation (seconds).
    static let extraTimeDuration: TimeInterval = 10
    /// Kicks each side takes in the regular shootout phase.
    static let regularPenaltyKicks = 5
    /// Success rate (percent) applied identically to both sides.
    static let penaltySuccessPercent: UInt64 = 75
    /// Hard cap on sudden-death rounds before the seeded decider steps in.
    static let maxSuddenDeathRounds = 50

    // MARK: - Resolve

    static func resolve(fixture: Fixture,
                        homeTeam: Team,
                        awayTeam: Team,
                        regulationResult: MatchResult,
                        tournamentSeed: UInt64) -> KnockoutMatchOutcome {

        // 1. Decisive in regulation — keep the result, winner by scoreline.
        if regulationResult.homeScore != regulationResult.awayScore {
            let winner = regulationResult.homeScore > regulationResult.awayScore
                ? homeTeam.id : awayTeam.id
            return outcome(regulationResult, fixture: fixture,
                           resolution: .regulation, winner: winner)
        }

        // 2. Regulation draw → deterministic extra time. The stored scoreline
        //    stays the regulation draw; extra time only decides the winner.
        let etSeed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                  fixtureID: "extratime-\(fixture.id)")
        let et = TournamentEngine.simulateMatch(homeTeam: homeTeam, awayTeam: awayTeam,
                                                seed: etSeed, duration: extraTimeDuration)
        if et.homeScore != et.awayScore {
            let winner = et.homeScore > et.awayScore ? homeTeam.id : awayTeam.id
            return outcome(regulationResult, fixture: fixture,
                           resolution: .extraTime, winner: winner)
        }

        // 3. Still level → deterministic penalty shootout.
        let shootout = resolvePenalties(fixtureID: fixture.id,
                                        tournamentSeed: tournamentSeed)
        let winner = shootout.home > shootout.away ? homeTeam.id : awayTeam.id
        var result = FixtureResult(from: regulationResult, fixtureID: fixture.id, isSimulated: true)
        result.resolution = .penalties
        result.homePenaltyScore = shootout.home
        result.awayPenaltyScore = shootout.away
        result.winnerTeamID = winner
        return KnockoutMatchOutcome(fixtureResult: result, winnerTeamID: winner)
    }

    // MARK: - Helpers

    private static func outcome(_ regulation: MatchResult,
                                fixture: Fixture,
                                resolution: MatchResolution,
                                winner: String) -> KnockoutMatchOutcome {
        var result = FixtureResult(from: regulation, fixtureID: fixture.id, isSimulated: true)
        result.resolution = resolution
        result.winnerTeamID = winner
        result.homePenaltyScore = nil
        result.awayPenaltyScore = nil
        return KnockoutMatchOutcome(fixtureResult: result, winnerTeamID: winner)
    }

    /// Deterministic shootout: 5 kicks each with early clinch, then sudden death,
    /// then a seeded decider as an absolute safety net. Always returns an unequal
    /// tally so a concrete winner exists.
    static func resolvePenalties(fixtureID: String,
                                 tournamentSeed: UInt64) -> (home: Int, away: Int) {
        var home = 0, away = 0
        var homeKicks = 0, awayKicks = 0

        func scored(_ side: String, _ kick: Int) -> Bool {
            let value = TournamentSeedDeriver.derive(
                tournamentSeed: tournamentSeed,
                fixtureID: "penalty-\(fixtureID)-\(side)-\(kick)")
            return value % 100 < penaltySuccessPercent
        }

        // Regular phase — stop as soon as the result is mathematically clinched.
        for kick in 0..<regularPenaltyKicks {
            if scored("home", kick) { home += 1 }
            homeKicks += 1
            if clinched(home: home, away: away, homeKicks: homeKicks, awayKicks: awayKicks) {
                return (home, away)
            }
            if scored("away", kick) { away += 1 }
            awayKicks += 1
            if clinched(home: home, away: away, homeKicks: homeKicks, awayKicks: awayKicks) {
                return (home, away)
            }
        }
        if home != away { return (home, away) }

        // Sudden death — one kick each per round until someone leads.
        var round = 0
        while round < maxSuddenDeathRounds {
            let kick = regularPenaltyKicks + round
            if scored("home", kick) { home += 1 }
            if scored("away", kick) { away += 1 }
            round += 1
            if home != away { return (home, away) }
        }

        // Safety net (astronomically unlikely): a seeded decider breaks the tie.
        let decider = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                   fixtureID: "penalty-final-\(fixtureID)")
        if decider % 2 == 0 { home += 1 } else { away += 1 }
        return (home, away)
    }

    /// True when one side's regular-phase lead can no longer be overturned by the
    /// other side's remaining kicks.
    private static func clinched(home: Int, away: Int, homeKicks: Int, awayKicks: Int) -> Bool {
        let remainingHome = regularPenaltyKicks - homeKicks
        let remainingAway = regularPenaltyKicks - awayKicks
        if home > away + remainingAway { return true }
        if away > home + remainingHome { return true }
        return false
    }
}
