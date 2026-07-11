//  TeamSelectView.swift
//  One-pool matchup builder with a focused Home/Away slot.

import SwiftUI
import SwiftData

enum MatchupSelectionSide {
    case home, away
}

struct TeamSelectView: View {
    let teams: [Team]
    let onCreateTeam: () -> Void
    let onStart: (_ home: Team, _ away: Team) -> Void

    @Query(sort: \CustomTeam.createdAt) private var customTeams: [CustomTeam]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var matchup = TeamMatchup()
    @State private var activeSide: MatchupSelectionSide = .home

    private var selectableTeams: [Team] { teams + customTeams.map(\.asTeam) }
    private var slotAvailable: Bool { CustomTeamStore.canCreate(existingCount: customTeams.count) }
    private var activeTeam: Team? { activeSide == .home ? matchup.home : matchup.away }

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: matchup.home?.primaryColor ?? Palette.energy,
                            secondaryTint: matchup.away?.primaryColor ?? Palette.accent)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    matchupCard
                    teamPool
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { startBar }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("teamselect.title")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Button(action: { if slotAvailable { onCreateTeam() } }) {
                    Label("teamselect.create", systemImage: slotAvailable ? "plus" : "lock.fill")
                        .font(.sectionLabel)
                        .foregroundStyle(slotAvailable ? Palette.accent : Palette.textTertiary)
                        .padding(.horizontal, Spacing.s)
                        .frame(minHeight: Layout.minTouchTarget)
                        .background(Palette.bgElevated.opacity(0.8), in: Capsule())
                        .overlay(Capsule().stroke(Palette.borderSubtle))
                }
                .buttonStyle(.plain)
                .disabled(!slotAvailable)
            }
            Text("teamselect.subtitle")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var matchupCard: some View {
        ArenaSurface(padding: Spacing.l, isFocused: true) {
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    MatchupSlotView(side: .home,
                                    team: matchup.home,
                                    isActive: activeSide == .home) {
                        activeSide = .home
                    }
                    VStack(spacing: Spacing.xs) {
                        Text("common.versus")
                            .font(.headline)
                            .foregroundStyle(Palette.textPrimary)
                        Circle()
                            .fill(matchup.isReady ? Palette.accent : Palette.textTertiary)
                            .frame(width: 6, height: 6)
                            .shadow(color: matchup.isReady ? Palette.accent : .clear, radius: 5)
                            .modifier(PulseEffect(active: matchup.isReady && !reduceMotion))
                    }
                    .frame(width: 40)
                    MatchupSlotView(side: .away,
                                    team: matchup.away,
                                    isActive: activeSide == .away) {
                        activeSide = .away
                    }
                }

                Text(activeSide == .home ? "teamselect.focus.home" : "teamselect.focus.away")
                    .font(.caption)
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var teamPool: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "teamselect.pool",
                               trailingText: activeSide == .home ? "teamselect.home" : "teamselect.away")

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 3),
                      spacing: Spacing.s) {
                ForEach(selectableTeams) { team in
                    TeamPoolCard(team: team,
                                 selection: selection(for: team),
                                 isDisabled: isDisabled(team)) {
                        select(team)
                    }
                }
            }
        }
    }

    private var startBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Palette.borderSubtle)
                .frame(height: 1)
            Button {
                if let home = matchup.home, let away = matchup.away { onStart(home, away) }
            } label: {
                HStack {
                    Text(matchup.isReady ? "teamselect.start" : "teamselect.start.disabled")
                    Spacer()
                    Image(systemName: "play.fill")
                }
            }
            .buttonStyle(ArenaButtonStyle(kind: .primary))
            .disabled(!matchup.isReady)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
        }
        .background(.ultraThinMaterial)
    }

    private func selection(for team: Team) -> MatchupSelectionSide? {
        if matchup.home == team { return .home }
        if matchup.away == team { return .away }
        return nil
    }

    private func isDisabled(_ team: Team) -> Bool {
        activeSide == .home ? matchup.isDisabledForHome(team) : matchup.isDisabledForAway(team)
    }

    private func select(_ team: Team) {
        switch activeSide {
        case .home:
            let wasSelected = matchup.home == team
            matchup.selectHome(team)
            if !wasSelected, matchup.home != nil { activeSide = .away }
        case .away:
            matchup.selectAway(team)
        }
    }
}

/// A gentle, indefinite scale pulse used to draw the eye to the readiness dot
/// once both slots are filled. Settles back to rest when `active` turns off and
/// never animates when Reduce Motion is on (the caller gates `active`).
private struct PulseEffect: ViewModifier {
    let active: Bool
    @State private var expanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(expanded ? 1.35 : 1)
            .onAppear { sync() }
            .onChange(of: active) { _, _ in sync() }
    }

    private func sync() {
        if active {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                expanded = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { expanded = false }
        }
    }
}

#Preview {
    TeamSelectView(teams: TeamStore().mvpTeams, onCreateTeam: {}) { _, _ in }
        .modelContainer(for: CustomTeam.self, inMemory: true)
}
