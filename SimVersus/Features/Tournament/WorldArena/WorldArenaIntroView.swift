//  WorldArenaIntroView.swift

import SwiftUI

struct WorldArenaIntroView: View {
    let onChooseNation: () -> Void
    private let featuredTeams = Array(NationalTeamStore().allTeams.prefix(8))

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            ScrollView {
                VStack(spacing: Spacing.l) {
                    flagOrbit
                    titleBlock
                    formatCard
                    disclaimer
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, 104)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            ArenaCTAButton(title: "tournament.worldArena.chooseNation",
                           systemImage: "flag.fill",
                           action: onChooseNation)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.s)
                .background(.ultraThinMaterial)
        }
        .navigationTitle("tournament.worldArena.name")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var flagOrbit: some View {
        ZStack {
            Circle()
                .stroke(Palette.accentWarning.opacity(0.35), lineWidth: 1)
                .frame(width: 220, height: 220)
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 62, weight: .light))
                .foregroundStyle(Palette.accentWarning)
                .accessibilityHidden(true)
            ForEach(Array(featuredTeams.enumerated()), id: \.element.id) { index, team in
                let angle = Double(index) / Double(featuredTeams.count) * 2 * Double.pi
                NationalFlagView(team: team, style: .compact)
                    .offset(x: CGFloat(cos(angle)) * 96,
                            y: CGFloat(sin(angle)) * 96)
            }
        }
        .frame(height: 232)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("tournament.worldArena.flagCluster")
    }

    private var titleBlock: some View {
        VStack(spacing: Spacing.s) {
            Text("tournament.worldArena.name")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
            Text("tournament.worldArena.subtitle")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var formatCard: some View {
        ArenaSurface {
            VStack(spacing: 0) {
                infoRow(icon: "flag.2.crossed", key: "tournament.worldArena.rule.teams")
                divider
                infoRow(icon: "square.grid.3x3.fill", key: "tournament.worldArena.rule.groups")
                divider
                infoRow(icon: "arrow.up.right", key: "tournament.worldArena.rule.qualifiers")
                divider
                infoRow(icon: "trophy.fill", key: "tournament.worldArena.rule.knockout")
            }
        }
    }

    private func infoRow(icon: String, key: LocalizedStringKey) -> some View {
        Label(key, systemImage: icon)
            .font(.body)
            .foregroundStyle(Palette.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget,
                   alignment: .leading)
    }

    private var divider: some View {
        Rectangle().fill(Palette.borderSubtle).frame(height: 1)
    }

    private var disclaimer: some View {
        Label("tournament.worldArena.disclaimer", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.leading)
    }
}

#Preview {
    NavigationStack { WorldArenaIntroView(onChooseNation: {}) }
        .preferredColorScheme(.dark)
}
