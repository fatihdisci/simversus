//  WorldKnockoutBracket.swift
//  Core/Models
//
//  Typed models for the World Arena knockout stage (Commit 4). A
//  WorldKnockoutBracket carries 31 deterministically-generated fixtures
//  (16 R32 + 8 R16 + 4 QF + 2 SF + 1 Final) plus the qualifier metadata
//  needed to verify invariants and persist state.

import Foundation

// MARK: - Error

/// Typed error for bracket operations — never silent partial results.
enum WorldBracketError: Error, Equatable {
    /// Wrong number of qualifiers (expected 32).
    case invalidQualifierCount(Int)
    /// A team appears in more than one qualifier list.
    case duplicateQualifier(String)
    /// A group letter has no standings record.
    case missingGroup(String)
    /// A group lacks enough advancing teams (needs at least 2).
    case incompleteGroup(String)
    /// A fixture slot could not be resolved to a concrete team.
    case unresolvedSlot(String)
    /// The bracket doesn't contain the expected fixture counts.
    case invalidBracketShape(String)
    /// Two fixtures share the same ID.
    case duplicateFixtureID(String)
    /// A result failed validation against the bracket.
    case invalidResult(String)
    /// Bounded backtracking exhausted its node budget without finding a
    /// complete same-group-free matching.
    case generationFailed(String)
}

// MARK: - Qualifiers

/// The 32 teams that advance from the group stage into the Round of 32.
/// 12 group winners + 12 runners-up + 8 best third-placed, all unique.
struct WorldKnockoutQualifiers: Codable, Equatable {
    /// Group winners, A…L order.
    let groupWinners: [String]
    /// Group runners-up, A…L order.
    let groupRunnersUp: [String]
    /// Best third-placed teams, rank 1…8 order.
    let bestThirdPlaced: [String]

    // MARK: - Factory

    /// Extracts and validates qualifiers from group standings. Each group must
    /// have at least two ranked teams in its standings; the best-third list
    /// must contain exactly eight IDs that are not among the winners or
    /// runners-up. Throws a typed `WorldBracketError` on any invariant violation
    /// — never silently produces partial qualifiers.
    static func make(
        groups: [GroupAssignment],
        standingsByGroup: [String: [GroupStanding]],
        bestThirdPlacedTeamIDs: [String]
    ) throws -> WorldKnockoutQualifiers {

        // 1. Extract winners and runners-up in A…L order.
        var winners: [String] = []
        var runnersUp: [String] = []
        winners.reserveCapacity(12)
        runnersUp.reserveCapacity(12)

        for group in groups {
            guard let standings = standingsByGroup[group.id] else {
                throw WorldBracketError.missingGroup(group.id)
            }
            guard standings.count >= 2 else {
                throw WorldBracketError.incompleteGroup(group.id)
            }
            winners.append(standings[0].teamID)
            runnersUp.append(standings[1].teamID)
        }

        guard winners.count == 12 else {
            throw WorldBracketError.invalidQualifierCount(winners.count + runnersUp.count + bestThirdPlacedTeamIDs.count)
        }

        // 2. Validate best-third count.
        guard bestThirdPlacedTeamIDs.count == 8 else {
            throw WorldBracketError.invalidQualifierCount(winners.count + runnersUp.count + bestThirdPlacedTeamIDs.count)
        }

        // 3. Uniqueness across all three lists.
        let winnerSet = Set(winners)
        let runnerUpSet = Set(runnersUp)
        let thirdSet = Set(bestThirdPlacedTeamIDs)

        guard winnerSet.count == 12 else {
            throw WorldBracketError.duplicateQualifier("Duplicate in group winners")
        }
        guard runnerUpSet.count == 12 else {
            throw WorldBracketError.duplicateQualifier("Duplicate in group runners-up")
        }
        guard thirdSet.count == 8 else {
            throw WorldBracketError.duplicateQualifier("Duplicate in best third-placed")
        }
        guard winnerSet.intersection(runnerUpSet).isEmpty else {
            throw WorldBracketError.duplicateQualifier("Team appears in both winners and runners-up")
        }
        guard winnerSet.intersection(thirdSet).isEmpty else {
            throw WorldBracketError.duplicateQualifier("Best third-placed team is also a group winner")
        }
        guard runnerUpSet.intersection(thirdSet).isEmpty else {
            throw WorldBracketError.duplicateQualifier("Best third-placed team is also a group runner-up")
        }

        return WorldKnockoutQualifiers(
            groupWinners: winners,
            groupRunnersUp: runnersUp,
            bestThirdPlaced: bestThirdPlacedTeamIDs)
    }

    // MARK: - Computed

    /// All 32 team IDs: winners, then runners-up, then best thirds.
    var allTeamIDs: [String] {
        groupWinners + groupRunnersUp + bestThirdPlaced
    }

    /// True when all 32 team IDs are unique.
    var allUnique: Bool {
        Set(allTeamIDs).count == 32
    }
}

// MARK: - Bracket

/// A complete 32-team single-elimination bracket: 31 fixtures across 5 rounds.
/// Generated deterministically from a seed and a set of qualifiers — same inputs
/// always produce an identical bracket. Stored as JSON inside TournamentState
/// for save/resume.
struct WorldKnockoutBracket: Codable, Equatable {
    /// All 31 knockout fixtures, R32 → Final.
    let fixtures: [Fixture]
    /// The tournament seed this bracket was generated from.
    let createdFromTournamentSeed: UInt64
    /// The 32 team IDs that qualified (winners + runners-up + best thirds).
    /// Used for invariant checks; the bracket is invalid if these change.
    let qualifierTeamIDs: [String]

    // MARK: - Computed round accessors

    /// Round of 32 fixtures (16).
    var r32Fixtures: [Fixture] { fixtures.filter { $0.round == 1 } }
    /// Round of 16 fixtures (8).
    var r16Fixtures: [Fixture] { fixtures.filter { $0.round == 2 } }
    /// Quarter-final fixtures (4).
    var quarterFinals: [Fixture] { fixtures.filter { $0.round == 3 } }
    /// Semi-final fixtures (2).
    var semiFinals: [Fixture] { fixtures.filter { $0.round == 4 } }
    /// Final fixture (1).
    var final: Fixture? { fixtures.first { $0.round == 5 } }

    /// Total knockout fixture count — must be 31 for a valid 32-team bracket.
    var totalFixtureCount: Int { fixtures.count }

    // MARK: - Invariant helpers (for tests and debug)

    /// True when the bracket satisfies the shape invariant: exactly
    /// 16+8+4+2+1 = 31 fixtures, all IDs unique, all seeds nonzero.
    var hasValidShape: Bool {
        guard fixtures.count == 31 else { return false }
        guard r32Fixtures.count == 16,
              r16Fixtures.count == 8,
              quarterFinals.count == 4,
              semiFinals.count == 2,
              final != nil else { return false }
        let ids = Set(fixtures.map(\.id))
        guard ids.count == 31 else { return false }
        guard fixtures.allSatisfy({ $0.seed != 0 }) else { return false }
        return true
    }

    /// All 32 qualifiers appear exactly once across the 16 R32 fixtures.
    var hasValidQualifierCoverage: Bool {
        let r32Teams = r32Fixtures.flatMap { [$0.homeTeamID, $0.awayTeamID] }
        return Set(r32Teams) == Set(qualifierTeamIDs) && r32Teams.count == 32
    }
}
