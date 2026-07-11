//  HomeView.swift
//  Night Arena landing screen.

import SwiftUI

struct HomeView: View {
    let onPlay: () -> Void
    private let showcaseTeams = Array(TeamStore().mvpTeams.prefix(2))

    var body: some View {
        ZStack {
            ArenaBackground()

            VStack(spacing: 0) {
                brandHeader
                Spacer(minLength: Spacing.l)
                hero
                Spacer(minLength: Spacing.xl)
                actionPanel
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.xl)
        }
    }

    private var brandHeader: some View {
        HStack {
            HStack(spacing: Spacing.s) {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: Palette.accent, radius: 6)
                Text("home.eyebrow")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Text("home.duration.short")
                .font(.label)
                .foregroundStyle(Palette.accent)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(Palette.accent.opacity(0.1), in: Capsule())
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.l) {
            ZStack {
                Circle()
                    .stroke(Palette.energy.opacity(0.22), lineWidth: 1)
                    .frame(width: 246, height: 246)
                Circle()
                    .stroke(Palette.accent.opacity(0.12),
                            style: StrokeStyle(lineWidth: 12, dash: [2, 14]))
                    .frame(width: 198, height: 198)

                if showcaseTeams.count == 2 {
                    TeamOrbView(team: showcaseTeams[0], size: 76)
                        .offset(x: -62, y: 38)
                    TeamOrbView(team: showcaseTeams[1], size: 68)
                        .offset(x: 58, y: -42)
                }

                Text("common.versus")
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(Spacing.s)
                    .background(Palette.bgElevatedStrong, in: Circle())
                    .overlay(Circle().stroke(Palette.borderStrong))
            }

            VStack(spacing: Spacing.s) {
                Text("home.title")
                    .font(.display)
                    .foregroundStyle(Palette.textPrimary)
                Text("home.subtitle")
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionPanel: some View {
        ArenaSurface {
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    Label("home.meta.spectator", systemImage: "eye.fill")
                    Spacer()
                    Label("home.meta.physics", systemImage: "circle.hexagongrid.fill")
                }
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)

                Button(action: onPlay) {
                    HStack {
                        Text("home.play")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(ArenaButtonStyle(kind: .primary))

                Button(action: {}) {
                    Text("home.removeAds")
                        .font(.sectionLabel)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    HomeView(onPlay: {})
        .preferredColorScheme(.dark)
}
