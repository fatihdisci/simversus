//  AppRoute.swift
//  App
//
//  Route enum that drives the root `NavigationStack` in `RootView`. Each case
//  carries exactly what its destination view needs: the match route keeps the
//  full `MatchConfig` so it can be replayed with a fresh seed for a rematch,
//  and the result route carries both the finished `MatchResult` and the
//  originating `MatchConfig` so the result screen can do the same.

import Foundation

enum AppRoute: Hashable {
    case home
    case teamSelect
    case teamCreator
    case match(MatchConfig)
    case result(MatchResult, MatchConfig)
}
