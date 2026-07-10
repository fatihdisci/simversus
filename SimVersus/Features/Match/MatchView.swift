//  MatchView.swift
//  Features/Match
//
//  Spectator match screen: a SpriteView hosting `MatchScene` with a SwiftUI HUD
//  on top (scoreboard, clock, half label, goal flash). Navigation and the
//  post-match hand-off are wired in Part 1d via `onMatchEnded`.

import SwiftUI
import SpriteKit

final class MatchViewModel: ObservableObject {
    let scene: MatchScene
    let homeTeam: Team
    let awayTeam: Team

    @Published var hud = MatchHUDSnapshot()
    @Published var showGoalFlash = false

    private let matchEnded: (MatchResult) -> Void
    private var flashDismiss: DispatchWorkItem?

    init(config: MatchConfig, onMatchEnded: @escaping (MatchResult) -> Void) {
        homeTeam = config.homeTeam
        awayTeam = config.awayTeam
        matchEnded = onMatchEnded
        scene = MatchScene(config: config)
        scene.onHUDUpdate = { [weak self] snapshot in self?.hud = snapshot }
        scene.onGoalScored = { [weak self] in self?.flashGoal() }
        scene.onMatchEnded = { [weak self] result in self?.matchEnded(result) }
    }

    private func flashGoal() {
        flashDismiss?.cancel()
        showGoalFlash = true
        let work = DispatchWorkItem { [weak self] in self?.showGoalFlash = false }
        flashDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PhysicsConstants.goalCelebrationPause, execute: work)
    }
}

struct MatchView: View {
    @StateObject private var model: MatchViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(config: MatchConfig, onMatchEnded: @escaping (MatchResult) -> Void) {
        _model = StateObject(wrappedValue: MatchViewModel(config: config, onMatchEnded: onMatchEnded))
    }

    var body: some View {
        ZStack {
            Palette.bgArena.ignoresSafeArea()

            SpriteView(scene: model.scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()

            VStack {
                scoreboard
                Spacer()
            }
            .padding(.top, Spacing.m)

            goalFlash
                .opacity(model.showGoalFlash ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.showGoalFlash)
                .allowsHitTesting(false)
        }
    }

    // MARK: Scoreboard

    private var scoreboard: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.l) {
                TeamBadgeView(team: model.homeTeam, size: 34)
                Text("\(model.hud.homeScore)")
                    .font(.scoreboard)
                    .foregroundStyle(Palette.textPrimary)
                Text(verbatim: "–")
                    .font(.titleXL)
                    .foregroundStyle(Palette.textSecondary)
                Text("\(model.hud.awayScore)")
                    .font(.scoreboard)
                    .foregroundStyle(Palette.textPrimary)
                TeamBadgeView(team: model.awayTeam, size: 34)
            }
            HStack(spacing: Spacing.s) {
                Text(verbatim: "\(model.hud.minute)'")
                    .font(.label)
                    .foregroundStyle(Palette.accent)
                Text(model.hud.isFirstHalf ? "match.half.first" : "match.half.second")
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(Palette.bgElevated.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: Goal flash

    private var goalFlash: some View {
        ZStack {
            Palette.goalFlash.ignoresSafeArea()
            Text("match.goal")
                .font(.scoreboard)
                .foregroundStyle(Palette.bgPrimary)
        }
    }
}

#Preview {
    let teams = TeamStore().mvpTeams
    MatchView(config: MatchConfig(homeTeam: teams[0], awayTeam: teams[2], seed: 7)) { _ in }
}
