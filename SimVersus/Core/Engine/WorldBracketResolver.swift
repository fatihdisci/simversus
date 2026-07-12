//  WorldBracketResolver.swift
//  Core/Engine
//
//  Pure Swift engine that converts 32 group-stage qualifiers into a complete
//  deterministic 31-fixture knockout bracket (Commit 4). No SpriteKit, SwiftUI
//  or SwiftData dependency.
//
//  R32 placement uses seeded shuffles + greedy matching with bounded
//  backtracking for same-group avoidance. Subsequent rounds are pre-wired with
//  typed `.winner(of:)` slot sources. The `materialize` function resolves those
//  sources to concrete team IDs as results come in.
//
//  Determinism: all randomness flows through `SeededRandomNumberGenerator`
//  seeded from `TournamentSeedDeriver`. Same qualifiers + same seed ⇒ identical
//  bracket every time.

import Foundation

enum WorldBracketResolver {

    // MARK: - Structural constants

    static let r32MatchCount = 16
    static let r16MatchCount = 8
    static let qfMatchCount = 4
    static let sfMatchCount = 2
    static let finalMatchCount = 1
    static let totalKnockoutFixtures = 31
    static let totalQualifiers = 32
    static let groupCount = 12
    static let seededPoolSize = 16
    static let unseededPoolSize = 16
    static let bestRunnerUpCount = 4

    /// Maximum backtracking nodes before falling back to the greedy result.
    static let maxBacktrackNodes = 10_000

    // MARK: - Round naming

    private static func roundPrefix(_ round: Int) -> String {
        switch round {
        case 1: return "R32"
        case 2: return "R16"
        case 3: return "QF"
        case 4: return "SF"
        case 5: return "F"
        default: return "R\(round)"
        }
    }

    // MARK: - Generate

