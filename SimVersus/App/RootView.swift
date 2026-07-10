//  RootView.swift
//  App
//
//  Owns the app-level `NavigationStack` and the `[AppRoute]` path that drives
//  the Home → TeamSelect → Match → Result flow. Each destination is built per
//  push so a rematch always gets a fresh `MatchConfig.seed` (CONSTITUTION §7)
//  and a finished match pops the match route before pushing the result, so
//  the user cannot swipe back onto a paused scene.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    @State private var path: [AppRoute] = []

    /// Loaded once — `TeamStore` reads the bundle file at init.
    private let teams = TeamStore().mvpTeams

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(onPlay: { path.append(.teamSelect) })
                .navigationDestination(for: AppRoute.self, destination: destination)
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .home:
            // The root view already renders Home; this case exists so the enum
            // exhaustively covers every value.
            HomeView(onPlay: { path = [.teamSelect] })

        case .teamSelect:
            TeamSelectView(teams: teams) { home, away in
                let config = MatchConfig(homeTeam: home, awayTeam: away)
                path.append(.match(config))
            }

        case .match(let config):
            MatchView(config: config) { result in
                appState.matchesPlayedCount += 1
                // Replace the match route with the result so the user can't
                // swipe back onto the paused scene.
                path.removeLast()
                path.append(.result(result, config))
            }
            .navigationBarBackButtonHidden(true)
            // Hiding the whole bar also kills the iOS interactive-back gesture,
            // which would otherwise let the user abandon a live match.
            .toolbar(.hidden, for: .navigationBar)

        case .result(let result, let config):
            ResultView(
                result: result,
                config: config,
                onRematch: { rematch(from: config) },
                onNewMatch: { path = [.teamSelect] },
                onHome: { path = [] }
            )
        }
    }

    // MARK: - Actions

    /// Builds a fresh match between the same two teams with a new random seed
    /// and replaces the stack with that single match. Pushed matches end with
    /// `removeLast()` + `append(.result)` so the back-swipe lands on Home.
    private func rematch(from config: MatchConfig) {
        let newConfig = MatchConfig(homeTeam: config.homeTeam,
                                    awayTeam: config.awayTeam)
        path = [.match(newConfig)]
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
