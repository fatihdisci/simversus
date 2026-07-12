//  WorldArenaChampionView.swift

import SwiftUI
import SwiftData

struct WorldArenaChampionView: View {
    let tournamentID: UUID
    let onTrophyCabinet: () -> Void
    let onHome: () -> Void
    let onNewTournament: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var controller: WorldArenaSessionController?
    @State private var errorKey: String?

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            if let controller, let championID = controller.championTeamID,
               let champion = controller.nationalTeam(championID) {
                celebration(controller: controller, champion: champion)
            } else if let errorKey {
                WorldArenaErrorView(key: errorKey, onRetry: load, onReturn: onHome)
            } else {
                ProgressView("tournament.worldArena.loading")
            }
        }
        .navigationBarBackButtonHidden(true)
        .task { load() }
    }

    private func celebration(controller: WorldArenaSessionController,
                             champion: NationalTeamDefinition) -> some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                championArena(champion)
                VStack(spacing: Spacing.s) {
                    Text("tournament.champion.eyebrow")
                        .font(.caption).foregroundStyle(Palette.accentWarning)
                        .textCase(.uppercase)
                    Text(LocalizedStringKey(champion.nameKey))
                        .font(.screenTitle).foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(LocalizedStringKey(
                        champion.id == controller.state.playerTeamID
                        ? "tournament.champion.playerWon"
                        : "tournament.champion.aiWon"))
                        .font(.body).foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                summary(controller)
                actions(playerWon: champion.id == controller.state.playerTeamID)
            }
            .padding(Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    private func championArena(_ champion: NationalTeamDefinition) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(Palette.accentWarning.opacity(0.5 - Double(index) * 0.12),
                            lineWidth: 2)
                    .frame(width: CGFloat(150 + index * 42),
                           height: CGFloat(150 + index * 42))
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(index * 18)))
            }
            Circle().fill(Palette.accentWarning.opacity(0.12)).frame(width: 128, height: 128)
            NationalFlagView(team: champion, style: .standard)
                .scaleEffect(1.8)
        }
        .frame(height: 282)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(champion.nameKey)))
    }

    private func summary(_ controller: WorldArenaSessionController) -> some View {
        ArenaSurface {
            HStack {
                stat("104", key: "tournament.champion.matches")
                Spacer()
                stat("48", key: "tournament.champion.nations")
                Spacer()
                stat("1", key: "tournament.champion.champion")
            }
        }
    }

    private func stat(_ value: String, key: LocalizedStringKey) -> some View {
        VStack(spacing: Spacing.xs) {
            Text(value).font(.headline.monospacedDigit())
                .foregroundStyle(Palette.accentWarning)
            Text(key).font(.caption2).foregroundStyle(Palette.textSecondary)
        }
    }

    private func actions(playerWon: Bool) -> some View {
        VStack(spacing: Spacing.s) {
            if playerWon {
                ArenaCTAButton(title: "tournament.champion.trophyCabinet",
                               systemImage: "trophy.fill",
                               action: onTrophyCabinet)
            }
            ArenaCTAButton(title: "tournament.champion.newTournament",
                           systemImage: "arrow.counterclockwise",
                           kind: .secondary,
                           action: onNewTournament)
            Button("result.home", action: onHome)
                .font(.sectionLabel).foregroundStyle(Palette.textSecondary)
                .frame(minHeight: Layout.minTouchTarget)
        }
    }

    private func load() {
        guard controller == nil else { return }
        do {
            let loaded = try WorldArenaSessionController(
                tournamentID: tournamentID, modelContext: modelContext)
            guard loaded.championTeamID != nil else {
                errorKey = "tournament.error.noChampion"
                return
            }
            controller = loaded
            _ = try loaded.awardPlayerTrophyIfNeeded()
        } catch {
            errorKey = "tournament.error.missingState"
        }
    }
}
