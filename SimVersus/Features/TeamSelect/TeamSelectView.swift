//  TeamSelectView.swift
//  Features/TeamSelect
//
//  Home / Away team selection. Lists the MVP teams for each side; a team picked
//  on one side is disabled on the other. When both sides are chosen the Kick Off
//  CTA activates and calls `onStart`. Navigation is wired in Part 1d.

import SwiftUI

struct TeamSelectView: View {
    let teams: [Team]
    let onStart: (_ home: Team, _ away: Team) -> Void

    @State private var matchup = TeamMatchup()

    private let badgeSize: CGFloat = 64

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.l) {
                Text("teamselect.title")
                    .font(.titleXL)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.top, Spacing.m)

                teamRow(titleKey: "teamselect.home",
                        isSelected: { matchup.home == $0 },
                        isDisabled: { matchup.isDisabledForHome($0) },
                        select: { matchup.selectHome($0) })

                teamRow(titleKey: "teamselect.away",
                        isSelected: { matchup.away == $0 },
                        isDisabled: { matchup.isDisabledForAway($0) },
                        select: { matchup.selectAway($0) })

                Spacer()
                kickOffButton
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
    }

    // MARK: - Subviews

    private func teamRow(titleKey: LocalizedStringKey,
                         isSelected: @escaping (Team) -> Bool,
                         isDisabled: @escaping (Team) -> Bool,
                         select: @escaping (Team) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(titleKey)
                .font(.label)
                .foregroundStyle(Palette.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(teams) { team in
                        TeamCard(team: team,
                                 badgeSize: badgeSize,
                                 isSelected: isSelected(team),
                                 isDisabled: isDisabled(team)) {
                            select(team)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
            }
        }
    }

    private var kickOffButton: some View {
        Button {
            if let home = matchup.home, let away = matchup.away {
                onStart(home, away)
            }
        } label: {
            Text("teamselect.start")
                .font(.titleXL)
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
                .background(
                    matchup.isReady ? Palette.accent : Palette.arenaLine,
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!matchup.isReady)
    }
}

/// A single selectable team: badge + localized name, with selected / disabled
/// visual states.
private struct TeamCard: View {
    let team: Team
    let badgeSize: CGFloat
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                TeamBadgeView(team: team, size: badgeSize)
                Text(LocalizedStringKey(team.nameKey))
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .frame(width: badgeSize + Spacing.xl)
            }
            .padding(Spacing.s)
            .background(
                isSelected ? Palette.bgElevated : Color.clear,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.3 : 1)
    }
}

#Preview {
    TeamSelectView(teams: TeamStore().mvpTeams) { _, _ in }
}
