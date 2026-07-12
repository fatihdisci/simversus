//  WorldGroupStandingsTests.swift
//  SimVersusTests
//
//  Commit 3A — the central standing ranker rules and group table computation.

import XCTest
@testable import SimVersus

final class WorldGroupStandingsTests: XCTestCase {

    private func standing(_ id: String, p: Int, w: Int, d: Int, l: Int,
                          gf: Int, ga: Int) -> GroupStanding {
        GroupStanding(teamID: id, played: p, wins: w, draws: d, losses: l,
                      goalsFor: gf, goalsAgainst: ga, points: w * 3 + d)
    }

    /// A context with no head-to-head and a fixed seeded tiebreak by team id.
    private func plainContext(_ seed: UInt64 = 7) -> StandingRankContext {
        .crossGroup(tournamentSeed: seed, namespace: "test-tiebreak")
    }

    // MARK: - Ordering rules

    func testPointsBeatEverything() {
        let a = standing("A", p: 3, w: 1, d: 0, l: 2, gf: 1, ga: 9)  // 3 pts
        let b = standing("B", p: 3, w: 0, d: 2, l: 1, gf: 9, ga: 1)  // 2 pts
        let ranked = TournamentStandingRanker.rank([b, a], context: plainContext())
        XCTAssertEqual(ranked.map(\.teamID), ["A", "B"])
    }

    func testGoalDifferenceBeforeGoalsScored() {
        let a = standing("A", p: 3, w: 1, d: 0, l: 0, gf: 5, ga: 0)  // GD +5, GF 5
        let b = standing("B", p: 3, w: 1, d: 0, l: 0, gf: 9, ga: 6)  // GD +3, GF 9
        let ranked = TournamentStandingRanker.rank([b, a], context: plainContext())
        XCTAssertEqual(ranked.first?.teamID, "A")
    }

    func testGoalsScoredBeforeWins() {
        // Equal points and GD; A scored more, B has more wins. GF wins the tie.
        let a = standing("A", p: 8, w: 1, d: 6, l: 1, gf: 8, ga: 6)  // 9 pts, GD +2, GF 8, 1 win
        let b = standing("B", p: 3, w: 3, d: 0, l: 0, gf: 5, ga: 3)  // 9 pts, GD +2, GF 5, 3 wins
        let ranked = TournamentStandingRanker.rank([b, a], context: plainContext())
        XCTAssertEqual(ranked.first?.teamID, "A")
    }

    func testWinsBreakTieAfterGoalsScored() {
        // Equal points, GD and GF; more wins ranks higher.
        let a = standing("A", p: 4, w: 1, d: 1, l: 1, gf: 4, ga: 2)
        let b = standing("B", p: 4, w: 2, d: 1, l: 0, gf: 4, ga: 2)
        let ranked = TournamentStandingRanker.rank([a, b], context: plainContext())
        XCTAssertEqual(ranked.first?.teamID, "B")
    }

    func testTwoTeamHeadToHeadResolvesTie() {
        // A and B tie on every numeric key; B won the direct meeting.
        let a = standing("A", p: 6, w: 2, d: 0, l: 1, gf: 4, ga: 2)
        let b = standing("B", p: 6, w: 2, d: 0, l: 1, gf: 4, ga: 2)
        let context = StandingRankContext(
            headToHead: { x, y in
                if x == "A" && y == "B" { return -1 }  // B ahead of A
                if x == "B" && y == "A" { return 1 }
                return nil
            },
            seededTiebreak: { _ in 0 })
        let ranked = TournamentStandingRanker.rank([a, b], context: context)
        XCTAssertEqual(ranked.map(\.teamID), ["B", "A"])
    }

    func testThreeWayTieIsDeterministicAndStable() {
        // Three teams equal on every numeric key: order must not depend on input
        // order and must be identical run to run (no head-to-head chaining).
        let teams = ["A", "B", "C"].map { standing($0, p: 3, w: 1, d: 0, l: 2, gf: 2, ga: 2) }
        // A H2H that would create a non-transitive cycle if (wrongly) applied.
        let cyclic = StandingRankContext(
            headToHead: { x, y in
                let order = ["A": 0, "B": 1, "C": 2]
                guard let ix = order[x], let iy = order[y] else { return nil }
                return (ix + 1) % 3 == iy ? 1 : -1   // A>B>C>A cycle
            },
            seededTiebreak: { TournamentSeedDeriver.derive(tournamentSeed: 99, fixtureID: "t-\($0)") })
        let r1 = TournamentStandingRanker.rank(teams, context: cyclic)
        let r2 = TournamentStandingRanker.rank(Array(teams.reversed()), context: cyclic)
        XCTAssertEqual(r1.map(\.teamID), r2.map(\.teamID))
        XCTAssertEqual(Set(r1.map(\.teamID)), ["A", "B", "C"])
    }

    func testSameSeedSameOrder() {
        let teams = ["A", "B", "C", "D"].map { standing($0, p: 3, w: 1, d: 0, l: 2, gf: 2, ga: 2) }
        XCTAssertEqual(TournamentStandingRanker.rank(teams, context: plainContext(42)).map(\.teamID),
                       TournamentStandingRanker.rank(teams, context: plainContext(42)).map(\.teamID))
    }

    // MARK: - Group table computation

    func testPointsWinDrawLossAndPlayedOnly() {
        let group = GroupAssignment(id: "A", teamIDs: ["t0", "t1", "t2", "t3"])
        let fixtures = WorldGroupStageEngine.generateFixtures(groups: [group], tournamentSeed: 1)
        // Play only matchday 1: t0 v t3 (t0 wins 2-0), t1 v t2 (draw 1-1).
        let results = [
            result("WA-GA-MD1-M1", 2, 0, winner: "t0"),
            result("WA-GA-MD1-M2", 1, 1, winner: nil),
        ]
        let table = WorldGroupStageEngine.standings(for: group, fixtures: fixtures,
                                                    results: results, tournamentSeed: 1)
        let byID = Dictionary(uniqueKeysWithValues: table.map { ($0.teamID, $0) })
        XCTAssertEqual(byID["t0"]?.points, 3)   // win
        XCTAssertEqual(byID["t0"]?.played, 1)
        XCTAssertEqual(byID["t3"]?.points, 0)   // loss
        XCTAssertEqual(byID["t1"]?.points, 1)   // draw
        XCTAssertEqual(byID["t2"]?.points, 1)   // draw
        XCTAssertEqual(byID["t0"]?.goalDifference, 2)
        XCTAssertEqual(table.first?.teamID, "t0")   // leads the group
    }

    private func result(_ id: String, _ h: Int, _ a: Int, winner: String?) -> FixtureResult {
        FixtureResult(fixtureID: id, homeScore: h, awayScore: a,
                      winnerTeamID: winner, goals: [], isSimulated: true)
    }
}
