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

    var bracket: WorldKnockoutBracket? { state.knockoutBracket }

    var currentKnockoutRound: Int {
        guard let bracket else { return 1 }
        return min(max(state.currentRound, 1),
                   WorldBracketResolver.maxRound(in: bracket))
    }

    var nextPlayerKnockoutFixture: Fixture? {
        guard state.phase == .knockout, !isPlayerEliminated,
              let bracket else { return nil }
        let played = Set(state.results.map(\.fixtureID))
        return WorldBracketResolver.fixtures(in: bracket, round: currentKnockoutRound)
            .first {
                !played.contains($0.id)
                    && ($0.homeTeamID == state.playerTeamID
                        || $0.awayTeamID == state.playerTeamID)
            }
    }

    var isPlayerEliminated: Bool {
        guard let bracket else { return false }
        let fixtureMap = Dictionary(uniqueKeysWithValues: bracket.fixtures.map { ($0.id, $0) })
        return state.results.contains { result in
            guard let fixture = fixtureMap[result.fixtureID],
                  fixture.homeTeamID == state.playerTeamID
                    || fixture.awayTeamID == state.playerTeamID else { return false }
            return result.winnerTeamID != nil && result.winnerTeamID != state.playerTeamID
        }
    }

    var elimination: (fixture: Fixture, result: FixtureResult)? {
        guard let bracket else { return nil }
        for result in state.results.reversed() {
            guard result.winnerTeamID != state.playerTeamID,
                  let fixture = bracket.fixtures.first(where: { $0.id == result.fixtureID }),
                  fixture.homeTeamID == state.playerTeamID
                    || fixture.awayTeamID == state.playerTeamID else { continue }
            return (fixture, result)
        }
        return nil
    }

    var championTeamID: String? {
        guard let bracket else { return nil }
        return WorldBracketResolver.championTeamID(in: bracket, results: state.results)
    }

    @discardableResult
    func awardPlayerTrophyIfNeeded() throws -> Bool {
        guard state.phase == .finished,
              championTeamID == state.playerTeamID,
              let team = catalog.find(state.playerTeamID) else { return false }
        let tournamentID = state.id
        let descriptor = FetchDescriptor<Trophy>(
            predicate: #Predicate { $0.sourceTournamentID == tournamentID })
        guard try modelContext.fetch(descriptor).isEmpty else { return false }
        let trophy = Trophy(
            format: .grand,
            teamID: team.id,
            teamName: NSLocalizedString(team.nameKey, comment: ""),
            teamShort: team.shortCode,
            primaryHex: team.primary,
            secondaryHex: team.secondary,
            badgeShape: team.badgeShape,
            isCustomTeam: false,
            competitionID: TournamentDefinition.WorldArena.id,
            sourceTournamentID: tournamentID,
            nationalISOCode: team.isoCode,
            nationalFlagAsset: team.flagAsset)
        modelContext.insert(trophy)
        try modelContext.save()
        return true
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

    func resumeKnockoutProgression() async {
        guard state.phase == .knockout, !isResolving, !isPlayerEliminated else { return }
        isResolving = true
        errorKey = nil
        defer { isResolving = false }
        do {
            try advanceCompletedKnockoutRoundIfNeeded()
            guard state.phase == .knockout else { return }
            try simulateNonPlayerFixtures(in: currentKnockoutRound)
            try advanceCompletedKnockoutRoundIfNeeded()
            try modelContext.save()
        } catch {
            errorKey = error.localizedDescriptionKey
        }
    }

    @discardableResult
    func recordPlayerKnockoutResult(_ regulation: MatchResult,
                                    fixtureID: String) throws -> FixtureResult {
        guard var bracket = state.knockoutBracket,
              let fixture = bracket.fixtures.first(where: { $0.id == fixtureID }),
              fixture.homeTeamID == state.playerTeamID
                || fixture.awayTeamID == state.playerTeamID,
              let home = catalog.find(fixture.homeTeamID)?.asTeam,
              let away = catalog.find(fixture.awayTeamID)?.asTeam else {
            throw WorldArenaSessionError.malformedState
        }
        var stored = KnockoutMatchResolver.resolve(
            fixture: fixture,
            homeTeam: home,
            awayTeam: away,
            regulationResult: regulation,
            tournamentSeed: state.tournamentSeed).fixtureResult
        stored.isSimulated = false
        try WorldBracketValidator.validate(stored, against: bracket,
                                           existingResults: state.results)
        _ = try TournamentResultRecorder.record(stored,
                                                fixtureID: fixtureID,
                                                in: state)
        bracket = materialized(bracket)
        state.setKnockoutBracket(bracket)
        try advanceCompletedKnockoutRoundIfNeeded()
        try modelContext.save()
        return stored
    }

    func finishTournamentAfterElimination() async {
        guard isPlayerEliminated, state.phase == .knockout, !isResolving else { return }
        isResolving = true
        errorKey = nil
        defer { isResolving = false }
        do {
            while state.phase == .knockout {
                try simulateAllFixtures(in: currentKnockoutRound)
                try advanceCompletedKnockoutRoundIfNeeded()
            }
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

    private func simulateNonPlayerFixtures(in round: Int) throws {
        guard let bracket else { throw WorldArenaSessionError.malformedState }
        let played = Set(state.results.map(\.fixtureID))
        for fixture in WorldBracketResolver.fixtures(in: bracket, round: round)
            where !played.contains(fixture.id)
                && fixture.homeTeamID != state.playerTeamID
                && fixture.awayTeamID != state.playerTeamID {
            try simulateKnockoutFixture(fixture, bracket: bracket)
        }
    }

    private func simulateAllFixtures(in round: Int) throws {
        guard let bracket else { throw WorldArenaSessionError.malformedState }
        let played = Set(state.results.map(\.fixtureID))
        for fixture in WorldBracketResolver.fixtures(in: bracket, round: round)
            where !played.contains(fixture.id) {
            try simulateKnockoutFixture(fixture, bracket: bracket)
        }
    }

    private func simulateKnockoutFixture(_ fixture: Fixture,
                                         bracket: WorldKnockoutBracket) throws {
        let config = try matchConfig(for: fixture)
        let regulation = TournamentEngine.simulateMatch(
            homeTeam: config.homeTeam,
            awayTeam: config.awayTeam,
            seed: fixture.seed,
            duration: config.duration)
        let outcome = KnockoutMatchResolver.resolve(
            fixture: fixture,
            homeTeam: config.homeTeam,
            awayTeam: config.awayTeam,
            regulationResult: regulation,
            tournamentSeed: state.tournamentSeed)
        try WorldBracketValidator.validate(outcome.fixtureResult,
                                           against: bracket,
                                           existingResults: state.results)
        _ = try TournamentResultRecorder.record(
            outcome.fixtureResult, fixtureID: fixture.id, in: state)
    }

    private func advanceCompletedKnockoutRoundIfNeeded() throws {
        guard var bracket = state.knockoutBracket else {
            throw WorldArenaSessionError.malformedState
        }
        let round = currentKnockoutRound
        guard WorldBracketResolver.isRoundComplete(
            round, bracket: bracket, results: state.results) else { return }
        bracket = materialized(bracket)
        state.setKnockoutBracket(bracket)
        if round == WorldBracketResolver.maxRound(in: bracket) {
            state.currentRound = round
            state.setPhase(.finished)
            state.completedAt = .now
        } else {
            state.currentRound = round + 1
        }
    }

    private func materialized(_ bracket: WorldKnockoutBracket) -> WorldKnockoutBracket {
        let context = TournamentEngine.SlotResolutionContext(
            groupRankings: state.groupAssignments.map { standings(for: $0).map(\.teamID) },
            bestThirdPlacedTeamIDs: state.bestThirdPlacedTeamIDs,
            fixtureResults: Dictionary(uniqueKeysWithValues:
                state.results.map { ($0.fixtureID, $0) }))
        let fixtures = WorldBracketResolver.materialize(bracket.fixtures, context: context)
        return WorldKnockoutBracket(
            fixtures: fixtures,
            createdFromTournamentSeed: bracket.createdFromTournamentSeed,
            qualifierTeamIDs: bracket.qualifierTeamIDs)
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
