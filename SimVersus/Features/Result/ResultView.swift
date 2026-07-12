//  ResultView.swift
//  Post-match broadcast summary and celebration.

import SwiftUI

struct ResultView: View {
    @EnvironmentObject private var appState: AppState
    let result: MatchResult
    let config: MatchConfig
    let onRematch: () -> Void
    let onNewMatch: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: config.homeTeam.primaryColor,
                            secondaryTint: config.awayTeam.primaryColor)

            ScrollView {
                VStack(spacing: Spacing.l) {
                    header
                    ResultHeroCard(result: result,
                                   homeTeam: config.homeTeam,
                                   awayTeam: config.awayTeam,
                                   winnerText: winnerText,
                                   winnerTeam: winnerTeam)
                    goalSummary
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, 224)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .onDisappear { AdGate.onResultDismiss(matchesPlayed: appState.matchesPlayedCount) }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("result.status.complete")
                    .font(.caption)
                    .foregroundStyle(Palette.accent)
                    .textCase(.uppercase)
                Text("result.title")
                    .font(.screenTitle)
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            Image(systemName: winnerTeam != nil ? "trophy.fill" : "equal.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(headerAccent)
                .shadow(color: headerAccent.opacity(0.5), radius: 8)
        }
    }

    @ViewBuilder
    private var goalSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "result.goals")
            if result.goals.isEmpty {
                ArenaSurface {
                    Label("result.noGoals", systemImage: "minus.circle")
                        .font(.sectionLabel)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
            } else {
                ArenaSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(result.goals.indices, id: \.self) { index in
                            ResultGoalRow(goal: result.goals[index],
                                          team: team(for: result.goals[index]),
                                          homeScoreAfter: runningScores[index].home,
                                          awayScoreAfter: runningScores[index].away)
                            if index != result.goals.indices.last {
                                Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Cumulative home/away score after each goal, in chronological order —
    /// precomputed once so each row is a plain lookup.
    private var runningScores: [(home: Int, away: Int)] {
        var home = 0, away = 0
        return result.goals.map { goal in
            if goal.teamID == config.homeTeam.id { home += 1 }
            else if goal.teamID == config.awayTeam.id { away += 1 }
            return (home, away)
        }
    }

    /// A fixed palette colour rather than the winning team's — team colours
    /// are chosen freely in the creator/`teams.json` and can be near-black
    /// (e.g. a "Black-White" kit), which would make a team-tinted glyph
    /// illegible against the dark background. A draw stays neutral so it
    /// never falsely reads as a celebration.
    private var headerAccent: Color {
        winnerTeam != nil ? Palette.accent : Palette.textSecondary
    }

    private var actionBar: some View {
        VStack(spacing: Spacing.s) {
            ArenaCTAButton(title: "result.rematch",
                           systemImage: "arrow.counterclockwise",
                           kind: .primary,
                           action: onRematch)

            ArenaCTAButton(title: "result.newMatch",
                           systemImage: "forward.fill",
                           kind: .secondary,
                           action: onNewMatch)

            Button("result.home", action: onHome)
                .font(.sectionLabel)
                .foregroundStyle(Palette.textTertiary)
                .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.top, Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.borderSubtle).frame(height: 1) }
    }

    private var winnerTeam: Team? {
        guard let id = result.winnerTeamID else { return nil }
        return team(withID: id)
    }

    private var winnerText: String {
        guard let winner = winnerTeam else { return NSLocalizedString("result.draw", comment: "") }
        let teamName = NSLocalizedString(winner.nameKey, comment: "")
        let format = NSLocalizedString("result.winner %@", comment: "")
        return String.localizedStringWithFormat(format, teamName)
    }

    private func team(for goal: Goal) -> Team? { team(withID: goal.teamID) }

    private func team(withID id: String) -> Team? {
        if id == config.homeTeam.id { return config.homeTeam }
        if id == config.awayTeam.id { return config.awayTeam }
        return nil
    }
}

#Preview {
    let teams = TeamStore().mvpTeams
    let config = MatchConfig(homeTeam: teams[0], awayTeam: teams[3], seed: 42)
    let result = MatchSimulation(config: config).runToCompletion()
    return ResultView(result: result, config: config, onRematch: {}, onNewMatch: {}, onHome: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
