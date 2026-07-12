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
    private let teamResolver = TeamResolver()
    @Query(sort: \CustomTeam.name) private var customTeams: [CustomTeam]

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onPlay: { path.append(.teamSelect) },
                onTournament: { path.append(.tournamentLobby) },
                onTrophyCabinet: { path.append(.trophyCabinet) }
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
                onTournament: { path.append(.tournamentLobby) },
                onTrophyCabinet: { path.append(.trophyCabinet) }
            )

        case .teamSelect:
            TeamSelectView(
                teams: teams,
                onCreateTeam: { path.append(.teamCreator) },
                onStart: { home, away in
                    let config = MatchConfig(homeTeam: home, awayTeam: away,
                                             duration: appState.matchDuration.seconds)
                    path.append(.match(config, context: .casual))
                }
            )

        case .teamCreator:
            TeamCreatorView(onDone: { if !path.isEmpty { path.removeLast() } })

        case .trophyCabinet:
            TrophyCabinetView()

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
                                  onPlayMatch: { config, fixtureID in
                path.append(.match(config, context: .standardTournament(
                    tournamentID: tournamentID,
                    fixtureID: fixtureID)))
            })

        case .match(let config, let context):
            MatchView(config: config, onExit: {
                switch context {
                case .casual:
                    path = [.teamSelect]
                case .standardTournament(let tournamentID, _):
                    path = [.tournamentBracket(tournamentID: tournamentID)]
                case .worldArena:
                    returnToWorldArenaDashboard(context)
                }
            }) { result in
                appState.matchesPlayedCount += 1
                saveMatchRecord(result, config: config)
                if let tournamentID = context.tournamentID,
                   let fixtureID = context.fixtureID {
                    saveTournamentResult(result,
                                         fixtureID: fixtureID,
                                         tournamentID: tournamentID)
                }
                path.removeLast()
                path.append(.result(result, config, context: context))
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)

        case .result(let result, let config, let context):
            if case .standardTournament(let tournamentID, let fixtureID) = context {
                // Tournament match result — route back to bracket.
                ResultView(
                    result: result,
                    config: config,
                    onRematch: {
                        let newConfig = MatchConfig(homeTeam: config.homeTeam,
                                                    awayTeam: config.awayTeam,
                                                    duration: appState.matchDuration.seconds)
                        path = [.match(newConfig, context: .standardTournament(
                            tournamentID: tournamentID,
                            fixtureID: fixtureID))]
                    },
                    onNewMatch: { path = [.tournamentBracket(tournamentID: tournamentID)] },
                    onHome: { path = [] }
                )
            } else if case .worldArena = context {
                ResultView(
                    result: result,
                    config: config,
                    onRematch: { returnToWorldArenaDashboard(context) },
                    onNewMatch: { returnToWorldArenaDashboard(context) },
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
        teamResolver.resolve(teamID, customTeams: customTeams)
    }

    // MARK: - Actions

    private func rematch(from config: MatchConfig) {
        let newConfig = MatchConfig(homeTeam: config.homeTeam,
                                    awayTeam: config.awayTeam,
                                    duration: appState.matchDuration.seconds)
        path = [.match(newConfig, context: .casual)]
    }

    private func saveMatchRecord(_ result: MatchResult, config: MatchConfig) {
        modelContext.insert(MatchRecord(result: result, seed: config.seed))
        let descriptor = FetchDescriptor<MatchRecord>(sortBy: [SortDescriptor(\.playedAt, order: .reverse)])
        if let records = try? modelContext.fetch(descriptor), records.count > 500 {
            records.dropFirst(500).forEach(modelContext.delete)
        }
        try? modelContext.save()
    }

    private func saveTournamentResult(_ result: MatchResult,
                                      fixtureID: String,
                                      tournamentID: UUID) {
        let id = tournamentID
        let descriptor = FetchDescriptor<TournamentState>(predicate: #Predicate { $0.id == id })
        guard let state = try? modelContext.fetch(descriptor).first else { return }

        let fixtureResult = FixtureResult(from: result, fixtureID: fixtureID, isSimulated: false)
        guard (try? TournamentResultRecorder.record(
            fixtureResult, fixtureID: fixtureID, in: state)) == true else { return }
        try? modelContext.save()
    }

    private func returnToWorldArenaDashboard(_ context: MatchContext) {
        // World Arena destinations are added in Commit 5B/5C. Keeping this
        // centralized avoids duplicating route decisions in MatchView/ResultView.
        guard let tournamentID = context.tournamentID else { path = []; return }
        path = [.tournamentBracket(tournamentID: tournamentID)]
    }
}

#Preview {
    RootView()
        .environmentObject(AppState())
        .modelContainer(for: [CustomTeam.self, MatchRecord.self, TournamentState.self, Trophy.self], inMemory: true)
        .preferredColorScheme(.dark)
}
