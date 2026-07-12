//  WorldArenaSessionController.swift

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WorldArenaSessionController {
    private(set) var state: TournamentState
    private(set) var isResolving = false
    private(set) var errorKey: String?

    let catalog: NationalTeamStore
    let definition: TournamentDefinition
    private let modelContext: ModelContext

    init(tournamentID: UUID,
         modelContext: ModelContext,
         catalog: NationalTeamStore = NationalTeamStore()) throws {
        let id = tournamentID
        let descriptor = FetchDescriptor<TournamentState>(
            predicate: #Predicate { $0.id == id })
        guard let state = try modelContext.fetch(descriptor).first,
              state.competitionID == TournamentDefinition.WorldArena.id else {
            throw WorldArenaSessionError.missingTournament
        }
        self.state = state
        self.modelContext = modelContext
        self.catalog = catalog
        self.definition = .worldArena2026(catalog: catalog)
        try validatePersistedState()
    }

    static func create(playerTeamID: String,
                       modelContext: ModelContext,
                       seed: UInt64 = .random(in: 1 ... .max),
                       catalog: NationalTeamStore = NationalTeamStore()) throws -> TournamentState {
        guard catalog.find(playerTeamID) != nil else {
            throw WorldArenaSessionError.missingTeam(playerTeamID)
        }
        let definition = TournamentDefinition.worldArena2026(catalog: catalog)
        let stage = try TournamentEngine.generateWorldGroupStage(
            definition: definition, catalog: catalog, tournamentSeed: seed)
        let state = TournamentState(
            format: .grand,
            playerTeamID: playerTeamID,
            teams: catalog.allTeams.map(\.id),
            fixtures: stage.fixtures,
            competitionID: definition.id,
            tournamentSeed: seed,
            groupAssignments: stage.groups)
        modelContext.insert(state)
        try modelContext.save()
        return state
    }

    var playerTeam: NationalTeamDefinition? { catalog.find(state.playerTeamID) }

    var playerGroup: GroupAssignment? {
        state.groupAssignments.first { $0.teamIDs.contains(state.playerTeamID) }
    }

    var currentMatchday: Int {
        let played = Set(state.results.map(\.fixtureID))
        return playerGroupFixtures.first(where: { !played.contains($0.id) })?.matchday
            ?? WorldGroupStageEngine.matchdayCount
    }

    var matchdayProgressText: String {
        "\(currentMatchday)/\(WorldGroupStageEngine.matchdayCount)"
    }

    var nextPlayerGroupFixture: Fixture? {
        guard state.phase == .groupStage else { return nil }
        let played = Set(state.results.map(\.fixtureID))
        return playerGroupFixtures.first { !played.contains($0.id) }
    }

    var isGroupStageComplete: Bool {
        let groupFixtures = state.fixtures.filter { $0.round == 0 }
        let played = Set(state.results.map(\.fixtureID))
        return groupFixtures.count == 72 && groupFixtures.allSatisfy { played.contains($0.id) }
    }

    var rankedThirdPlacedTeams: [GroupStanding] {
        WorldGroupStageEngine.rankThirdPlacedTeams(
            groups: state.groupAssignments,
            fixtures: groupFixtures,
            results: state.results,
            tournamentSeed: state.tournamentSeed)
    }

    func standings(for group: GroupAssignment) -> [GroupStanding] {
        WorldGroupStageEngine.standings(
            for: group,
            fixtures: groupFixtures,
            results: state.results,
            tournamentSeed: state.tournamentSeed)
    }

    func group(named id: String) -> GroupAssignment? {
        state.groupAssignments.first { $0.id == id }
    }

    func groupFixtures(for group: GroupAssignment) -> [Fixture] {
        let ids = Set(group.teamIDs)
        return groupFixtures.filter {
            ids.contains($0.homeTeamID) && ids.contains($0.awayTeamID)
        }.sorted { $0.matchIndex < $1.matchIndex }
    }

    func nationalTeam(_ id: String) -> NationalTeamDefinition? { catalog.find(id) }

    func matchConfig(for fixture: Fixture) throws -> MatchConfig {
        guard let home = catalog.find(fixture.homeTeamID)?.asTeam,
              let away = catalog.find(fixture.awayTeamID)?.asTeam else {
            throw WorldArenaSessionError.missingTeam(fixture.homeTeamID)
        }
        return MatchConfig(homeTeam: home, awayTeam: away,
                           seed: fixture.seed,
                           duration: PhysicsConstants.matchDuration,
                           powerUpsEnabled: false)
    }

    /// Called on dashboard appearance. If the player finished a matchday, all
    /// other fixtures from that day are resolved exactly once before advancing.
    func resumeProgression() async {
        guard state.phase == .groupStage, !isResolving else { return }
        isResolving = true
        errorKey = nil
        defer { isResolving = false }

        do {
            for matchday in 1...WorldGroupStageEngine.matchdayCount {
                guard playerFixture(on: matchday).map(hasResult) == true else { break }
                try simulateUnplayedGroupFixtures(on: matchday)
            }
            if isGroupStageComplete { try finalizeGroupStageIfNeeded() }
            try modelContext.save()
        } catch {
            errorKey = error.localizedDescriptionKey
        }
    }

    private var groupFixtures: [Fixture] { state.fixtures.filter { $0.round == 0 } }

    private var playerGroupFixtures: [Fixture] {
        groupFixtures.filter {
            $0.homeTeamID == state.playerTeamID || $0.awayTeamID == state.playerTeamID
        }.sorted { ($0.matchday ?? 0) < ($1.matchday ?? 0) }
    }

    private func playerFixture(on matchday: Int) -> Fixture? {
        playerGroupFixtures.first { $0.matchday == matchday }
    }

    private func hasResult(_ fixture: Fixture) -> Bool {
        state.results.contains { $0.fixtureID == fixture.id }
    }

    private func simulateUnplayedGroupFixtures(on matchday: Int) throws {
        let played = Set(state.results.map(\.fixtureID))
        for fixture in groupFixtures where fixture.matchday == matchday
            && !played.contains(fixture.id) {
            let config = try matchConfig(for: fixture)
            let result = TournamentEngine.simulateMatch(
                homeTeam: config.homeTeam,
                awayTeam: config.awayTeam,
                seed: fixture.seed,
                duration: config.duration)
            let stored = FixtureResult(from: result,
                                       fixtureID: fixture.id,
                                       isSimulated: true)
            _ = try TournamentResultRecorder.record(
                stored, fixtureID: fixture.id, in: state)
        }
    }

    private func finalizeGroupStageIfNeeded() throws {
        guard state.knockoutBracket == nil else {
            state.setPhase(.knockout)
            return
        }
        let bestThirds = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: state.groupAssignments,
            fixtures: groupFixtures,
            results: state.results,
            tournamentSeed: state.tournamentSeed)
        var standingsByGroup: [String: [GroupStanding]] = [:]
        var allStandings: [GroupStanding] = []
        for group in state.groupAssignments {
            let table = standings(for: group)
            standingsByGroup[group.id] = table
            allStandings.append(contentsOf: table)
        }
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: state.groupAssignments,
            standingsByGroup: standingsByGroup,
            bestThirdPlacedTeamIDs: bestThirds)
        let bracket = try WorldBracketResolver.generate(
            definition: definition,
            qualifiers: qualifiers,
            groupStandings: allStandings,
            tournamentSeed: state.tournamentSeed)
        state.setBestThirdPlacedTeamIDs(bestThirds)
        state.setKnockoutBracket(bracket)
        state.currentRound = 1
        state.setPhase(.knockout)
    }

    private func validatePersistedState() throws {
        guard state.groupAssignments.count == TournamentDefinition.WorldArena.groupCount,
              groupFixtures.count == 72,
              Set(state.teams).count == TournamentDefinition.WorldArena.teamCount else {
            throw WorldArenaSessionError.malformedState
        }
    }
}

enum WorldArenaSessionError: Error {
    case missingTournament
    case malformedState
    case missingTeam(String)
}

private extension Error {
    var localizedDescriptionKey: String {
        guard let sessionError = self as? WorldArenaSessionError else {
            return "tournament.error.progression"
        }
        switch sessionError {
        case .missingTournament: return "tournament.error.missingState"
        case .malformedState: return "tournament.error.malformedState"
        case .missingTeam: return "tournament.error.missingTeam"
        }
    }
}
