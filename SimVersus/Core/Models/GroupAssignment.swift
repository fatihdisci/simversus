//  GroupAssignment.swift
//  Core/Models
//
//  Result models for the World Arena 2026 group draw (Commit 3). A
//  `GroupAssignment` binds one group letter (A…L) to its four drawn team IDs;
//  a `WorldGroupStage` is the full drawn stage — 12 groups + 72 fixtures — as a
//  single Codable aggregate so it can later be persisted inside `TournamentState`
//  without a schema migration (it serialises to the existing Data blobs).

import Foundation

/// One drawn group: a stable letter id and exactly four team IDs.
struct GroupAssignment: Codable, Equatable, Identifiable {
    /// Group letter, "A"…"L". Matches the order of `TournamentDefinition.groups`.
    let id: String
    /// The four team IDs drawn into this group, in draw order (pot 1 → pot 4).
    let teamIDs: [String]
}

/// The complete drawn group stage: assignments and every group fixture.
/// Codable + Equatable so it round-trips through JSON for persistence and tests.
struct WorldGroupStage: Codable, Equatable {
    let groups: [GroupAssignment]
    let fixtures: [Fixture]
}
