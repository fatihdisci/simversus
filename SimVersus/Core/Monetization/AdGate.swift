//  AdGate.swift
//  Core/Monetization
//
//  Result-screen exit hook for the Phase 1e interstitial cadence.

enum AdGate {
    static func onResultDismiss(matchesPlayed: Int) {
        Task { @MainActor in
            AdManager.shared.matchCompleted(matchesPlayed: matchesPlayed)
        }
    }
}
