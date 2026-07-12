//  TournamentBracketView.swift
//  Features/Tournament
//
//  The heart of the tournament UI. Shows group standings (if applicable) or
//  the knockout bracket. Auto-resolves all non-player matches headlessly and
//  surfaces the player's next match. Tapping a player match goes to MatchView.

import SwiftUI
import SwiftData

struct TournamentBracketView: View {
    let tournamentID: UUID
    let onPlayMatch: (MatchConfig) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomTeam.name) private var customTeams: [CustomTeam]

    private let allTeams = TeamStore().allTeams
    @State private var state: TournamentState?
    @State private var isSimulating = false

    var body: some View {
        Group {
            if let state {
                content(for: state)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(state?.format.displayName ?? "Turnuva")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { _ = loadState() }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(for state: TournamentState) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                playerTeamBanner(state)
                phaseBadge(state)

                if state.format.hasGroupStage && !isGroupStageComplete(state) {
                    groupStandingsSection(state)
                }

                currentRoundSection(state)
            }
            .padding()
        }
        .task {
            if let current = loadState() {
                await advanceIfRoundComplete(current)
                if let updated = loadState() {
                    await autoResolveNonPlayerMatches(updated)
                }
            }
        }
    }

    // MARK: - Player team banner

    private func playerTeamBanner(_ state: TournamentState) -> some View {
        let team = resolveTeam(state.playerTeamID)
        return HStack(spacing: 12) {
            TeamBadgeView(team: team, size: 36, showsCode: false)
            VStack(alignment: .leading, spacing: 2) {
                Text("Senin Takımın")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(team.nameTR)
                    .font(.headline)
            }
            Spacer()
            if state.completedAt != nil {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Phase badge

    private func phaseBadge(_ state: TournamentState) -> some View {
        HStack {
            Image(systemName: state.completedAt != nil ? "flag.checkered" : "play.circle.fill")
            Text(phaseLabel(state))
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private func phaseLabel(_ state: TournamentState) -> String {
        if state.completedAt != nil { return "Turnuva Tamamlandı" }
        switch state.phase {
        case .pending:    return "Hazırlanıyor..."
        case .groupStage: return "Grup Aşaması"
        case .knockout:   return "Eleme Aşaması"
        case .finished:   return "Tamamlandı"
        }
    }

    // MARK: - Group standings

    private func isGroupStageComplete(_ state: TournamentState) -> Bool {
        let groupFixtures = state.fixtures.filter { $0.round == 0 }
        let playedIDs = Set(state.results.map(\.fixtureID))
        return groupFixtures.allSatisfy { playedIDs.contains($0.id) }
    }

    @ViewBuilder
    private func groupStandingsSection(_ state: TournamentState) -> some View {
        ForEach(0..<state.format.groupCount, id: \.self) { groupIndex in
            VStack(alignment: .leading, spacing: 8) {
                Text("Grup \(["A","B","C","D"][groupIndex])")
                    .font(.sectionLabel)
                    .foregroundStyle(.secondary)

                let groupFixtures = state.fixtures.filter { $0.round == 0 && $0.groupIndex == groupIndex }
                let groupTeamIDs = groupTeams(from: groupFixtures)
                let standings = TournamentEngine.groupStandings(
                    teams: groupTeamIDs,
                    fixtures: groupFixtures,
                    results: state.results)

                ForEach(Array(standings.enumerated()), id: \.element.teamID) { idx, standing in
                    standingRow(idx: idx, standing: standing,
                               isPlayer: standing.teamID == state.playerTeamID)
                }
            }
        }
    }

    private func groupTeams(from fixtures: [Fixture]) -> [String] {
        var ids = Set<String>()
        for f in fixtures { ids.insert(f.homeTeamID); ids.insert(f.awayTeamID) }
        return Array(ids)
    }

    private func standingRow(idx: Int, standing: GroupStanding, isPlayer: Bool) -> some View {
        let team = resolveTeam(standing.teamID)
        return HStack(spacing: 8) {
            Text("\(idx + 1)")
                .font(.caption)
                .foregroundStyle(idx < 2 ? .yellow : .secondary)
                .frame(width: 18)
            TeamBadgeView(team: team, size: 24, showsCode: false)
            Text(team.nameTR)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text("\(standing.played)O \(standing.wins)G \(standing.draws)B \(standing.losses)M  \(standing.points)P")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isPlayer ? team.primaryColor.opacity(0.15) : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Current round fixtures

    private func currentRoundSection(_ state: TournamentState) -> some View {
        let currentRound = state.currentRound
        let fixtures = TournamentEngine.fixturesForRound(state.fixtures, round: currentRound)
        let playedIDs = Set(state.results.map(\.fixtureID))

        return VStack(alignment: .leading, spacing: 8) {
            Text(roundTitle(state, round: currentRound))
                .font(.sectionLabel)
                .foregroundStyle(.secondary)

            ForEach(fixtures) { fixture in
                fixtureRow(state: state, fixture: fixture, isPlayed: playedIDs.contains(fixture.id))
            }
        }
    }

    private func roundTitle(_ state: TournamentState, round: Int) -> String {
        if state.completedAt != nil { return "Sonuçlar" }
        let maxR = TournamentEngine.maxRound(in: state.fixtures)
        switch round {
        case 0: return "Grup Maçları"
        case maxR: return "Final"
        case maxR - 1: return "Yarı Final"
        default: return "Çeyrek Final"
        }
    }

    @ViewBuilder
    private func fixtureRow(state: TournamentState, fixture: Fixture, isPlayed: Bool) -> some View {
        let isPlayerMatch = fixture.homeTeamID == state.playerTeamID
            || fixture.awayTeamID == state.playerTeamID
        let isTBD = fixture.homeTeamID == "TBD" || fixture.awayTeamID == "TBD"

        if isPlayed, let result = state.results.first(where: { $0.fixtureID == fixture.id }) {
            playedFixtureRow(fixture: fixture, result: result, isPlayer: isPlayerMatch)
        } else if isTBD {
            HStack {
                Text("??? vs ???")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        } else if isPlayerMatch {
            Button {
                let config = buildMatchConfig(for: fixture)
                onPlayMatch(config)
            } label: {
                HStack {
                    teamChip(fixture.homeTeamID)
                    Text("vs").font(.caption).foregroundStyle(.secondary)
                    teamChip(fixture.awayTeamID)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
                .padding(10)
                .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                teamChip(fixture.homeTeamID)
                Text("vs").font(.caption).foregroundStyle(.tertiary)
                teamChip(fixture.awayTeamID)
                Spacer()
                if isSimulating {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Text("Bekliyor...").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(10)
            .opacity(0.6)
        }
    }

    private func playedFixtureRow(fixture: Fixture, result: FixtureResult, isPlayer: Bool) -> some View {
        HStack {
            teamChip(fixture.homeTeamID, highlight: result.homeScore > result.awayScore)
            Text("\(result.homeScore) - \(result.awayScore)")
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(isPlayer ? Palette.textPrimary : .secondary)
            teamChip(fixture.awayTeamID, highlight: result.awayScore > result.homeScore)
            Spacer()
            if result.isSimulated {
                Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
    }

    private func teamChip(_ teamID: String, highlight: Bool = false) -> some View {
        let team = resolveTeam(teamID)
        return HStack(spacing: 4) {
            TeamBadgeView(team: team, size: 20, showsCode: false)
            Text(team.short)
                .font(.caption)
                .fontWeight(highlight ? .bold : .regular)
        }
    }

    // MARK: - Auto-resolve

    private func autoResolveNonPlayerMatches(_ state: TournamentState) async {
        guard state.completedAt == nil else { return }
        isSimulating = true
        defer { isSimulating = false }

        let playedIDs = Set(state.results.map(\.fixtureID))
        let currentRoundFixtures = TournamentEngine.fixturesForRound(
            state.fixtures, round: state.currentRound)

        for fixture in currentRoundFixtures {
            guard !playedIDs.contains(fixture.id) else { continue }
            let isPlayerMatch = fixture.homeTeamID == state.playerTeamID
                || fixture.awayTeamID == state.playerTeamID
            if isPlayerMatch { continue }
            guard fixture.homeTeamID != "TBD" && fixture.awayTeamID != "TBD" else { continue }
            guard let homeTeam = findTeam(fixture.homeTeamID),
                  let awayTeam = findTeam(fixture.awayTeamID) else { continue }

            let result = TournamentEngine.simulateMatch(
                homeTeam: homeTeam, awayTeam: awayTeam, seed: fixture.seed)
            let fixtureResult = FixtureResult(from: result,
                                              fixtureID: fixture.id,
                                              isSimulated: true)
            await MainActor.run {
                state.appendResult(fixtureResult)
                try? modelContext.save()
            }
            await advanceIfRoundComplete(state)
        }
    }

    private func advanceIfRoundComplete(_ state: TournamentState) async {
        let currentFixtures = TournamentEngine.fixturesForRound(
            state.fixtures, round: state.currentRound)
        let playedIDs = Set(state.results.map(\.fixtureID))
        let allPlayed = currentFixtures.allSatisfy { playedIDs.contains($0.id) }
        guard allPlayed else { return }

        if state.currentRound == TournamentEngine.maxRound(in: state.fixtures) {
            state.completedAt = .now
            state.setPhase(.finished)
            try? modelContext.save()
            return
        }

        if state.format.hasGroupStage && state.currentRound == 0 {
            await advanceFromGroupStage(state)
        } else {
            var fixtures = state.fixtures
            let winners = determineWinners(from: state, round: state.currentRound)
            TournamentEngine.advanceKnockout(fixtures: &fixtures,
                                             results: state.results,
                                             newWinners: winners)
            await MainActor.run {
                state.fixturesData = (try? JSONEncoder().encode(fixtures)) ?? Data()
                state.advanceRound()
                state.setPhase(.knockout)
                try? modelContext.save()
            }
        }
    }

    private func advanceFromGroupStage(_ state: TournamentState) async {
        var allAdvancers: [String] = []
        for g in 0..<state.format.groupCount {
            let gf = state.fixtures.filter { $0.round == 0 && $0.groupIndex == g }
            let gIDs = groupTeams(from: gf)
            let standings = TournamentEngine.groupStandings(
                teams: gIDs, fixtures: gf, results: state.results)
            allAdvancers.append(contentsOf: TournamentEngine.topTeams(
                from: standings, count: state.format.advancePerGroup))
        }
        var fixtures = state.fixtures
        TournamentEngine.advanceKnockout(fixtures: &fixtures,
                                         results: state.results,
                                         newWinners: allAdvancers)
        await MainActor.run {
            state.fixturesData = (try? JSONEncoder().encode(fixtures)) ?? Data()
            state.advanceRound()
            state.setPhase(.knockout)
            try? modelContext.save()
        }
    }

    private func determineWinners(from state: TournamentState, round: Int) -> [String] {
        let roundFixtures = TournamentEngine.fixturesForRound(state.fixtures, round: round)
        let resultMap = Dictionary(uniqueKeysWithValues: state.results.map { ($0.fixtureID, $0) })
        return roundFixtures.compactMap { f in
            guard let r = resultMap[f.id] else { return nil }
            if let w = r.winnerTeamID { return w }
            return r.homeScore >= r.awayScore ? f.homeTeamID : f.awayTeamID
        }
    }

    // MARK: - Helpers

    private func loadState() -> TournamentState? {
        let id = tournamentID
        let descriptor = FetchDescriptor<TournamentState>(
            predicate: #Predicate { $0.id == id })
        let fetched = try? modelContext.fetch(descriptor).first
        state = fetched
        return fetched
    }

    private func buildMatchConfig(for fixture: Fixture) -> MatchConfig {
        let home = findTeam(fixture.homeTeamID)!
        let away = findTeam(fixture.awayTeamID)!
        return MatchConfig(homeTeam: home, awayTeam: away,
                           seed: fixture.seed,
                           powerUpsEnabled: false)
    }

    private func findTeam(_ teamID: String) -> Team? {
        if let preset = allTeams.first(where: { $0.id == teamID }) { return preset }
        if let custom = customTeams.first(where: { $0.id.uuidString == teamID }) { return custom.asTeam }
        return nil
    }

    private func resolveTeam(_ teamID: String) -> Team {
        findTeam(teamID) ?? Team(id: teamID, nameKey: teamID, nameTR: teamID, nameEN: teamID,
                                  short: "???", primary: "#888888", secondary: "#444444",
                                  badgeShape: .star, tier: 0, baseStrength: 75,
                                  stats: .balanced, pattern: .solid)
    }
}

#Preview {
    NavigationStack {
        TournamentBracketView(tournamentID: UUID(), onPlayMatch: { _ in })
    }
    .modelContainer(for: [CustomTeam.self, MatchRecord.self, TournamentState.self],
                    inMemory: true)
    .preferredColorScheme(.dark)
}
