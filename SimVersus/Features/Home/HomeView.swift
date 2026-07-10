//  HomeView.swift
//  Features/Home
//
//  App landing screen: brand title, primary "Start Match" CTA and a secondary
//  "Remove Ads" action. Navigation is driven by the `onPlay` closure wired up
//  in `RootView`; the "Remove Ads" action stays inert until Part 1e.

import SwiftUI

struct HomeView: View {
    /// Invoked when the user taps "Start Match". The host pushes the team
    /// select destination onto the navigation stack.
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Palette.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Spacer()
                title
                Spacer()
                playButton
                removeAdsButton
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
    }

    // MARK: - Subviews

    private var title: some View {
        Text("home.title")
            .font(.scoreboard)
            .foregroundStyle(Palette.textPrimary)
    }

    private var playButton: some View {
        Button(action: onPlay) {
            Text("home.play")
                .font(.titleXL)
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.m)
                .background(
                    Palette.accent,
                    in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }

    private var removeAdsButton: some View {
        Button(action: {}) {
            Text("home.removeAds")
                .font(.label)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView(onPlay: {})
        .preferredColorScheme(.dark)
}
