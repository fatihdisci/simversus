//  HomeView.swift
//  Night Arena landing screen.

import SwiftUI

struct HomeView: View {
    let onPlay: () -> Void

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
        }
    }

    private var hero: some View {
        VStack(spacing: Spacing.l) {
            AmbientArenaView()

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
                    Spacer()
                    Label("home.duration.short", systemImage: "timer")
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
