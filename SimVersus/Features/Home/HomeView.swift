//  HomeView.swift
//  Night Arena landing screen.

import SwiftUI

struct HomeView: View {
    let onPlay: () -> Void
    let onHistory: () -> Void
    let onTournament: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showSettings = false
    @State private var showRemoveAds = false

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
        .sheet(isPresented: $showSettings) {
            SettingsView(onDone: { showSettings = false })
        }
        .sheet(isPresented: $showRemoveAds) {
            RemoveAdsSheet()
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
            ArenaIconButton(systemName: "gearshape.fill", accessibilityKey: "settings.title") {
                showSettings = true
            }
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
        ArenaSurface(padding: Spacing.l) {
            VStack(spacing: Spacing.l) {
                HStack {
                    Label(durationMetaText, systemImage: "timer")
                    Spacer()
                    Text("home.meta.spectator")
                }
                .font(.caption).foregroundStyle(Palette.textSecondary)

                VStack(spacing: Spacing.s) {
                    ArenaCTAButton(title: "home.play", systemImage: "arrow.right", action: onPlay)

                    Button(action: onTournament) {
                        Label("Turnuva", systemImage: "trophy.fill")
                            .font(.sectionLabel)
                            .foregroundStyle(Palette.accent)
                            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                    }.buttonStyle(.plain)

                    Button(action: onHistory) {
                        Label("home.history", systemImage: "clock.arrow.circlepath")
                            .font(.sectionLabel)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                    }.buttonStyle(.plain)

                    if !purchaseManager.isAdFree {
                        Button(action: { showRemoveAds = true }) {
                            Text("home.removeAds")
                                .font(.caption)
                                .foregroundStyle(Palette.textTertiary)
                                .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var durationMetaText: String {
        let format = NSLocalizedString("match.duration.seconds %d", comment: "")
        return String.localizedStringWithFormat(format, Int(appState.matchDuration.seconds))
    }
}

#Preview {
    HomeView(onPlay: {}, onHistory: {}, onTournament: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .preferredColorScheme(.dark)
}
