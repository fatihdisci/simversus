import XCTest
import SwiftData
@testable import SimVersus

@MainActor
final class WorldArenaProgressionTests: XCTestCase {
    private func makeController(seed: UInt64 = 42) async throws
        -> (WorldArenaSessionController, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TournamentState.self,
                                           configurations: configuration)
        let context = ModelContext(container)
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: seed)
        let controller = try WorldArenaSessionController(
            tournamentID: state.id, modelContext: context)

        for _ in 1...3 {
            let fixture = try XCTUnwrap(controller.nextPlayerGroupFixture)
            let playerHome = fixture.homeTeamID == state.playerTeamID
            let result = FixtureResult(
                fixtureID: fixture.id,
                homeScore: playerHome ? 3 : 0,
                awayScore: playerHome ? 0 : 3,
                winnerTeamID: state.playerTeamID,
                goals: [], isSimulated: false)
            _ = try TournamentResultRecorder.record(
                result, fixtureID: fixture.id, in: state)
            await controller.resumeProgression()
        }
        return (controller, context)
    }

    func testKnockoutDrawResolvesDecisivelyAndPropagates() async throws {
        let (controller, _) = try await makeController(seed: 10)
        await controller.resumeKnockoutProgression()
        let fixture = try XCTUnwrap(controller.nextPlayerKnockoutFixture)
        let draw = MatchResult(homeTeamID: fixture.homeTeamID,
                               awayTeamID: fixture.awayTeamID,
                               homeScore: 1, awayScore: 1, goals: [])

        let stored = try controller.recordPlayerKnockoutResult(
            draw, fixtureID: fixture.id)

        XCTAssertNotNil(stored.winnerTeamID)
        XCTAssertNotEqual(stored.resolution, .regulation)
        XCTAssertEqual(controller.state.results.count, 88)
        let nextRound = try XCTUnwrap(controller.bracket).fixtures.filter { $0.round == 2 }
        XCTAssertTrue(nextRound.contains {
            $0.homeTeamID == stored.winnerTeamID || $0.awayTeamID == stored.winnerTeamID
        })
    }

    func testPlayerLossPersistsElimination() async throws {
        let (controller, context) = try await makeController(seed: 11)
        await controller.resumeKnockoutProgression()
        let fixture = try XCTUnwrap(controller.nextPlayerKnockoutFixture)
        let playerHome = fixture.homeTeamID == controller.state.playerTeamID
        let loss = MatchResult(homeTeamID: fixture.homeTeamID,
                               awayTeamID: fixture.awayTeamID,
                               homeScore: playerHome ? 0 : 2,
                               awayScore: playerHome ? 2 : 0,
                               goals: [])
        _ = try controller.recordPlayerKnockoutResult(loss, fixtureID: fixture.id)

        XCTAssertTrue(controller.isPlayerEliminated)
        let resumed = try WorldArenaSessionController(
            tournamentID: controller.state.id, modelContext: context)
        XCTAssertTrue(resumed.isPlayerEliminated)
    }

    func testEliminatedPlayerCanFinishTournament() async throws {
        let (controller, _) = try await makeController(seed: 12)
        await controller.resumeKnockoutProgression()
        let fixture = try XCTUnwrap(controller.nextPlayerKnockoutFixture)
        let playerHome = fixture.homeTeamID == controller.state.playerTeamID
        let loss = MatchResult(homeTeamID: fixture.homeTeamID,
                               awayTeamID: fixture.awayTeamID,
                               homeScore: playerHome ? 0 : 1,
                               awayScore: playerHome ? 1 : 0,
                               goals: [])
        _ = try controller.recordPlayerKnockoutResult(loss, fixtureID: fixture.id)

        await controller.finishTournamentAfterElimination()

        XCTAssertEqual(controller.state.phase, .finished)
        XCTAssertNotNil(controller.state.completedAt)
        XCTAssertNotNil(controller.championTeamID)
        XCTAssertEqual(controller.state.results.filter {
            $0.fixtureID.hasPrefix("WA-") && !$0.fixtureID.contains("-G")
        }.count, 31)
    }
}
