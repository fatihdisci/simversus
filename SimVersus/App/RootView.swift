//  RootView.swift
//  App
//
//  Owns the app-level `NavigationStack` and the `[AppRoute]` path that drives
//  the Home → TeamSelect → Match → Result flow. Each destination is built per
//  push so a rematch always gets a fresh `MatchConfig.seed` (CONSTITUTION §7)
//  and a finished match pops the match route before pushing the result, so
//  the user cannot swipe back onto a paused scene.
//
//  Tournament routes (Faz 3) are added as siblings — the player picks a format,
//  picks a team, and then navigates a bracket until the cup is won. Tournament
//  matches carry their tournamentID through match → result so the result screen
//  routes back to the bracket instead of the casual play flow.

import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    @State private var path: [AppRoute] = []

    private let teams = TeamStore().mvpTeams
    private let allTeams = TeamStore().allTeams
    @Query(sort: \CustomTeam.name) private var customTeams: [CustomTeam]

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onPlay: { path.append(.teamSelect) },
                onHistory: { path.append(.history) },
                onTournament: { path.append(.tournamentLobby) }
            )
            .navigationDestination(for: AppRoute.self, destination: destination)
        }
    }

    // MARK: - Destinations

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView(
                onPlay: { path = [.teamSelect] },
                onHistory: { path.append(.history) },
                onTournament: { path.append(.tournamentLobby) }
            )

        case .history:
            HistoryView(onPlay: { path = [.teamSelect] })

        case .teamSelect:
            TeamSelectView(
                teams: teams,
                onCreateTeam: { path.append(.teamCreator) },
                onStart: { home, away in
                    let config = MatchConfig(homeTeam: home, awayTeam: away,
                                             duration: appState.matchDuration.seconds)
                    path.append(.match(config))
                }
            )

        case .teamCreator:
            TeamCreatorView(onDone: { if !path.isEmpty { path.removeLast() } })

        case .tournamentLobby:
            TournamentLobbyView { format in
                path.append(.tournamentPickMyTeam(format))
            }

        case .tournamentPickMyTeam(let format):
            TournamentPickMyTeamView(format: format) { state in
                path.append(.tournamentBracket(tournamentID: state.id))
            }

        case .tournamentBracket(let tournamentID):
            TournamentBracketView(tournamentID: tournamentID,
                                  onPlayMatch: { config in
                path.append(.match(config, tournamentID: tournamentID))
            })

        case .match(let config, let tournamentID):
            MatchView(config: config, onExit: {
                if let tid = tournamentID {
                    path = [.tournamentBracket(tournamentID: tid)]
                } else {
                    path = [.teamSelect]
                }
            }) { result in
                appState.matchesPlayedCount += 1
                saveMatchRecord(result, config: config)
                if let tid = tournamentID {
                    saveTournamentResult(result, config: config, tournamentID: tid)
                }
                path.removeLast()
                path.append(.result(result, config, tournamentID: tournamentID))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)

        case .result(let result, let config, let tournamentID):
            if let tid = tournamentID {
                // Tournament match result — route back to bracket.
                ResultView(
                    result: result,
                    config: config,
                    onRematch: {
                        let newConfig = MatchConfig(homeTeam: config.homeTeam,
                                                    awayTeam: config.awayTeam,
                                                    duration: appState.matchDuration.seconds)
                        path = [.match(newConfig, tournamentID: tid)]
                    },
                    onNewMatch: { path = [.tournamentBracket(tournamentID: tid)] },
                    onHome: { path = [] }
                )
            } else {
                // Casual play result.
                ResultView(
                    result: result,
                    config: config,
                    onRematch: { rematch(from: config) },
                    onNewMatch: { path = [.teamSelect] },
                    onHome: { path = [] }
                )
            }
        }
    }

    // MARK: - Team resolution

    func resolveTeam(_ teamID: String) -> Team {
        if let preset = allTeams.first(where: { $0.id == teamID }) { return preset }
        if let custom = customTeams.first(where: { $0.id.uuidString == teamID }) { return custom.asTeam }
        return Team(id: teamID, nameKey: teamID, nameTR: teamID, nameEN: teamID,
                    short: "???", primary: "#888888", secondary: "#444444",
                    badgeShape: .star, tier: 0, baseStrength: 75, stats: .balanced, pattern: .solid)
    }

    // MARK: - Actions

    private func rematch(from config: MatchConfig) {
        let newConfig = MatchConfig(homeTeam: config.homeTeam,
                                    awayTeam: config.awayTeam,
                                    duration: appState.matchDuration.seconds)
        path = [.match(newConfig)]
    }

    private func saveMatchRecord(_ result: MatchResult, config: MatchConfig) {
        modelContext.insert(MatchRecord(result: result, seed: config.seed))
        let descriptor = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        if let records = try? modelContext.fetch(descriptor), records.count > 500 {
            records.dropFirst(500).forEach(modelContext.delete)
        }
        try? modelContext.save()
    }

    private func saveTournamentResult(_ result: MatchResult, config: MatchConfig, tournamentID: UUID) {
        let id = tournamentID
        let descriptor = FetchDescriptor<TournamentState>(predicate: #Predicate { $0.id == id })
        guard let state = try? modelContext.fetch(descriptor).first else { return }

        // Match the result to its fixture.
        let fixtureID = fixtureIDForMatch(config: config, in: state)
        let fixtureResult = FixtureResult(from: result, fixtureID: fixtureID, isSimulated: false)
        state.appendResult(fixtureResult)
        try? modelContext.save()
    }

    /// Finds the matching fixture in the tournament state for this match config.
    private func fixtureIDForMatch(config: MatchConfig, in state: TournamentState) -> String {
        let playedIDs = Set(state.results.map(\.fixtureID))
        // Find the first unplayed fixture matching these two teams
        for f in state.fixtures where !playedIDs.contains(f.id) {
            let homeMatch = f.homeTeamID == config.homeTeam.id
            let awayMatch = f.awayTeamID == config.awayTeam.id
            if homeMatch && awayMatch { return f.id }
        }
        return "match-\(config.seed)" // fallback
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .modelContainer(for: [CustomTeam.self, MatchRecord.self, TournamentState.self], inMemory: true)
        .preferredColorScheme(.dark)
}
