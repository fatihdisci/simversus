//  TournamentKind.swift
//  Core/Models
//
//  Top-level tournament category. Standard covers the four club formats
//  (mini/classic/groupKO/grand); special tournaments like World Arena 2026
//  get their own kind.

import Foundation

enum TournamentKind: String, Codable, CaseIterable {
    /// Club tournaments (mini, classic, groupKO, grand).
    case standard
    /// 48-nation World Arena 2026.
    case nations2026
}
