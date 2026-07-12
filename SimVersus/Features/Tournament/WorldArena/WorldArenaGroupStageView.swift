//  WorldArenaGroupStageView.swift

import SwiftUI
import SwiftData

struct WorldArenaGroupStageView: View {
    let tournamentID: UUID
    let onPlayMatch: (MatchConfig, Fixture) -> Void
    let onViewBestThirds: () -> Void
    let onReturnToLobby: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var controller: WorldArenaSessionController?
    @State private var selectedGroupID = "A"
    @State private var loadErrorKey: String?

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            if let controller {
                dashboard(controller)
            } else if let loadErrorKey {
                WorldArenaErrorView(key: loadErrorKey,
                                    onRetry: load,
                                    onReturn: onReturnToLobby)
            } else {
                ProgressView("tournament.worldArena.loading")
                    .tint(Palette.accent)
            }
        }
        .navigationTitle("tournament.worldArena.name")
        .navigationBarTitleDisplayMode(.inline)
        .task { load() }
    }

    private func dashboard(_ controller: WorldArenaSessionController) -> some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                WorldArenaGroupHeader(controller: controller)
                if controller.isResolving {
                    Label("tournament.group.simulating", systemImage: "bolt.horizontal.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                if controller.state.phase == .knockout {
                    groupCompleteCard
                } else if let fixture = controller.nextPlayerGroupFixture {
                    nextMatchCard(controller, fixture: fixture)
                }
                groupSelector(controller)
                if let group = controller.group(named: selectedGroupID) {
                    WorldArenaGroupTable(group: group,
                                         standings: controller.standings(for: group),
                                         playerTeamID: controller.state.playerTeamID,
                                         catalog: controller.catalog)
                    WorldArenaGroupFixtures(fixtures: controller.groupFixtures(for: group),
                                            results: controller.state.results,
                                            catalog: controller.catalog)
                }
                if let errorKey = controller.errorKey {
                    Text(LocalizedStringKey(errorKey))
                        .font(.caption)
                        .foregroundStyle(Palette.danger)
                }
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
        .task { await controller.resumeProgression() }
    }

    private var groupCompleteCard: some View {
        ArenaSurface {
            VStack(spacing: Spacing.m) {
                Label("tournament.group.complete", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(Palette.accent)
                ArenaCTAButton(title: "tournament.bestThird.view",
                               systemImage: "list.number",
                               action: onViewBestThirds)
            }
        }
    }

    private func nextMatchCard(_ controller: WorldArenaSessionController,
                               fixture: Fixture) -> some View {
        ArenaSurface {
            VStack(spacing: Spacing.m) {
                ArenaSectionHeader(title: "tournament.group.nextMatch",
                                   trailingText: "tournament.group.watch")
                WorldArenaFixtureTeams(fixture: fixture,
                                       catalog: controller.catalog)
                ArenaCTAButton(title: "tournament.group.watch",
                               systemImage: "play.fill",
                               isEnabled: !controller.isResolving) {
                    do {
                        onPlayMatch(try controller.matchConfig(for: fixture), fixture)
                    } catch {
                        loadErrorKey = "tournament.error.missingTeam"
                    }
                }
            }
        }
    }

    private func groupSelector(_ controller: WorldArenaSessionController) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: Spacing.s) {
                ForEach(controller.state.groupAssignments) { group in
                    ArenaChoicePill(title: String.localizedStringWithFormat(
                        NSLocalizedString("tournament.group.name", comment: ""), group.id),
                                    isSelected: selectedGroupID == group.id) {
                        selectedGroupID = group.id
                    }
                    .frame(width: 72)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func load() {
        guard controller == nil else { return }
        do {
            let loaded = try WorldArenaSessionController(
                tournamentID: tournamentID,
                modelContext: modelContext)
            controller = loaded
            selectedGroupID = loaded.playerGroup?.id ?? "A"
            loadErrorKey = nil
        } catch {
            loadErrorKey = "tournament.error.missingState"
        }
    }
}

struct WorldArenaErrorView: View {
    let key: String
    let onRetry: () -> Void
    let onReturn: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("tournament.error.title", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(LocalizedStringKey(key))
        } actions: {
            Button("common.retry", action: onRetry)
            Button("tournament.error.returnLobby", action: onReturn)
        }
    }
}
