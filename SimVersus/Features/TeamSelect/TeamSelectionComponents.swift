import SwiftUI

/// The focused Home/Away slot at the top of Team Select. The shield sits on a
/// round pedestal that carries the active/selected state (accent ring + soft team
/// glow); the full team name is shown beneath, so the shield renders code-free.
struct MatchupSlotView: View {
    let side: MatchupSelectionSide
    let team: Team?
    let isActive: Bool
    let action: () -> Void

    /// Diameter of the round pedestal the shield sits on.
    private let pedestal: CGFloat = 88
    /// Shield width inside the pedestal — leaves an even margin all around.
    private let badge: CGFloat = 60

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                ZStack {
                    if let team {
                        TeamGlow(color: team.primaryColor)
                            .frame(width: pedestal * 0.92, height: pedestal * 0.92)
                    }
                    Circle()
                        .fill(isActive ? Palette.accent.opacity(0.12) : Palette.bgDeep.opacity(0.7))
                    if let team {
                        TeamBadgeView(team: team, size: badge, showsCode: false)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(isActive ? Palette.accent : Palette.textTertiary)
                    }
                }
                .frame(width: pedestal, height: pedestal)
                .overlay(
                    Circle().stroke(isActive ? Palette.accent : Palette.borderSubtle,
                                    lineWidth: isActive ? 2 : 1)
                )

                VStack(spacing: Spacing.xs) {
                    Text(side == .home ? "teamselect.home" : "teamselect.away")
                        .font(.caption)
                        .foregroundStyle(isActive ? Palette.accent : Palette.textSecondary)
                        .textCase(.uppercase)
                    Text(team.map { LocalizedStringKey($0.nameKey) } ?? "teamselect.empty")
                        .font(.sectionLabel)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// A team in the pool grid. The shield renders code-free above the full name so
/// every card shares one vertical rhythm; a fixed shield frame area keeps all
/// badges on the same optical baseline regardless of grid row.
struct TeamPoolCard: View {
    let team: Team
    let selection: MatchupSelectionSide?
    let isDisabled: Bool
    let action: () -> Void

    /// Shield width inside a card.
    private let badge: CGFloat = 52
    /// Diameter of the Home/Away status pip.
    private let pip: CGFloat = 22

    private var isSelected: Bool { selection != nil }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                ZStack(alignment: .topTrailing) {
                    TeamBadgeView(team: team, size: badge, showsCode: false)
                        // Fixed shield frame area so every card's badge shares the
                        // same optical footprint and baseline across grid rows.
                        .frame(height: badge * 1.12)
                    if let selection {
                        Text(selection == .home ? "teamselect.home.short" : "teamselect.away.short")
                            .font(.label)
                            .foregroundStyle(Palette.bgDeep)
                            .frame(width: pip, height: pip)
                            .background(Palette.accent, in: Circle())
                            .overlay(Circle().stroke(Palette.bgElevated, lineWidth: 2))
                            .offset(x: pip * 0.42, y: -pip * 0.24)
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
            .background(isSelected ? team.primaryColor.opacity(0.18) : Palette.bgElevated.opacity(0.78),
                        in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.borderSubtle,
                            lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        // Only dim a card that is genuinely unavailable (locked, unpicked). A
        // card already picked for the other side keeps its accent border + pip
        // at full opacity instead of being crushed to an unreadable ghost.
        .opacity(isDisabled && !isSelected ? 0.45 : 1)
        .accessibilityHint(isSelected ? Text("teamselect.selected") : Text(""))
    }
}
