//  WorldBracketValidator.swift
//  Core/Engine
//
//  Pure validation of FixtureResult against a WorldKnockoutBracket before the
//  result is accepted. Catches mismatches, duplicate submissions, invalid
//  winners, and inconsistent penalty data before they corrupt bracket state.
//  All errors are typed — never a silent boolean.

import Foundation

enum WorldBracketValidator {

    /// Validates that `result` is consistent with the bracket and hasn't already
    /// been recorded with a conflicting value. Throws a typed `WorldBracketError`
    /// on the first violation; returns silently on success.
    ///
    /// Idempotent: submitting the identical result twice passes (the second call
    /// is a no-op). Submitting a different result for the same fixture throws
    /// `.invalidResult`.
    static func validate(
        _ result: FixtureResult,
        against bracket: WorldKnockoutBracket,
        existingResults: [FixtureResult]
    ) throws {

        // 1. Fixture exists in the bracket.
        guard let fixture = bracket.fixtures.first(where: { $0.id == result.fixtureID }) else {
            throw WorldBracketError.invalidResult(
                "Fixture \(result.fixtureID) is not in the bracket")
        }

        // 2. Duplicate check — identical result is idempotent; different result is an error.
        if let existing = existingResults.first(where: { $0.fixtureID == result.fixtureID }) {
            if existing.homeScore == result.homeScore
                && existing.awayScore == result.awayScore
                && existing.winnerTeamID == result.winnerTeamID
                && existing.resolution == result.resolution
                && existing.homePenaltyScore == result.homePenaltyScore
                && existing.awayPenaltyScore == result.awayPenaltyScore {
                return // idempotent — exact same result
            }
            throw WorldBracketError.invalidResult(
                "Conflicting result for fixture \(result.fixtureID): existing \(existing.homeScore)-\(existing.awayScore), new \(result.homeScore)-\(result.awayScore)")
        }

        // 3. Score values are non-negative.
        guard result.homeScore >= 0, result.awayScore >= 0 else {
            throw WorldBracketError.invalidResult(
                "Negative score for \(result.fixtureID): \(result.homeScore)-\(result.awayScore)")
        }

        // 4. Winner must be non-nil for knockout fixtures (round > 0).
        let isKnockout = fixture.round > 0
        if isKnockout {
            guard let winner = result.winnerTeamID else {
                throw WorldBracketError.invalidResult(
                    "Knockout fixture \(result.fixtureID) has nil winnerTeamID")
            }
            // Winner must be one of the two teams in the fixture.
            let validTeams = Set([fixture.homeTeamID, fixture.awayTeamID].filter {
                $0 != "TBD" && !$0.isEmpty
            })
            if !validTeams.isEmpty {
                guard validTeams.contains(winner) else {
                    throw WorldBracketError.invalidResult(
                        "Winner \(winner) is not one of the teams in fixture \(result.fixtureID) (\(fixture.homeTeamID) vs \(fixture.awayTeamID))")
                }
            }
        }

        // 5. Resolution field consistency.
        switch result.resolution {
        case .regulation, .extraTime:
            guard result.homePenaltyScore == nil, result.awayPenaltyScore == nil else {
                throw WorldBracketError.invalidResult(
                    "Fixture \(result.fixtureID) resolution is \(result.resolution) but penalty scores are present")
            }
        case .penalties:
            guard let hps = result.homePenaltyScore,
                  let aps = result.awayPenaltyScore else {
                throw WorldBracketError.invalidResult(
                    "Fixture \(result.fixtureID) resolution is .penalties but penalty scores are nil")
            }
            guard hps != aps else {
                throw WorldBracketError.invalidResult(
                    "Fixture \(result.fixtureID) penalty scores are equal (\(hps)-\(aps)); knockout must be decisive")
            }
        }
    }
}
