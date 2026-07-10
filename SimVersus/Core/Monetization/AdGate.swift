//  AdGate.swift
//  Core/Monetization
//
//  Stub for the ad gate. Part 1d only needs a single call site — the result
//  screen signals dismissal via `onResultDismiss()` — so the surface stays
//  ready for Part 1e to wire up the AdMob interstitial cadence specified in
//  CONSTITUTION §4.3 (every 3rd match, gated by `AdManager` / `PurchaseManager`).

import Foundation

enum AdGate {
    /// Called when the user leaves the result screen. No-op in Part 1d;
    /// Part 1e turns it into the interstitial trigger.
    static func onResultDismiss() {
        // Intentionally empty until Part 1e fills in the AdMob / IAP wiring.
    }
}
