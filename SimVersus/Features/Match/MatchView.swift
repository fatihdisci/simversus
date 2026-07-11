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
        setPaused(!isPaused)
    }

    func setPaused(_ paused: Bool) {
        guard isPaused != paused else { return }
        isPaused = paused
        scene.isPaused = paused
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
    @State private var pauseStateBeforeExitPrompt: Bool?
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
                HStack(alignment: .top, spacing: Spacing.s) {
                    ArenaIconButton(systemName: "xmark",
                                    accessibilityKey: "match.exit") {
                            presentExitConfirmation()
                    }
                    BroadcastScoreboard(homeTeam: model.homeTeam,
                                        awayTeam: model.awayTeam,
                                        hud: model.hud)
                    .frame(maxWidth: 256)
                    ArenaIconButton(systemName: model.isPaused ? "play.fill" : "pause.fill",
                                    accessibilityKey: model.isPaused ? "match.resume" : "match.pause") {
                            model.togglePause()
                    }
                }
                .background(
                    // Report the HUD's bottom edge (in screen space) so the
                    // scene can centre the arena in the space beneath it.
                    GeometryReader { geo in
                        Color.clear.preference(key: HUDBottomKey.self,
                                               value: geo.frame(in: .global).maxY)
                    }
                )
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

            if model.isPaused, !showExitConfirmation {
                MatchPausePanel(onExit: presentExitConfirmation) { model.setPaused(false) }
            }
        }
        .confirmationDialog("match.exit.confirm.title", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("match.exit", role: .destructive, action: confirmExit)
            Button("common.cancel", role: .cancel, action: restoreStateAfterExitPrompt)
        } message: {
            Text("match.exit.confirm.message")
        }
        .onChange(of: showExitConfirmation) { _, isPresented in
            if !isPresented { restoreStateAfterExitPrompt() }
        }
        .onPreferenceChange(HUDBottomKey.self) { bottom in
            // Add a small gap so the arena doesn't butt against the scoreboard.
            model.scene.topReservedInset = bottom + Spacing.m
        }
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

    private func presentExitConfirmation() {
        guard !showExitConfirmation else { return }
        pauseStateBeforeExitPrompt = model.isPaused
        model.setPaused(true)
        showExitConfirmation = true
    }

    private func restoreStateAfterExitPrompt() {
        guard let wasPaused = pauseStateBeforeExitPrompt else { return }
        pauseStateBeforeExitPrompt = nil
        model.setPaused(wasPaused)
    }

    private func confirmExit() {
        pauseStateBeforeExitPrompt = nil
        onExit()
    }

}

/// Carries the HUD's bottom edge (screen-space Y) up to the match view so the
/// scene can reserve that space and centre the arena beneath it.
private struct HUDBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    let teams = TeamStore().mvpTeams
    MatchView(config: MatchConfig(homeTeam: teams[0], awayTeam: teams[2], seed: 7), onExit: {}) { _ in }
}