    /// Generates the complete 31-fixture knockout bracket from qualifiers and
    /// group standings. Same inputs ⇒ identical bracket (deterministic).
    static func generate(
        definition: TournamentDefinition,
        qualifiers: WorldKnockoutQualifiers,
        groupStandings: [GroupStanding],
        tournamentSeed: UInt64
    ) throws -> WorldKnockoutBracket {

        // 0. Build group index lookup from the definition.
        let groupIDs = definition.groups.map(\.id) // A…L
        guard groupIDs.count == groupCount else {
            throw WorldBracketError.invalidBracketShape(
                "Expected \(groupCount) groups, got \(groupIDs.count)")
        }
        let groupIndexByID = Dictionary(uniqueKeysWithValues: zip(groupIDs, groupIDs.indices))

        // Build team → group index map from standings (every standing carries a groupID).
        var teamGroupIndex: [String: Int] = [:]
        for s in groupStandings {
            guard let gid = s.groupID, let gi = groupIndexByID[gid] else { continue }
            teamGroupIndex[s.teamID] = gi
        }

        // 1. Rank the 12 runners-up to find the top 4 (seeded pool).
        let runnerUpIDs = Set(qualifiers.groupRunnersUp)
        let runnerUpStandings = groupStandings.filter { runnerUpIDs.contains($0.teamID) }
        let crossGroupCtx = StandingRankContext.crossGroup(
            tournamentSeed: tournamentSeed, namespace: "runnerup-rank")
        let rankedRunnersUp = TournamentStandingRanker.rank(runnerUpStandings, context: crossGroupCtx)
        let bestRunnersUp = Array(rankedRunnersUp.prefix(bestRunnerUpCount).map(\.teamID))
        let remainingRunnersUp = Array(rankedRunnersUp.dropFirst(bestRunnerUpCount).map(\.teamID))

        // 2. Build Pool A (seeded): 12 winners + 4 best runners-up.
        var poolA: [(teamID: String, groupIndex: Int)] = []
        for (gi, winnerID) in qualifiers.groupWinners.enumerated() {
            poolA.append((winnerID, gi))
        }
        for runnerID in bestRunnersUp {
            guard let gi = teamGroupIndex[runnerID] else {
                throw WorldBracketError.missingGroup("Runner-up \(runnerID) has no group index")
            }
            poolA.append((runnerID, gi))
        }

        // 3. Build Pool B (unseeded): 8 remaining runners-up + 8 best thirds.
        var poolB: [(teamID: String, groupIndex: Int)] = []
        for runnerID in remainingRunnersUp {
            guard let gi = teamGroupIndex[runnerID] else {
                throw WorldBracketError.missingGroup("Runner-up \(runnerID) has no group index")
            }
            poolB.append((runnerID, gi))
        }
        for thirdID in qualifiers.bestThirdPlaced {
            guard let gi = teamGroupIndex[thirdID] else {
                throw WorldBracketError.missingGroup("Best-third \(thirdID) has no group index")
            }
            poolB.append((thirdID, gi))
        }

        guard poolA.count == seededPoolSize, poolB.count == unseededPoolSize else {
            throw WorldBracketError.invalidQualifierCount(poolA.count + poolB.count)
        }

        // 4. Seeded shuffle.
        let poolASeed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                      fixtureID: "bracket-poolA")
        let poolBSeed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                      fixtureID: "bracket-poolB")
        var rngA = SeededRandomNumberGenerator(seed: poolASeed)
        var rngB = SeededRandomNumberGenerator(seed: poolBSeed)
        poolA.shuffle(using: &rngA)
        poolB.shuffle(using: &rngB)

        // 5. Greedy matching.
        var usedB = Array(repeating: false, count: unseededPoolSize)
        var pairings: [(seeded: (teamID: String, groupIndex: Int),
                         unseeded: (teamID: String, groupIndex: Int))] = []
        pairings.reserveCapacity(seededPoolSize)
        var sameGroupCount = 0

        for seeded in poolA {
            var matched = false
            // First pass: try different-group opponent.
            for j in poolB.indices where !usedB[j] && poolB[j].groupIndex != seeded.groupIndex {
                pairings.append((seeded, poolB[j]))
                usedB[j] = true
                matched = true
                break
            }
            if matched { continue }
            // Second pass: accept same-group.
            for j in poolB.indices where !usedB[j] {
                pairings.append((seeded, poolB[j]))
                usedB[j] = true
                matched = true
                sameGroupCount += 1
                break
            }
            guard matched else {
                throw WorldBracketError.generationFailed("No available opponent for \(seeded.teamID)")
            }
        }

        // 6. Bounded backtracking if greedy produced a same-group pairing.
        if sameGroupCount > 0 {
            if let better = backtrackMatch(poolA: poolA, poolB: poolB, maxNodes: maxBacktrackNodes) {
                pairings = better
            }
            // If backtracking fails, keep the greedy result — it's valid.
        }

        // 7. Build R32 fixtures.
        var fixtures: [Fixture] = []
        fixtures.reserveCapacity(totalKnockoutFixtures)
        var matchIndex = 0

        for (i, pairing) in pairings.enumerated() {
            let fixtureID = "WA-\(roundPrefix(1))-M\(i + 1)"
            let seed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed, fixtureID: fixtureID)
            let homeSrc = slotSource(for: pairing.seeded.teamID,
                                     groupIndex: pairing.seeded.groupIndex,
                                     qualifiers: qualifiers)
            let awaySrc = slotSource(for: pairing.unseeded.teamID,
                                     groupIndex: pairing.unseeded.groupIndex,
                                     qualifiers: qualifiers)
            fixtures.append(Fixture(
                id: fixtureID,
                homeTeamID: pairing.seeded.teamID,
                awayTeamID: pairing.unseeded.teamID,
                round: 1,
                groupIndex: nil,
                matchIndex: matchIndex,
                seed: seed,
                homeSource: homeSrc,
                awaySource: awaySrc))
            matchIndex += 1
        }

        // 8. Build R16, QF, SF, Final.
        for round in 2...5 {
            let matchCount: Int
            switch round {
            case 2: matchCount = r16MatchCount
            case 3: matchCount = qfMatchCount
            case 4: matchCount = sfMatchCount
            case 5: matchCount = finalMatchCount
            default: matchCount = 0
            }
            let prevPrefix = roundPrefix(round - 1)
            let curPrefix = roundPrefix(round)

            for i in 0..<matchCount {
                let homeFixtureID = "WA-\(prevPrefix)-M\(i * 2 + 1)"
                let awayFixtureID = "WA-\(prevPrefix)-M\(i * 2 + 2)"
                let fixtureID = "WA-\(curPrefix)-M\(i + 1)"
                let seed = TournamentSeedDeriver.derive(tournamentSeed: tournamentSeed,
                                                        fixtureID: fixtureID)
                fixtures.append(Fixture(
                    id: fixtureID,
                    homeTeamID: "TBD",
                    awayTeamID: "TBD",
                    round: round,
                    groupIndex: nil,
                    matchIndex: matchIndex,
                    seed: seed,
                    homeSource: .winner(of: homeFixtureID),
                    awaySource: .winner(of: awayFixtureID)))
                matchIndex += 1
            }
        }

        // 9. Validate post-conditions.
        guard fixtures.count == totalKnockoutFixtures else {
            throw WorldBracketError.invalidBracketShape(
                "Expected \(totalKnockoutFixtures) fixtures, got \(fixtures.count)")
        }
        let ids = Set(fixtures.map(\.id))
        guard ids.count == totalKnockoutFixtures else {
            throw WorldBracketError.duplicateFixtureID("Duplicate fixture ID detected")
        }
        guard fixtures.allSatisfy({ $0.seed != 0 }) else {
            throw WorldBracketError.invalidBracketShape("Fixture has zero seed")
        }
        let r32Teams = fixtures.filter({ $0.round == 1 }).flatMap { [$0.homeTeamID, $0.awayTeamID] }
        guard Set(r32Teams) == Set(qualifiers.allTeamIDs), r32Teams.count == totalQualifiers else {
            throw WorldBracketError.invalidBracketShape("R32 doesn't cover all 32 qualifiers exactly once")
        }

        return WorldKnockoutBracket(
            fixtures: fixtures,
            createdFromTournamentSeed: tournamentSeed,
            qualifierTeamIDs: qualifiers.allTeamIDs)
    }

    // MARK: - Slot source derivation

    /// Derives the appropriate `FixtureSlotSource` for a qualifier so the bracket
    /// carries semantic "how did this team get here?" information.
    private static func slotSource(for teamID: String,
                                    groupIndex: Int,
                                    qualifiers: WorldKnockoutQualifiers) -> FixtureSlotSource {
        // Check if it's a group winner (rank 0) or runner-up (rank 1).
        if qualifiers.groupWinners.contains(teamID) {
            return .groupRank(groupIndex: groupIndex, rank: 0)
        }
        if qualifiers.groupRunnersUp.contains(teamID) {
            return .groupRank(groupIndex: groupIndex, rank: 1)
        }
        if let thirdIdx = qualifiers.bestThirdPlaced.firstIndex(of: teamID) {
            return .bestThirdPlace(rank: thirdIdx)
        }
        // Fallback — should never happen for valid qualifiers.
        return .team(teamID)
    }

    // MARK: - Bounded backtracking

    /// Tries to find a perfect matching with zero same-group conflicts.
    /// Returns nil if the node budget is exhausted without finding one.
    private static func backtrackMatch(
        poolA: [(teamID: String, groupIndex: Int)],
        poolB: [(teamID: String, groupIndex: Int)],
        maxNodes: Int
    ) -> [(seeded: (teamID: String, groupIndex: Int),
            unseeded: (teamID: String, groupIndex: Int))]? {
        var usedB = Array(repeating: false, count: poolB.count)
        var current: [(seeded: (teamID: String, groupIndex: Int),
                       unseeded: (teamID: String, groupIndex: Int))] = []
        current.reserveCapacity(poolA.count)
        var nodesExplored = 0

        func backtrack(_ seededIdx: Int) -> Bool {
            nodesExplored += 1
            guard nodesExplored <= maxNodes else { return false }

            if seededIdx == poolA.count { return true }

            let seeded = poolA[seededIdx]
            // Try different-group opponents first (heuristic: fewer conflicts).
            for j in poolB.indices where !usedB[j] && poolB[j].groupIndex != seeded.groupIndex {
                usedB[j] = true
                current.append((seeded, poolB[j]))
                if backtrack(seededIdx + 1) { return true }
                current.removeLast()
                usedB[j] = false
            }
            // Then try same-group (worse, but valid).
            for j in poolB.indices where !usedB[j] && poolB[j].groupIndex == seeded.groupIndex {
                usedB[j] = true
                current.append((seeded, poolB[j]))
                if backtrack(seededIdx + 1) { return true }
                current.removeLast()
                usedB[j] = false
            }
            return false
        }

        if backtrack(0) { return current }
        return nil
    }

    // MARK: - Materialize

    /// Resolves `.winner(of:)` and other unresolved slot sources in the given
    /// fixtures against a `SlotResolutionContext`. Returns a new fixture array;
    /// does NOT mutate the input.
    ///
    /// - Only writes a concrete team ID when the source is genuinely resolved
    ///   (never "TBD" fallback).
    /// - Never overwrites an already-concrete team ID with "TBD".
    /// - Idempotent: calling twice with the same context produces the same result.
    static func materialize(
        _ fixtures: [Fixture],
        context: TournamentEngine.SlotResolutionContext
    ) -> [Fixture] {
        fixtures.map { f in
            var fixture = f
            let homeResolved = TournamentEngine.resolveSlot(f.homeSource, context: context)
            let awayResolved = TournamentEngine.resolveSlot(f.awaySource, context: context)

            var newHome = f.homeTeamID
            var newAway = f.awayTeamID

            switch homeResolved {
            case .resolved(let id):
                // Only write if current is unresolved — don't overwrite concrete.
                if newHome == "TBD" || newHome.isEmpty {
                    newHome = id
                }
            case .unresolved:
                break // keep current value
            }

            switch awayResolved {
            case .resolved(let id):
                if newAway == "TBD" || newAway.isEmpty {
                    newAway = id
                }
            case .unresolved:
                break
            }

            if newHome != f.homeTeamID || newAway != f.awayTeamID {
                fixture = f.withTeams(home: newHome, away: newAway)
            }
            return fixture
        }
    }

    // MARK: - Round helpers

    /// Fixtures in the given bracket for a specific round.
    static func fixtures(in bracket: WorldKnockoutBracket, round: Int) -> [Fixture] {
        bracket.fixtures.filter { $0.round == round }.sorted { $0.matchIndex < $1.matchIndex }
    }

    /// True when every fixture in the round has a played result. For rounds
    /// above 1, also verifies that all referenced previous-round fixtures
    /// actually have results (a round can't be "complete" if its slots can't
    /// yet be resolved).
    static func isRoundComplete(
        _ round: Int,
        bracket: WorldKnockoutBracket,
        results: [FixtureResult]
    ) -> Bool {
        let roundFixtures = fixtures(in: bracket, round: round)
        guard !roundFixtures.isEmpty else { return false }
        let playedIDs = Set(results.map(\.fixtureID))
        let allPlayed = roundFixtures.allSatisfy { playedIDs.contains($0.id) }
        guard allPlayed else { return false }

        // For round > 1, also check that the slots are actually resolvable.
        if round > 1 {
            let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.fixtureID, $0) })
            for f in roundFixtures {
                // Every .winner(of:) source must have a result.
                if case .winner(let refID) = f.homeSource {
                    guard resultMap[refID]?.winnerTeamID != nil else { return false }
                }
                if case .winner(let refID) = f.awaySource {
                    guard resultMap[refID]?.winnerTeamID != nil else { return false }
                }
            }
        }
        return true
    }

    /// Returns fixtures whose slots are both concrete (not "TBD") and which
    /// have not yet been played. Ordered by round ascending, then match index.
    static func nextPlayableFixtures(
        in bracket: WorldKnockoutBracket,
        results: [FixtureResult]
    ) -> [Fixture] {
        let playedIDs = Set(results.map(\.fixtureID))
        return bracket.fixtures
            .filter { f in
                guard !playedIDs.contains(f.id) else { return false }
                return f.homeTeamID != "TBD" && f.awayTeamID != "TBD"
                    && !f.homeTeamID.isEmpty && !f.awayTeamID.isEmpty
                    && f.homeTeamID != f.awayTeamID
            }
            .sorted { a, b in
                if a.round != b.round { return a.round < b.round }
                return a.matchIndex < b.matchIndex
            }
    }

    /// The champion team ID — nil until the final has been played and won.
    static func championTeamID(
        in bracket: WorldKnockoutBracket,
        results: [FixtureResult]
    ) -> String? {
        guard let finalFixture = bracket.final else { return nil }
        let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.fixtureID, $0) })
        guard let finalResult = resultMap[finalFixture.id] else { return nil }
        return finalResult.winnerTeamID
    }

    /// The highest round number present in the bracket.
    static func maxRound(in bracket: WorldKnockoutBracket) -> Int {
        bracket.fixtures.map(\.round).max() ?? 0
    }
}
