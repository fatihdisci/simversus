import XCTest
import SwiftData
@testable import SimVersus

@MainActor
final class WorldArenaSessionControllerTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TournamentState.self,
                                           configurations: configuration)
        return ModelContext(container)
    }

    func testCreationPersistsCompleteGroupStageOnce() throws {
        let context = try makeContext()
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: 42)

        XCTAssertEqual(state.competitionID, TournamentDefinition.WorldArena.id)
        XCTAssertEqual(state.playerTeamID, "nation-tr")
        XCTAssertEqual(state.tournamentSeed, 42)
        XCTAssertEqual(state.groupAssignments.count, 12)
        XCTAssertEqual(state.fixtures.count, 72)
        XCTAssertTrue(state.results.isEmpty)
        XCTAssertNil(state.knockoutBracket)

        _ = try WorldArenaSessionController(tournamentID: state.id,
                                            modelContext: context)
        _ = try WorldArenaSessionController(tournamentID: state.id,
                                            modelContext: context)
        let states = try context.fetch(FetchDescriptor<TournamentState>())
        XCTAssertEqual(states.count, 1)
    }

    func testResumePreservesSeedAndDraw() throws {
        let context = try makeContext()
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: 99)
        let groups = state.groupAssignments
        let fixtures = state.fixtures

        let resumed = try WorldArenaSessionController(
            tournamentID: state.id, modelContext: context)

        XCTAssertEqual(resumed.state.tournamentSeed, 99)
        XCTAssertEqual(resumed.state.groupAssignments, groups)
        XCTAssertEqual(resumed.state.fixtures, fixtures)
    }

    func testMatchdayProgressionAndBracketGeneration() async throws {
        let context = try makeContext()
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: 7)
        let controller = try WorldArenaSessionController(
            tournamentID: state.id, modelContext: context)

        for matchday in 1...3 {
            let fixture = try XCTUnwrap(controller.nextPlayerGroupFixture)
            XCTAssertEqual(fixture.matchday, matchday)
            let result = FixtureResult(fixtureID: fixture.id,
                                       homeScore: 1, awayScore: 0,
                                       winnerTeamID: fixture.homeTeamID,
                                       goals: [], isSimulated: false)
            XCTAssertTrue(try TournamentResultRecorder.record(
                result, fixtureID: fixture.id, in: state))
            await controller.resumeProgression()
            XCTAssertEqual(state.results.count, matchday * 24)
        }

        XCTAssertEqual(state.bestThirdPlacedTeamIDs.count, 8)
        XCTAssertEqual(state.knockoutBracket?.fixtures.count, 31)
        XCTAssertEqual(state.phase, .knockout)
        XCTAssertEqual(state.currentRound, 1)
    }

    func testFinalizationDoesNotRegeneratePersistedBracket() async throws {
        let context = try makeContext()
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: 123)
        let controller = try WorldArenaSessionController(
            tournamentID: state.id, modelContext: context)

        for _ in 1...3 {
            let fixture = try XCTUnwrap(controller.nextPlayerGroupFixture)
            let result = FixtureResult(fixtureID: fixture.id,
                                       homeScore: 2, awayScore: 1,
                                       winnerTeamID: fixture.homeTeamID,
                                       goals: [], isSimulated: false)
            _ = try TournamentResultRecorder.record(
                result, fixtureID: fixture.id, in: state)
            await controller.resumeProgression()
        }
        let bracket = try XCTUnwrap(state.knockoutBracket)

        await controller.resumeProgression()
        XCTAssertEqual(state.knockoutBracket, bracket)
    }
}
