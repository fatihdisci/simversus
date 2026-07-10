//  TeamMatchup.swift
//  Features/TeamSelect
//
//  Pure selection state for the team-select screen. Enforces the rule that a
//  team can never be chosen on both sides: a team already picked for one side
//  is disabled on the other, so `home` and `away` can never be equal.

import Foundation

struct TeamMatchup: Equatable {
    private(set) var home: Team?
    private(set) var away: Team?

    /// Both sides chosen — the Kick Off CTA becomes active.
    var isReady: Bool { home != nil && away != nil }

    /// A team is unavailable on the home side while it is the away pick.
    func isDisabledForHome(_ team: Team) -> Bool { away == team }

    /// A team is unavailable on the away side while it is the home pick.
    func isDisabledForAway(_ team: Team) -> Bool { home == team }

    /// Toggles the home pick. Tapping the current pick clears it; picking a team
    /// that is the away pick is ignored (it is disabled in the UI too).
    mutating func selectHome(_ team: Team) {
        guard !isDisabledForHome(team) else { return }
        home = (home == team) ? nil : team
    }

    /// Toggles the away pick. Mirror of `selectHome`.
    mutating func selectAway(_ team: Team) {
        guard !isDisabledForAway(team) else { return }
        away = (away == team) ? nil : team
    }
}
