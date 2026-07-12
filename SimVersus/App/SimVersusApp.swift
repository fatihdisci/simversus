//  SimVersusApp.swift
//  App
//
//  Application entry point. Hosts the root scene and injects shared state.
//  `RootView` owns the navigation; the app is dark-themed throughout
//  ("stadium night match").

import SwiftUI
import SwiftData

@main
struct SimVersusApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var consentManager = ConsentManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(purchaseManager)
                .preferredColorScheme(.dark)
                .task {
                    await consentManager.requestConsent()
                    await AdManager.shared.preload()
                    await AdManager.shared.preloadRewarded()
                }
        }
        // Persists user-created teams (Phase 2a). The container is injected into
        // the environment so `@Query` / `modelContext` work throughout the app.
        .modelContainer(for: [CustomTeam.self, MatchRecord.self, TournamentState.self])
    }
}
