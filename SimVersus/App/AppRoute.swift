//  AppRoute.swift
//  App
//
//  Route enum that drives the root `NavigationStack` in `RootView`. Each case
//  carries exactly what its destination view needs: the match route keeps the
//  full `MatchConfig` so it can be replayed with a fresh seed for a rematch,
//  and the result route carries both the finished `MatchResult` and the
//  originating `MatchConfig` so the result screen can do the same.

import Foundation

enum AppRoute: Hashable {
    case home
    case history
    case teamSelect
    case teamCreator
    case tournamentLobby
    /// Active tournament bracket. The UUID is the `TournamentState.id` —
    /// the view fetches the @Model object from the model context.
    case tournamentBracket(tournamentID: UUID)
    /// Pick "my team" before generating a tournament. Carries the chosen format.
    case tournamentPickMyTeam(TournamentFormat)
    case trophyCabinet
    case match(MatchConfig, tournamentID: UUID? = nil)
    case result(MatchResult, MatchConfig, tournamentID: UUID? = nil)
}
