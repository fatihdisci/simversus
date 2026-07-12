import XCTest
@testable import SimVersus

final class WorldArenaNavigationTests: XCTestCase {
    func testMatchContextCarriesExactFixtureIdentity() {
        let tournamentID = UUID()
        let context = MatchContext.worldArena(
            tournamentID: tournamentID,
            fixtureID: "WA-GA-MD2-M1",
            stage: .group)

        XCTAssertEqual(context.tournamentID, tournamentID)
        XCTAssertEqual(context.fixtureID, "WA-GA-MD2-M1")
    }

    func testResultUpdatesExactFixtureWhenTeamsRepeat() throws {
        let fixtures = [
            Fixture(id: "first", homeTeamID: "a", awayTeamID: "b",
                    round: 0, groupIndex: 0, matchIndex: 0, seed: 1),
            Fixture(id: "second", homeTeamID: "a", awayTeamID: "b",
                    round: 0, groupIndex: 0, matchIndex: 1, seed: 2),
        ]
        let state = TournamentState(format: .mini,
                                    playerTeamID: "a",
                                    teams: ["a", "b", "c", "d"],
                                    fixtures: fixtures)
        let result = FixtureResult(fixtureID: "second", homeScore: 2,
                                   awayScore: 1, winnerTeamID: "a",
                                   goals: [], isSimulated: false)

        XCTAssertTrue(try TournamentResultRecorder.record(
            result, fixtureID: "second", in: state))
        XCTAssertEqual(state.results.map(\.fixtureID), ["second"])
    }

    func testRepeatedResultRecordingIsIdempotent() throws {
        let fixture = Fixture(id: "fixture", homeTeamID: "a", awayTeamID: "b",
                              round: 1, groupIndex: nil, matchIndex: 0, seed: 1)
        let state = TournamentState(format: .mini,
                                    playerTeamID: "a",
                                    teams: ["a", "b", "c", "d"],
                                    fixtures: [fixture])
        let result = FixtureResult(fixtureID: fixture.id, homeScore: 1,
                                   awayScore: 0, winnerTeamID: "a",
                                   goals: [], isSimulated: false)

        XCTAssertTrue(try TournamentResultRecorder.record(
            result, fixtureID: fixture.id, in: state))
        XCTAssertFalse(try TournamentResultRecorder.record(
            result, fixtureID: fixture.id, in: state))
        XCTAssertEqual(state.results.count, 1)
    }
}
