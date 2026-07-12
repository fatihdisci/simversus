//  WorldArenaBestThirdsView.swift

import SwiftUI
import SwiftData

struct WorldArenaBestThirdsView: View {
    let tournamentID: UUID
    let onViewKnockout: () -> Void
    let onReturnToLobby: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var controller: WorldArenaSessionController?
    @State private var errorKey: String?

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            if let controller {
                content(controller)
            } else if let errorKey {
                WorldArenaErrorView(key: errorKey,
                                    onRetry: load,
                                    onReturn: onReturnToLobby)
            } else {
                ProgressView("tournament.worldArena.loading")
            }
        }
        .navigationTitle("tournament.bestThird.title")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if controller != nil {
                ArenaCTAButton(title: "tournament.bestThird.viewBracket",
                               systemImage: "arrow.right",
                               action: onViewKnockout)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                    .background(.ultraThinMaterial)
            }
        }
        .task { load() }
    }

    private func content(_ controller: WorldArenaSessionController) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("tournament.bestThird.subtitle")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                ArenaSurface(padding: 0) {
                    VStack(spacing: 0) {
                        tableHeader
                        ForEach(Array(controller.rankedThirdPlacedTeams.enumerated()),
                                id: \.element.teamID) { index, standing in
                            row(index: index, standing: standing, controller: controller)
                            if index < controller.rankedThirdPlacedTeams.count - 1 {
                                Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.l)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
    }

    private var tableHeader: some View {
        HStack {
            Text("#").frame(width: 24)
            Text("tournament.bestThird.team")
            Spacer()
            Text("tournament.bestThird.columns").font(.caption.monospaced())
        }
        .font(.caption)
        .foregroundStyle(Palette.textSecondary)
        .padding(Spacing.m)
        .background(Palette.bgElevatedStrong)
    }

    private func row(index: Int, standing: GroupStanding,
                     controller: WorldArenaSessionController) -> some View {
        let team = controller.nationalTeam(standing.teamID)
        let qualified = controller.state.bestThirdPlacedTeamIDs.contains(standing.teamID)
        return HStack(spacing: Spacing.s) {
            Text("\(index + 1)").font(.caption.monospacedDigit()).frame(width: 24)
            if let team { NationalFlagView(team: team, style: .compact) }
            VStack(alignment: .leading, spacing: 2) {
                Text(team.map { LocalizedStringKey($0.nameKey) }
                     ?? LocalizedStringKey(standing.teamID))
                    .font(.caption).lineLimit(1)
                Text(qualified ? "tournament.bestThird.qualified"
                               : "tournament.bestThird.eliminated")
                    .font(.caption2)
                    .foregroundStyle(qualified ? Palette.accent : Palette.textTertiary)
            }
            Spacer()
            Text("\(standing.played)  \(standing.goalDifference)  \(standing.goalsFor)  \(standing.points)")
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: 52)
        .background(qualified ? Palette.accent.opacity(0.06) : Color.clear)
        .accessibilityValue(qualified
                            ? Text("tournament.bestThird.qualified")
                            : Text("tournament.bestThird.eliminated"))
    }

    private func load() {
        guard controller == nil else { return }
        do {
            controller = try WorldArenaSessionController(
                tournamentID: tournamentID, modelContext: modelContext)
            errorKey = nil
        } catch {
            errorKey = "tournament.error.missingState"
        }
    }
}
