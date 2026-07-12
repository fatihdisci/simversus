//  CustomTeamStore.swift
//  Core/Data
//
//  Slot bookkeeping for custom teams. Free users get one slot; Phase 2b unlocks
//  more via a rewarded ad by bumping `unlockedSlots` (persisted in UserDefaults).
//  Creation/persistence of the teams themselves is done with SwiftData directly
//  in the views (`@Query` / `modelContext`); this type only owns the slot count.

import Foundation

enum CustomTeamStore {
    private enum Keys {
        static let unlockedSlots = "customTeam.unlockedSlots"
    }

    /// Slots available in the MVP before any rewarded unlock.
    static let baseSlots = 1
    static let maxSlots = 5

    /// How many custom teams the user may keep. Never below `baseSlots`.
    static var unlockedSlots: Int {
        let stored = UserDefaults.standard.integer(forKey: Keys.unlockedSlots)
        return min(maxSlots, max(baseSlots, stored))
    }

    /// True when the user has room for another custom team.
    static func canCreate(existingCount: Int) -> Bool {
        existingCount < unlockedSlots
    }

    static func unlockAdditionalSlot() {
        UserDefaults.standard.set(min(maxSlots, unlockedSlots + 1), forKey: Keys.unlockedSlots)
    }
}
