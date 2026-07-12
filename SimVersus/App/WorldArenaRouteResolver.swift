//  WorldArenaRouteResolver.swift

enum WorldArenaRouteResolver {
    static func destination(for state: TournamentState) -> AppRoute {
        switch state.phase {
        case .pending, .groupStage:
            return .worldArenaGroups(tournamentID: state.id)
        case .knockout:
            return .worldArenaKnockout(tournamentID: state.id)
        case .finished:
            return .worldArenaChampion(tournamentID: state.id)
        }
    }
}
