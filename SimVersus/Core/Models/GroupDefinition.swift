//  GroupDefinition.swift
//  Core/Models
//
//  Describes one group in a tournament: which teams are in it (or how many
//  slots), how many advance, and how the knockout bracket maps group ranks.

import Foundation

struct GroupDefinition: Codable, Identifiable, Equatable {
    /// Group identifier, e.g. "A", "B", ... "L".
    let id: String
    /// Pre-assigned team IDs. Empty means teams are assigned by draw.
    let teamIDs: [String]
    /// Number of teams that advance directly to the knockout stage.
    let advanceDirectCount: Int

    init(id: String, teamIDs: [String] = [], advanceDirectCount: Int = 2) {
        self.id = id
        self.teamIDs = teamIDs
        self.advanceDirectCount = advanceDirectCount
    }
}
