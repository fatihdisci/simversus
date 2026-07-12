//  TournamentLobbyView.swift
//  Features/Tournament

import SwiftUI
import SwiftData

struct TournamentLobbyView: View {
    let onSelectFormat: (TournamentFormat) -> Void
    let onStartWorldArena: () -> Void
    let onContinueWorldArena: (UUID) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var adManager = AdManager.shared
    @Query(sort: \TournamentState.startedAt, order: .reverse)
    private var tournaments: [TournamentState]

    private var activeWorldArena: TournamentState? {
        tournaments.first {
            $0.competitionID == TournamentDefinition.WorldArena.id && $0.completedAt == nil
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.energy,
                            secondaryTint: Palette.accentWarning)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    lobbyHeader
                    ArenaSectionHeader(title: "tournament.lobby.standard")
                    standardFormats
                    ArenaSectionHeader(title: "tournament.lobby.special")
                    if let activeWorldArena { continueCard(activeWorldArena) }
                    worldArenaCard
                }
                .padding(Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("tournament.lobby.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adManager.preloadRewarded() }
    }

    private var lobbyHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("tournament.lobby.title")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
            Text("tournament.lobby.subtitle")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var standardFormats: some View {
        VStack(spacing: Spacing.s) {
            ForEach(TournamentFormat.allCases, id: \.self) { format in
                StandardFormatCard(format: format,
                                   isLocked: !format.isFree && !purchaseManager.isAdFree) {
                    select(format)
                }
            }
        }
    }

    private func continueCard(_ state: TournamentState) -> some View {
        ArenaSurface {
            HStack(spacing: Spacing.m) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("tournament.worldArena.continue")
                        .font(.headline)
                    Text("tournament.worldArena.progressSaved")
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
            }
            .contentShape(Rectangle())
            .onTapGesture { onContinueWorldArena(state.id) }
        }
    }

    private var worldArenaCard: some View {
        Button(action: onStartWorldArena) {
            HStack(spacing: Spacing.m) {
                WorldArenaGlyph()
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("tournament.worldArena.name")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("tournament.worldArena.cardStats")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.accentWarning)
                    Text("tournament.worldArena.independent")
                        .font(.caption2)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Spacing.s)
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Palette.accentWarning)
            }
            .padding(Spacing.m)
            .background(Palette.bgElevatedStrong,
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Radius.card)
                .stroke(Palette.accentWarning.opacity(0.65), lineWidth: 1))
        }
        .buttonStyle(ArenaTileButtonStyle())
        .accessibilityHint("tournament.worldArena.chooseHint")
    }

    private func select(_ format: TournamentFormat) {
        guard format.isFree || purchaseManager.isAdFree else {
            adManager.showRewarded { onSelectFormat(format) }
            return
        }
        onSelectFormat(format)
    }
}

private struct StandardFormatCard: View {
    let format: TournamentFormat
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(format.displayName).font(.headline)
                    Text(summary).font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Image(systemName: isLocked ? "play.rectangle.fill" : "chevron.right")
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Spacing.m)
            .background(Palette.bgElevated,
                        in: RoundedRectangle(cornerRadius: Radius.button))
            .overlay(RoundedRectangle(cornerRadius: Radius.button)
                .stroke(Palette.borderSubtle))
        }
        .buttonStyle(ArenaTileButtonStyle())
    }

    private var summary: String {
        let key = format.hasGroupStage
            ? "tournament.lobby.format.group"
            : "tournament.lobby.format.knockout"
        return String.localizedStringWithFormat(
            NSLocalizedString(key, comment: ""), format.teamCount, format.groupCount)
    }
}

private struct WorldArenaGlyph: View {
    var body: some View {
        ZStack {
            Circle().stroke(Palette.accentWarning, lineWidth: 2)
            Ellipse().stroke(Palette.accentWarning.opacity(0.7), lineWidth: 1)
                .frame(width: 22)
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(Palette.accentWarning)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        TournamentLobbyView(onSelectFormat: { _ in },
                            onStartWorldArena: {},
                            onContinueWorldArena: { _ in })
    }
    .environmentObject(PurchaseManager.shared)
    .modelContainer(for: [TournamentState.self], inMemory: true)
    .preferredColorScheme(.dark)
}
