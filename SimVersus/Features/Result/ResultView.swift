//  ResultView.swift
//  Features/Result
//
//  Post-match summary. Renders the final score, both team badges, the winner
//  (or draw) banner, a chronological goal log and three actions: Rematch runs
//  the same teams with a fresh seed, New Match returns to team selection, and
//  Main Menu pops the stack back to Home. On disappear the screen notifies
//  `AdGate` — Part 1e will turn that into the interstitial trigger from
//  CONSTITUTION §4.3.

import SwiftUI

struct ResultView: View {
    let result: MatchResult
    let config: MatchConfig
    let onRematch: () -> Void
    let onNewMatch: () -> Void
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.l) {
                    title
                    badges
                    score
                    resultBanner
                    goalList
                    actions
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.l)
                .padding(.bottom, Spacing.xl)
            }
        }
        .onDisappear { AdGate.onResultDismiss() }
    }

    // MARK: - Sections

    private var title: some View {
        Text("result.title")
            .font(.titleXL)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var badges: some View {
        HStack(spacing: Spacing.xl) {
            TeamBadgeView(team: config.homeTeam, size: 84)
            Text(verbatim: "–")
                .font(.titleXL)
                .foregroundStyle(Palette.textSecondary)
            TeamBadgeView(team: config.awayTeam, size: 84)
        }
    }

    private var score: some View {
        HStack(spacing: Spacing.m) {
            Text("\(result.homeScore)")
                .font(.scoreboard)
                .foregroundStyle(Palette.textPrimary)
            Text(verbatim: "–")
                .font(.titleXL)
                .foregroundStyle(Palette.textSecondary)
            Text("\(result.awayScore)")
                .font(.scoreboard)
                .foregroundStyle(Palette.textPrimary)
        }
    }

    /// The localized banner — winner name from the catalog, or the draw text.
    /// `result.winner %@` is fetched via the catalog and `%@` is substituted
    /// by hand so we can pass the already-localized team name as a String.
    private var resultBanner: some View {
        let text = winnerText
        return Text(verbatim: text)
            .font(.titleXL)
            .multilineTextAlignment(.center)
            .foregroundStyle(winnerTeam == nil ? Palette.textSecondary : Palette.accent)
    }

    @ViewBuilder
    private var goalList: some View {
        if result.goals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.s) {
                // Indices are unique by definition, so this avoids any risk of
                // a `(minute, teamID)` duplicate-id crash inside SwiftUI.
                ForEach(result.goals.indices, id: \.self) { index in
                    goalRow(goal: result.goals[index])
                }
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Palette.bgElevated,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
        }
    }

    private func goalRow(goal: Goal) -> some View {
        let team = team(for: goal)
        let teamColor = team?.primaryColor ?? Palette.textSecondary
        let teamShort = team?.short ?? "?"
        let teamNameKey = team?.nameKey

        return HStack(spacing: Spacing.m) {
            Text(verbatim: "\(goal.minute)'")
                .font(.scoreboard)
                .foregroundStyle(Palette.textPrimary)
            Text(teamShort)
                .font(.label)
                .foregroundStyle(teamColor)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(
                    teamColor.opacity(0.18),
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
            Spacer()
            if let teamNameKey {
                Text(LocalizedStringKey(teamNameKey))
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Spacing.m) {
            Button(action: onRematch) {
                Text("result.rematch")
                    .font(.titleXL)
                    .foregroundStyle(Palette.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .background(
                        Palette.accent,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onNewMatch) {
                Text("result.newMatch")
                    .font(.label)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                    .padding(.vertical, Spacing.s)
                    .background(
                        Palette.bgElevated,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onHome) {
                Text("result.home")
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var winnerTeam: Team? {
        guard let id = result.winnerTeamID else { return nil }
        return team(withID: id)
    }

    /// Fully-localized banner text. Returns the draw text when no winner.
    private var winnerText: String {
        if let winner = winnerTeam {
            // `NSLocalizedString` is the runtime-safe lookup that handles the
            // dynamic `team.<id>.name` key reliably.
            let teamName = NSLocalizedString(winner.nameKey, comment: "")
            // `result.winner %@` is fetched via the same mechanism so the
            // sentence and the team name both follow the device locale.
            let format = NSLocalizedString("result.winner %@", comment: "")
            return String.localizedStringWithFormat(format, teamName)
        } else {
            return NSLocalizedString("result.draw", comment: "")
        }
    }

    private func team(for goal: Goal) -> Team? {
        team(withID: goal.teamID)
    }

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
    return ResultView(
        result: result,
        config: config,
        onRematch: {},
        onNewMatch: {},
        onHome: {}
    )
    .preferredColorScheme(.dark)
}