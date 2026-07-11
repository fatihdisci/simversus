import SwiftUI

struct BroadcastScoreboard: View {
    let homeTeam: Team
    let awayTeam: Team
    let hud: MatchHUDSnapshot

    private var progress: CGFloat {
        min(1, max(0, CGFloat(hud.minute) / CGFloat(PhysicsConstants.displayMatchMinutes)))
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                team(team: homeTeam, score: hud.homeScore, isHome: true)
                Text(verbatim: "–")
                    .font(.scoreSeparator)
                    .foregroundStyle(Palette.textTertiary)
                team(team: awayTeam, score: hud.awayScore, isHome: false)
            }

            HStack(spacing: Spacing.s) {
                Text(verbatim: "\(hud.minute)'")
                    .font(.label)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 34, alignment: .leading)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.borderSubtle)
                        Capsule()
                            .fill(LinearGradient(colors: [homeTeam.primaryColor, Palette.accent, awayTeam.primaryColor],
                                                 startPoint: .leading,
                                                 endPoint: .trailing))
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 4)
                Text(hud.isFirstHalf ? "match.half.first" : "match.half.second")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Spacing.s)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .stroke(LinearGradient(colors: [homeTeam.primaryColor.opacity(0.7),
                                                 Palette.borderSubtle,
                                                 awayTeam.primaryColor.opacity(0.7)],
                                       startPoint: .leading,
                                       endPoint: .trailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
    }

    private func team(team: Team, score: Int, isHome: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            if isHome { TeamOrbView(team: team, size: 28) }
            Text("\(score)")
                .font(.scoreboard)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 30)
            if !isHome { TeamOrbView(team: team, size: 28) }
        }
        .frame(maxWidth: .infinity, alignment: isHome ? .leading : .trailing)
    }
}

struct MatchPausePanel: View {
    let onExit: () -> Void
    let onResume: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()
            ArenaSurface(padding: Spacing.l, isFocused: true) {
                VStack(spacing: Spacing.l) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 52, height: 52)
                        .background(Palette.accent.opacity(0.12), in: Circle())
                    VStack(spacing: Spacing.xs) {
                        Text("match.paused.title")
                            .font(.headline)
                            .foregroundStyle(Palette.textPrimary)
                        Text("match.paused.subtitle")
                            .font(.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Button("match.resume", action: onResume)
                        .buttonStyle(ArenaButtonStyle(kind: .primary))
                    Button("match.exit", role: .destructive, action: onExit)
                        .buttonStyle(ArenaButtonStyle(kind: .destructive))
                }
                .frame(maxWidth: 260)
            }
            .padding(.horizontal, Spacing.xl)
        }
    }
}
