import XCTest
import SwiftData
@testable import SimVersus

@MainActor
final class WorldArenaTrophyTests: XCTestCase {
    private func makeController(seed: UInt64) async throws
        -> (WorldArenaSessionController, ModelContext) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TournamentState.self, Trophy.self,
                                           configurations: configuration)
        let context = ModelContext(container)
        let state = try WorldArenaSessionController.create(
            playerTeamID: "nation-tr", modelContext: context, seed: seed)
        let controller = try WorldArenaSessionController(
            tournamentID: state.id, modelContext: context)
        for _ in 1...3 {
            let fixture = try XCTUnwrap(controller.nextPlayerGroupFixture)
            let home = fixture.homeTeamID == state.playerTeamID
            let result = FixtureResult(fixtureID: fixture.id,
                                       homeScore: home ? 2 : 0,
                                       awayScore: home ? 0 : 2,
                                       winnerTeamID: state.playerTeamID,
                                       goals: [], isSimulated: false)
            _ = try TournamentResultRecorder.record(
                result, fixtureID: fixture.id, in: state)
            await controller.resumeProgression()
        }
        return (controller, context)
    }

    func testPlayerChampionInsertsExactlyOneWorldArenaTrophy() async throws {
        let (controller, context) = try await makeController(seed: 21)
        while controller.state.phase == .knockout {
            await controller.resumeKnockoutProgression()
            let fixture = try XCTUnwrap(controller.nextPlayerKnockoutFixture)
            let playerHome = fixture.homeTeamID == controller.state.playerTeamID
            let win = MatchResult(homeTeamID: fixture.homeTeamID,
                                  awayTeamID: fixture.awayTeamID,
                                  homeScore: playerHome ? 2 : 0,
                                  awayScore: playerHome ? 0 : 2,
                                  goals: [])
            _ = try controller.recordPlayerKnockoutResult(win, fixtureID: fixture.id)
        }

        XCTAssertEqual(controller.championTeamID, controller.state.playerTeamID)
        XCTAssertTrue(try controller.awardPlayerTrophyIfNeeded())
        XCTAssertFalse(try controller.awardPlayerTrophyIfNeeded())
        let trophies = try context.fetch(FetchDescriptor<Trophy>())
        XCTAssertEqual(trophies.count, 1)
        XCTAssertEqual(trophies.first?.competitionID, TournamentDefinition.WorldArena.id)
        XCTAssertEqual(trophies.first?.sourceTournamentID, controller.state.id)
        XCTAssertEqual(trophies.first?.nationalISOCode, "TR")
    }

    func testAIChampionDoesNotInsertPlayerTrophy() async throws {
        let (controller, context) = try await makeController(seed: 22)
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

        XCTAssertNotEqual(controller.championTeamID, controller.state.playerTeamID)
        XCTAssertFalse(try controller.awardPlayerTrophyIfNeeded())
        XCTAssertTrue(try context.fetch(FetchDescriptor<Trophy>()).isEmpty)
    }

    func testLegacyTrophyMetadataRemainsOptional() {
        let trophy = Trophy(format: .mini, teamID: "legacy",
                            teamName: "Legacy", teamShort: "LEG",
                            primaryHex: "#111111", secondaryHex: "#FFFFFF",
                            badgeShape: .star, isCustomTeam: false)
        XCTAssertNil(trophy.competitionID)
        XCTAssertNil(trophy.sourceTournamentID)
        XCTAssertEqual(trophy.format, .mini)
    }
}
