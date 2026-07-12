#if DEBUG
import SwiftUI

private enum WorldArenaPreviewScenario {
    case group, groupComplete, bestThirds, r32, semiFinal, final
    case eliminated, playerChampion, aiChampion
}

private struct WorldArenaScenarioPreview: View {
    let scenario: WorldArenaPreviewScenario
    private let catalog = NationalTeamStore()

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            ScrollView {
                VStack(spacing: Spacing.l) {
                    switch scenario {
                    case .group: groupPreview(complete: false)
                    case .groupComplete: groupPreview(complete: true)
                    case .bestThirds: bestThirdPreview
                    case .r32: knockoutPreview(round: 1, count: 6)
                    case .semiFinal: knockoutPreview(round: 4, count: 2)
                    case .final: knockoutPreview(round: 5, count: 1)
                    case .eliminated: eliminatedPreview
                    case .playerChampion: championPreview(playerWon: true)
                    case .aiChampion: championPreview(playerWon: false)
                    }
                }
                .padding(Spacing.l)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func groupPreview(complete: Bool) -> some View {
        let teams = Array(catalog.allTeams.prefix(4))
        let group = GroupAssignment(id: "A", teamIDs: teams.map(\.id))
        let table = teams.enumerated().map { index, team in
            GroupStanding(teamID: team.id, played: complete ? 3 : 0,
                          wins: complete ? max(0, 3 - index) : 0,
                          draws: 0, losses: complete ? index : 0,
                          goalsFor: complete ? 6 - index : 0,
                          goalsAgainst: complete ? index : 0,
                          points: complete ? max(0, 9 - index * 3) : 0,
                          groupID: "A")
        }
        return VStack(spacing: Spacing.m) {
            ArenaSectionHeader(title: complete
                               ? "tournament.group.complete"
                               : "tournament.group.nextMatch")
            WorldArenaGroupTable(group: group, standings: table,
                                 playerTeamID: teams[0].id, catalog: catalog)
        }
    }

    private var bestThirdPreview: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ArenaSectionHeader(title: "tournament.bestThird.title")
            ForEach(Array(catalog.allTeams.prefix(12).enumerated()), id: \.element.id) { index, team in
                HStack {
                    Text("\(index + 1)").font(.caption.monospacedDigit()).frame(width: 24)
                    NationalFlagView(team: team, style: .compact)
                    Text(LocalizedStringKey(team.nameKey)).font(.caption)
                    Spacer()
                    Text(LocalizedStringKey(index < 8
                                            ? "tournament.bestThird.qualified"
                                            : "tournament.bestThird.eliminated"))
                        .font(.caption2)
                        .foregroundStyle(index < 8 ? Palette.accent : Palette.textTertiary)
                }
                .padding(Spacing.s)
                .background(Palette.bgElevated,
                            in: RoundedRectangle(cornerRadius: Radius.badge))
            }
        }
    }

    private func knockoutPreview(round: Int, count: Int) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ArenaSectionHeader(title: LocalizedStringKey(roundKey(round)))
            ForEach(0..<count, id: \.self) { index in
                let home = catalog.allTeams[index * 2]
                let away = catalog.allTeams[index * 2 + 1]
                let fixture = Fixture(id: "preview-\(index)",
                                      homeTeamID: home.id, awayTeamID: away.id,
                                      round: round, groupIndex: nil,
                                      matchIndex: index, seed: UInt64(index + 1))
                WorldArenaKnockoutPendingRow(fixture: fixture,
                                             catalog: catalog,
                                             playerTeamID: home.id)
            }
        }
    }

    private var eliminatedPreview: some View {
        let home = catalog.allTeams[0], away = catalog.allTeams[1]
        let fixture = Fixture(id: "preview-loss", homeTeamID: home.id,
                              awayTeamID: away.id, round: 3,
                              groupIndex: nil, matchIndex: 0, seed: 1)
        let result = FixtureResult(fixtureID: fixture.id, homeScore: 0,
                                   awayScore: 2, winnerTeamID: away.id,
                                   goals: [], isSimulated: false)
        return ArenaSurface {
            VStack(spacing: Spacing.m) {
                Label("tournament.knockout.eliminated", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Palette.danger)
                WorldArenaKnockoutResultRow(fixture: fixture, result: result,
                                            catalog: catalog, playerTeamID: home.id)
            }
        }
    }

    private func championPreview(playerWon: Bool) -> some View {
        let champion = catalog.allTeams[playerWon ? 0 : 3]
        return VStack(spacing: Spacing.l) {
            Image(systemName: "sparkles")
                .font(.system(size: 72)).foregroundStyle(Palette.accentWarning)
            NationalFlagView(team: champion).scaleEffect(1.8)
            Text(LocalizedStringKey(champion.nameKey)).font(.screenTitle)
            Text(LocalizedStringKey(playerWon
                                    ? "tournament.champion.playerWon"
                                    : "tournament.champion.aiWon"))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.top, Spacing.xxl)
    }

    private func roundKey(_ round: Int) -> String {
        switch round {
        case 1: return TournamentRoundKey.r32
        case 4: return TournamentRoundKey.semiFinal
        default: return TournamentRoundKey.final
        }
    }
}

#Preview("Group Stage — Matchday 1") { WorldArenaScenarioPreview(scenario: .group) }
#Preview("Group Stage — Complete") { WorldArenaScenarioPreview(scenario: .groupComplete) }
#Preview("Best Thirds") { WorldArenaScenarioPreview(scenario: .bestThirds) }
#Preview("Round of 32") { WorldArenaScenarioPreview(scenario: .r32) }
#Preview("Semi-final") { WorldArenaScenarioPreview(scenario: .semiFinal) }
#Preview("Final") { WorldArenaScenarioPreview(scenario: .final) }
#Preview("Eliminated Player") { WorldArenaScenarioPreview(scenario: .eliminated) }
#Preview("Player Champion") { WorldArenaScenarioPreview(scenario: .playerChampion) }
#Preview("AI Champion") { WorldArenaScenarioPreview(scenario: .aiChampion) }
#Preview("Compact Height", traits: .fixedLayout(width: 320, height: 568)) {
    WorldArenaScenarioPreview(scenario: .group)
}
#Preview("Large Dynamic Type", traits: .sizeThatFitsLayout) {
    WorldArenaScenarioPreview(scenario: .bestThirds)
        .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
