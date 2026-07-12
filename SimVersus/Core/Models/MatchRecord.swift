import Foundation
import SwiftData

@Model
final class MatchRecord {
    var homeTeamID: String
    var awayTeamID: String
    var homeScore: Int
    var awayScore: Int
    var goalsData: Data
    var playedAt: Date
    var seed: UInt64

    init(result: MatchResult, seed: UInt64, playedAt: Date = .now) {
        homeTeamID = result.homeTeamID; awayTeamID = result.awayTeamID
        homeScore = result.homeScore; awayScore = result.awayScore
        goalsData = (try? JSONEncoder().encode(result.goals)) ?? Data()
        self.seed = seed; self.playedAt = playedAt
    }

    var goals: [Goal] { (try? JSONDecoder().decode([Goal].self, from: goalsData)) ?? [] }
}
