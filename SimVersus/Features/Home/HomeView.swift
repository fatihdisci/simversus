//  HomeView.swift
//  Night Arena landing screen.

import SwiftUI

struct HomeView: View {
    let onPlay: () -> Void
    let onTournament: () -> Void
    let onTrophyCabinet: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showSettings = false
    @State private var showRemoveAds = false

    var body: some View {
        ZStack {
            ArenaBackground()

            // A GeometryReader + ScrollView lets the layout breathe on tall
            // devices (spacers expand, no scroll) yet stay reachable on short
            // ones (iPhone SE / large Dynamic Type): content taller than the
            // viewport scrolls instead of clipping.
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        brandHeader
                        Spacer(minLength: Spacing.l)
                        hero(arenaSize: arenaSize(for: proxy.size.height))
                        Spacer(minLength: Spacing.xl)
                        actionPanel
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, Spacing.xl)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onDone: { showSettings = false })
        }
        .sheet(isPresented: $showRemoveAds) {
            RemoveAdsSheet()
        }
    }

    // MARK: Header

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
            ArenaIconButton(systemName: "gearshape.fill", accessibilityKey: "settings.title") {
                showSettings = true
            }
        }
    }

    // MARK: Hero

    private func hero(arenaSize: CGFloat) -> some View {
        VStack(spacing: Spacing.m) {
            AmbientArenaView(size: arenaSize)

            VStack(spacing: Spacing.xs) {
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

    /// Shrink the ambient arena on short screens or at large Dynamic Type so the
    /// action card never gets pushed off-screen, without losing the brand.
    private func arenaSize(for availableHeight: CGFloat) -> CGFloat {
        let isShort = availableHeight < Layout.heroCompactHeightThreshold
        let isLargeType = dynamicTypeSize >= .accessibility1
        return (isShort || isLargeType) ? Layout.heroArenaCompact : Layout.heroArenaRegular
    }

    // MARK: Action panel

    private var actionPanel: some View {
        ArenaSurface(padding: Spacing.l) {
            VStack(spacing: Spacing.m) {
                matchMetadataRow
                ArenaCTAButton(title: "home.play", systemImage: "arrow.right", action: onPlay)
                modeActions
                if !purchaseManager.isAdFree {
                    removeAdsUtility
                }
            }
        }
    }

    /// Match duration + spectator note, baseline-aligned with matching icon sizes.
    private var matchMetadataRow: some View {
        HStack(spacing: Spacing.m) {
            Label(durationMetaText, systemImage: "timer")
            Spacer(minLength: Spacing.s)
            Label("home.meta.spectator", systemImage: "eye")
        }
        .font(.caption)
        .foregroundStyle(Palette.textSecondary)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    /// The second-level modes as one equal-weight family. Tournament and Trophy
    /// Cabinet share a single component and differ only by accent — Trophy
    /// Cabinet has a properly aligned icon instead of bare yellow text.
    private var modeActions: some View {
        HStack(spacing: Spacing.s) {
            ArenaModeAction(titleKey: "home.tournament",
                            systemImage: "trophy.fill",
                            accent: Palette.accent,
                            action: onTournament)
            ArenaModeAction(titleKey: "home.trophyCabinet",
                            systemImage: "display.case",
                            accent: Palette.accentWarning,
                            action: onTrophyCabinet)
        }
    }

    /// Lowest-priority utility — readable (not near-invisible) but clearly below
    /// the mode family and never CTA-like.
    private var removeAdsUtility: some View {
        Button(action: { showRemoveAds = true }) {
            Label("home.removeAds", systemImage: "sparkles")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var durationMetaText: String {
        let format = NSLocalizedString("match.duration.seconds %d", comment: "")
        return String.localizedStringWithFormat(format, Int(appState.matchDuration.seconds))
    }
}

// MARK: - Previews

#Preview("Default") {
    HomeView(onPlay: {}, onTournament: {}, onTrophyCabinet: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .preferredColorScheme(.dark)
}

#Preview("Compact height") {
    HomeView(onPlay: {}, onTournament: {}, onTrophyCabinet: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .frame(height: 620)
        .preferredColorScheme(.dark)
}

#Preview("Large Dynamic Type") {
    HomeView(onPlay: {}, onTournament: {}, onTrophyCabinet: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .environment(\.dynamicTypeSize, .accessibility2)
        .preferredColorScheme(.dark)
}

#Preview("English") {
    HomeView(onPlay: {}, onTournament: {}, onTrophyCabinet: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .environment(\.locale, .init(identifier: "en"))
        .preferredColorScheme(.dark)
}
