import SwiftUI

struct MatchupSlotView: View {
    let side: MatchupSelectionSide
    let team: Team?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                ZStack {
                    Circle()
                        .fill(isActive ? Palette.accent.opacity(0.12) : Palette.bgDeep.opacity(0.7))
                        .frame(width: 88, height: 88)
                    if let team {
                        TeamBadgeView(team: team, size: 62)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isActive ? Palette.accent : Palette.textTertiary)
                    }
                }
                .overlay(Circle().stroke(isActive ? Palette.accent : Palette.borderSubtle, lineWidth: isActive ? 2 : 1))

                Text(side == .home ? "teamselect.home" : "teamselect.away")
                    .font(.caption)
                    .foregroundStyle(isActive ? Palette.accent : Palette.textSecondary)
                Text(team.map { LocalizedStringKey($0.nameKey) } ?? "teamselect.empty")
                    .font(.sectionLabel)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

struct TeamPoolCard: View {
    let team: Team
    let selection: MatchupSelectionSide?
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                ZStack(alignment: .topTrailing) {
                    TeamBadgeView(team: team, size: 54)
                    if let selection {
                        Text(selection == .home ? "teamselect.home.short" : "teamselect.away.short")
                            .font(.caption)
                            .foregroundStyle(Palette.bgDeep)
                            .frame(width: 22, height: 22)
                            .background(Palette.accent, in: Circle())
                            .offset(x: 7, y: -5)
                    }
                }
                Text(LocalizedStringKey(team.nameKey))
                    .font(.caption)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.78)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.m)
            .padding(.horizontal, Spacing.xs)
            .background(selection == nil ? Palette.bgElevated.opacity(0.78) : team.primaryColor.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(selection == nil ? Palette.borderSubtle : Palette.accent,
                            lineWidth: selection == nil ? 1 : 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.32 : 1)
        .accessibilityHint(selection == nil ? Text("") : Text("teamselect.selected"))
    }
}
