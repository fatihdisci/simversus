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
    @Published var showHalfTime = false
    @Published var isPaused = false

    private let matchEnded: (MatchResult) -> Void
    private var flashDismiss: DispatchWorkItem?
    private var halfTimeDismiss: DispatchWorkItem?

    init(config: MatchConfig, onMatchEnded: @escaping (MatchResult) -> Void) {
        homeTeam = config.homeTeam
        awayTeam = config.awayTeam
        matchEnded = onMatchEnded
        scene = MatchScene(config: config)
        scene.onHUDUpdate = { [weak self] snapshot in self?.hud = snapshot }
        scene.onGoalScored = { [weak self] in self?.flashGoal() }
        scene.onHalfTime = { [weak self] in self?.announceHalfTime() }
        scene.onMatchEnded = { [weak self] result in self?.matchEnded(result) }
    }

    func togglePause() {
        isPaused.toggle()
        scene.isPaused = isPaused
    }

    private func announceHalfTime() {
        halfTimeDismiss?.cancel()
        showHalfTime = true
        let work = DispatchWorkItem { [weak self] in self?.showHalfTime = false }
        halfTimeDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + PhysicsConstants.halfTimePause, execute: work)
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
    @State private var showExitConfirmation = false
    private let onExit: () -> Void

    init(config: MatchConfig, onExit: @escaping () -> Void, onMatchEnded: @escaping (MatchResult) -> Void) {
        self.onExit = onExit
        _model = StateObject(wrappedValue: MatchViewModel(config: config, onMatchEnded: onMatchEnded))
    }

    var body: some View {
        ZStack {
            Palette.bgArena.ignoresSafeArea()

            SpriteView(scene: model.scene, preferredFramesPerSecond: 60)
                .ignoresSafeArea()

            VStack(spacing: Spacing.m) {
                ZStack(alignment: .top) {
                    scoreboard
                        .frame(maxWidth: 248)

                    HStack {
                        controlButton(systemName: "xmark", label: "match.exit") {
                            if !model.isPaused { model.togglePause() }
                            showExitConfirmation = true
                        }
                        Spacer()
                        controlButton(systemName: model.isPaused ? "play.fill" : "pause.fill",
                                      label: model.isPaused ? "match.resume" : "match.pause") {
                            model.togglePause()
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.top, Spacing.s)

            goalFlash
                .opacity(model.showGoalFlash ? 1 : 0)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.showGoalFlash)
                .allowsHitTesting(false)

            halfTimeAnnouncement
                .opacity(model.showHalfTime ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.78), value: model.showHalfTime)
                .allowsHitTesting(false)

            if model.isPaused { pauseOverlay }
        }
        .confirmationDialog("match.exit.confirm.title", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("match.exit", role: .destructive, action: onExit)
            Button("match.resume", role: .cancel) {
                if model.isPaused { model.togglePause() }
            }
        } message: {
            Text("match.exit.confirm.message")
        }
    }

    // MARK: Scoreboard

    private var scoreboard: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: 10) {
                TeamBadgeView(team: model.homeTeam, size: 30)
                Text("\(model.hud.homeScore)")
                    .font(.scoreboard)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(minWidth: 26)
                Text(verbatim: "–")
                    .font(.scoreSeparator)
                    .foregroundStyle(Palette.textSecondary)
                Text("\(model.hud.awayScore)")
                    .font(.scoreboard)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(minWidth: 26)
                TeamBadgeView(team: model.awayTeam, size: 30)
            }
            HStack(spacing: Spacing.s) {
                Text(verbatim: "\(model.hud.minute)'")
                    .font(.label)
                    .foregroundStyle(Palette.accent)
                Text(model.hud.isFirstHalf ? "match.half.first" : "match.half.second")
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, Spacing.s)
        .background(Palette.bgElevated.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    // MARK: Goal flash

    private var goalFlash: some View {
        Text("match.goal")
            .font(.scoreboard)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.m)
            .background(Palette.bgElevated.opacity(0.82), in: Capsule())
            .shadow(color: Palette.accent.opacity(0.65), radius: 22)
            .scaleEffect(model.showGoalFlash ? 1 : 0.72)
    }

    private var halfTimeAnnouncement: some View {
        VStack(spacing: Spacing.xs) {
            Text("match.halftime.title")
                .font(.titleXL)
                .foregroundStyle(.white)
            Text("match.halftime.subtitle")
                .font(.label)
                .foregroundStyle(Palette.accent)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
        .background(Palette.bgElevated.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(Palette.accent.opacity(0.45)))
    }

    private var pauseOverlay: some View {
        VStack(spacing: Spacing.l) {
            Image(systemName: "pause.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Palette.accent)
            Text("match.paused.title")
                .font(.titleXL)
                .foregroundStyle(.white)
            HStack(spacing: Spacing.m) {
                Button("match.exit", role: .destructive) { showExitConfirmation = true }
                    .buttonStyle(.bordered)
                Button("match.resume") { model.togglePause() }
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
            }
        }
        .padding(Spacing.xl)
        .background(Palette.bgElevated.opacity(0.96), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card).stroke(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.35), radius: 30)
    }

    private func controlButton(systemName: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 42, height: 42)
                .foregroundStyle(.white)
                .background(Palette.bgElevated.opacity(0.9), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.12)))
        }
        .accessibilityLabel(Text(label))
    }
}

#Preview {
    let teams = TeamStore().mvpTeams
    MatchView(config: MatchConfig(homeTeam: teams[0], awayTeam: teams[2], seed: 7), onExit: {}) { _ in }
}
