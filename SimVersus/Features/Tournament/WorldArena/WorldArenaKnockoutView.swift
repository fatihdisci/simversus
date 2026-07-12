//  WorldArenaKnockoutView.swift

import SwiftUI
import SwiftData

struct WorldArenaKnockoutView: View {
    let tournamentID: UUID
    let onPlayMatch: (MatchConfig, Fixture) -> Void
    let onChampion: () -> Void
    let onHome: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var controller: WorldArenaSessionController?
    @State private var selectedRound = 1
    @State private var errorKey: String?

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            if let controller { content(controller) }
            else if let errorKey {
                WorldArenaErrorView(key: errorKey, onRetry: load, onReturn: onHome)
            } else { ProgressView("tournament.worldArena.loading") }
        }
        .navigationTitle("tournament.knockout.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func content(_ controller: WorldArenaSessionController) -> some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                roundPicker
                if controller.state.phase == .finished {
                    completedCard(controller)
                } else if controller.isPlayerEliminated {
                    eliminatedCard(controller)
                } else if let fixture = controller.nextPlayerKnockoutFixture {
                    playerFixtureCard(controller, fixture: fixture)
                }
                if controller.isResolving {
                    Label("tournament.knockout.simulating", systemImage: "bolt.horizontal.fill")
                        .font(.caption).foregroundStyle(Palette.accent)
                }
                roundFixtures(controller)
                if let errorKey = controller.errorKey {
                    Text(LocalizedStringKey(errorKey))
                        .font(.caption).foregroundStyle(Palette.danger)
                }
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .task {
            await controller.resumeKnockoutProgression()
            selectedRound = controller.currentKnockoutRound
            if controller.state.phase == .finished { onChampion() }
        }
    }

    private var roundPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(1...5, id: \.self) { round in
                    Button {
                        selectedRound = round
                    } label: {
                        Text(LocalizedStringKey(roundKey(round)))
                            .font(.caption)
                            .foregroundStyle(selectedRound == round
                                             ? Palette.bgDeep : Palette.textPrimary)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: Layout.minTouchTarget)
                            .background(selectedRound == round
                                        ? Palette.accentWarning : Palette.bgElevatedStrong,
                                        in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedRound == round ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func playerFixtureCard(_ controller: WorldArenaSessionController,
                                   fixture: Fixture) -> some View {
        ArenaSurface {
            VStack(spacing: Spacing.m) {
                ArenaSectionHeader(title: "tournament.knockout.yourMatch")
                WorldArenaFixtureTeams(fixture: fixture, catalog: controller.catalog)
                ArenaCTAButton(title: "tournament.group.watch",
                               systemImage: "play.fill",
                               isEnabled: !controller.isResolving) {
                    if let config = try? controller.matchConfig(for: fixture) {
                        onPlayMatch(config, fixture)
                    }
                }
            }
        }
    }

    private func eliminatedCard(_ controller: WorldArenaSessionController) -> some View {
        ArenaSurface {
            VStack(spacing: Spacing.m) {
                Label("tournament.knockout.eliminated", systemImage: "xmark.circle.fill")
                    .font(.headline).foregroundStyle(Palette.danger)
                if let elimination = controller.elimination {
                    WorldArenaKnockoutResultRow(fixture: elimination.fixture,
                                                result: elimination.result,
                                                catalog: controller.catalog,
                                                playerTeamID: controller.state.playerTeamID)
                }
                ArenaCTAButton(title: "tournament.knockout.finishRemaining",
                               systemImage: "forward.end.fill",
                               isEnabled: !controller.isResolving) {
                    Task {
                        await controller.finishTournamentAfterElimination()
                        if controller.championTeamID != nil { onChampion() }
                    }
                }
            }
        }
    }

    private func completedCard(_ controller: WorldArenaSessionController) -> some View {
        ArenaSurface {
            ArenaCTAButton(title: "tournament.knockout.viewChampion",
                           systemImage: "trophy.fill",
                           action: onChampion)
        }
    }

    private func roundFixtures(_ controller: WorldArenaSessionController) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ArenaSectionHeader(title: LocalizedStringKey(roundKey(selectedRound)))
            if let bracket = controller.bracket {
                let results = Dictionary(uniqueKeysWithValues:
                    controller.state.results.map { ($0.fixtureID, $0) })
                ForEach(WorldBracketResolver.fixtures(in: bracket, round: selectedRound)) { fixture in
                    if let result = results[fixture.id] {
                        WorldArenaKnockoutResultRow(
                            fixture: fixture, result: result,
                            catalog: controller.catalog,
                            playerTeamID: controller.state.playerTeamID)
                    } else {
                        WorldArenaKnockoutPendingRow(
                            fixture: fixture, catalog: controller.catalog,
                            playerTeamID: controller.state.playerTeamID)
                    }
                }
            }
        }
    }

    private func roundKey(_ round: Int) -> String {
        switch round {
        case 1: return TournamentRoundKey.r32
        case 2: return TournamentRoundKey.r16
        case 3: return TournamentRoundKey.quarterFinal
        case 4: return TournamentRoundKey.semiFinal
        default: return TournamentRoundKey.final
        }
    }

    private func load() {
        guard controller == nil else { return }
        do {
            let loaded = try WorldArenaSessionController(
                tournamentID: tournamentID, modelContext: modelContext)
            controller = loaded
            selectedRound = loaded.currentKnockoutRound
        } catch {
            errorKey = "tournament.error.missingState"
        }
    }
}
