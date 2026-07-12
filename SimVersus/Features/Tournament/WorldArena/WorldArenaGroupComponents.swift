//  WorldArenaGroupComponents.swift

import SwiftUI

struct WorldArenaGroupHeader: View {
    let controller: WorldArenaSessionController

    var body: some View {
        ArenaSurface {
            HStack(spacing: Spacing.m) {
                if let team = controller.playerTeam {
                    NationalFlagView(team: team)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(LocalizedStringKey(team.nameKey)).font(.headline)
                        Text("tournament.group.playerNation")
                            .font(.caption).foregroundStyle(Palette.textSecondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text("tournament.group.matchday").font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(controller.matchdayProgressText)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(Palette.accentWarning)
                }
            }
        }
    }
}

struct WorldArenaGroupTable: View {
    let group: GroupAssignment
    let standings: [GroupStanding]
    let playerTeamID: String
    let catalog: NationalTeamStore

    var body: some View {
        ArenaSurface(padding: 0) {
            VStack(spacing: 0) {
                header
                ForEach(Array(standings.enumerated()), id: \.element.teamID) { index, item in
                    row(index: index, standing: item)
                    if index < standings.count - 1 {
                        Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("tournament.group.name", comment: ""), group.id))
                .font(.sectionLabel)
            Spacer()
            Text("tournament.group.columns")
                .font(.caption.monospaced())
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(Spacing.m)
        .background(Palette.bgElevatedStrong)
    }

    private func row(index: Int, standing: GroupStanding) -> some View {
        let team = catalog.find(standing.teamID)
        return HStack(spacing: Spacing.s) {
            Text("\(index + 1)").font(.caption.monospacedDigit()).frame(width: 20)
            if let team { NationalFlagView(team: team, style: .compact) }
            Text(team.map { LocalizedStringKey($0.nameKey) } ?? LocalizedStringKey(standing.teamID))
                .font(.caption).lineLimit(1)
            Spacer()
            Text("\(standing.played)  \(standing.goalDifference)  \(standing.points)")
                .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: Layout.minTouchTarget)
        .background(standing.teamID == playerTeamID
                    ? Palette.accent.opacity(0.12) : qualificationTint(index))
        .accessibilityLabel(accessibilityText(index: index, standing: standing, team: team))
    }

    private func qualificationTint(_ index: Int) -> Color {
        if index < 2 { return Palette.accent.opacity(0.05) }
        if index == 2 { return Palette.accentWarning.opacity(0.05) }
        return .clear
    }

    private func accessibilityText(index: Int, standing: GroupStanding,
                                   team: NationalTeamDefinition?) -> String {
        let name = team.map { NSLocalizedString($0.nameKey, comment: "") } ?? standing.teamID
        return "\(index + 1), \(name), \(standing.played), \(standing.goalDifference), \(standing.points)"
    }
}

struct WorldArenaGroupFixtures: View {
    let fixtures: [Fixture]
    let results: [FixtureResult]
    let catalog: NationalTeamStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ArenaSectionHeader(title: "tournament.group.fixtures")
            ForEach(fixtures) { fixture in
                let result = results.first { $0.fixtureID == fixture.id }
                HStack {
                    Text(catalog.find(fixture.homeTeamID)?.shortCode ?? "???")
                    Spacer()
                    Text(result.map { "\($0.homeScore)–\($0.awayScore)" } ?? "–")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(result == nil ? Palette.textTertiary : Palette.textPrimary)
                    Spacer()
                    Text(catalog.find(fixture.awayTeamID)?.shortCode ?? "???")
                }
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: Layout.minTouchTarget)
                .background(Palette.bgElevated,
                            in: RoundedRectangle(cornerRadius: Radius.badge))
            }
        }
    }
}

struct WorldArenaFixtureTeams: View {
    let fixture: Fixture
    let catalog: NationalTeamStore

    var body: some View {
        HStack(spacing: Spacing.l) {
            team(fixture.homeTeamID)
            Text("common.versus").font(.caption).foregroundStyle(Palette.textSecondary)
            team(fixture.awayTeamID)
        }
        .frame(maxWidth: .infinity)
    }

    private func team(_ id: String) -> some View {
        VStack(spacing: Spacing.s) {
            if let team = catalog.find(id) {
                NationalFlagView(team: team)
                Text(LocalizedStringKey(team.nameKey)).font(.caption).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
