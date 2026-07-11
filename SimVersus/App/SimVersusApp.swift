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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        // Persists user-created teams (Phase 2a). The container is injected into
        // the environment so `@Query` / `modelContext` work throughout the app.
        .modelContainer(for: CustomTeam.self)
    }
}
