import SwiftUI

struct ResultHeroCard: View {
    let result: MatchResult
    let homeTeam: Team
    let awayTeam: Team
    let winnerText: String
    let winnerTeam: Team?

    var body: some View {
        ArenaSurface(padding: Spacing.l, isFocused: true) {
            VStack(spacing: Spacing.l) {
                ZStack {
                    if let winnerTeam {
                        TeamGlow(color: winnerTeam.primaryColor)
                            .frame(width: 220, height: 130)
                    }
                    HStack(spacing: Spacing.m) {
                        TeamBadgeView(team: homeTeam, size: 72)
                            .opacity(result.homeScore < result.awayScore ? 0.5 : 1)
                        HStack(spacing: Spacing.s) {
                            Text("\(result.homeScore)")
                            Text(verbatim: "–").foregroundStyle(Palette.textTertiary)
                            Text("\(result.awayScore)")
                        }
                        .font(.finalScore)
                        .foregroundStyle(Palette.textPrimary)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        TeamBadgeView(team: awayTeam, size: 72)
                            .opacity(result.awayScore < result.homeScore ? 0.5 : 1)
                    }
                }

                VStack(spacing: Spacing.xs) {
                    Text(winnerTeam == nil ? "result.draw.label" : "result.winner.label")
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                        .textCase(.uppercase)
                    Text(verbatim: winnerText)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

struct ResultGoalRow: View {
    let goal: Goal
    let team: Team?
    /// Cumulative home–away score immediately after this goal, so the list
    /// reads as a broadcast-style progression rather than isolated events.
    let homeScoreAfter: Int
    let awayScoreAfter: Int

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(verbatim: "\(goal.minute)'")
                .font(.scoreboard)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 64, alignment: .leading)
            if let team {
                TeamOrbView(team: team, size: 30)
                Text(team.short)
                    .font(.label)
                    // Fixed, always-legible ink — never the team's own colour,
                    // which can be too close to the dark surface to read
                    // (mirrors TeamBadgeView's short-code convention).
                    .foregroundStyle(Palette.textPrimary)
            } else {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Image(systemName: "soccerball")
                .font(.caption)
                .foregroundStyle(Palette.textTertiary)
            Text(verbatim: "\(homeScoreAfter)–\(awayScoreAfter)")
                .font(.label)
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: 68)
    }
}
