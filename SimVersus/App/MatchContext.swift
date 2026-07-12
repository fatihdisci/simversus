//  MatchContext.swift
//  App
//
//  Explicit identity for the flow that owns a match. Tournament contexts carry
//  the exact fixture ID so result persistence never guesses from team IDs.

import Foundation

enum WorldArenaMatchStage: String, Codable, Hashable {
    case group
    case knockout
}

enum MatchContext: Hashable {
    case casual
    case standardTournament(tournamentID: UUID, fixtureID: String)
    case worldArena(tournamentID: UUID, fixtureID: String, stage: WorldArenaMatchStage)

    var tournamentID: UUID? {
        switch self {
        case .casual:
            return nil
        case .standardTournament(let tournamentID, _),
             .worldArena(let tournamentID, _, _):
            return tournamentID
        }
    }

    var fixtureID: String? {
        switch self {
        case .casual:
            return nil
        case .standardTournament(_, let fixtureID),
             .worldArena(_, let fixtureID, _):
            return fixtureID
        }
    }
}

struct TournamentResultDetails: Hashable {
    let resolution: MatchResolution
    let homePenaltyScore: Int?
    let awayPenaltyScore: Int?

    init(_ result: FixtureResult) {
        resolution = result.resolution
        homePenaltyScore = result.homePenaltyScore
        awayPenaltyScore = result.awayPenaltyScore
    }
}
