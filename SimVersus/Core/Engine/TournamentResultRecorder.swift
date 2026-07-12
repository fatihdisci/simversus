//  TournamentResultRecorder.swift
//  Core/Engine

import Foundation

enum TournamentResultRecordingError: Error, Equatable {
    case fixtureNotFound(String)
}

enum TournamentResultRecorder {
    /// Records against an explicit fixture identity. Returns false when the
    /// fixture already has a result, making repeated callbacks idempotent.
    @discardableResult
    static func record(_ result: FixtureResult,
                       fixtureID: String,
                       in state: TournamentState) throws -> Bool {
        guard result.fixtureID == fixtureID,
              state.fixtures.contains(where: { $0.id == fixtureID }) else {
            throw TournamentResultRecordingError.fixtureNotFound(fixtureID)
        }
        guard !state.results.contains(where: { $0.fixtureID == fixtureID }) else {
            return false
        }
        state.appendResult(result)
        return true
    }
}
