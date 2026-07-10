//  SimVersusApp.swift
//  App
//
//  Application entry point. Hosts the root scene and injects shared state.
//  `RootView` owns the navigation; the app is dark-themed throughout
//  ("stadium night match").

import SwiftUI

@main
struct SimVersusApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
