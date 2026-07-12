//  WorldArenaKnockoutComponents.swift

import SwiftUI

struct WorldArenaKnockoutResultRow: View {
    let fixture: Fixture
    let result: FixtureResult
    let catalog: NationalTeamStore
    let playerTeamID: String

    var body: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                team(fixture.homeTeamID, winner: result.winnerTeamID == fixture.homeTeamID)
                Spacer()
                Text("\(result.homeScore)–\(result.awayScore)")
                    .font(.headline.monospacedDigit())
                Spacer()
                team(fixture.awayTeamID, winner: result.winnerTeamID == fixture.awayTeamID)
            }
            if result.resolution == .extraTime {
                Text("tournament.knockout.afterExtraTime")
                    .font(.caption2).foregroundStyle(Palette.textSecondary)
            } else if let home = result.homePenaltyScore,
                      let away = result.awayPenaltyScore {
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("tournament.knockout.penaltiesScore", comment: ""),
                    home, away))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(Spacing.m)
        .background(isPlayerFixture ? Palette.accent.opacity(0.1) : Palette.bgElevated,
                    in: RoundedRectangle(cornerRadius: Radius.button))
    }

    private var isPlayerFixture: Bool {
        fixture.homeTeamID == playerTeamID || fixture.awayTeamID == playerTeamID
    }

    private func team(_ id: String, winner: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            if let team = catalog.find(id) {
                NationalFlagView(team: team, style: .compact)
                Text(team.shortCode).font(.caption.monospaced())
            }
            if winner { Image(systemName: "checkmark").font(.caption2) }
        }
        .fontWeight(winner ? .bold : .regular)
    }
}

struct WorldArenaKnockoutPendingRow: View {
    let fixture: Fixture
    let catalog: NationalTeamStore
    let playerTeamID: String

    var body: some View {
        HStack(spacing: Spacing.s) {
            slot(fixture.homeTeamID)
            Spacer()
            Text("tournament.knockout.pending")
                .font(.caption2).foregroundStyle(Palette.textTertiary)
            Spacer()
            slot(fixture.awayTeamID)
        }
        .padding(Spacing.m)
        .background(isPlayerFixture ? Palette.accent.opacity(0.1) : Palette.bgElevated,
                    in: RoundedRectangle(cornerRadius: Radius.button))
    }

    private var isPlayerFixture: Bool {
        fixture.homeTeamID == playerTeamID || fixture.awayTeamID == playerTeamID
    }

    @ViewBuilder
    private func slot(_ id: String) -> some View {
        if id == "TBD" || id.isEmpty {
            Text("tournament.knockout.pending")
                .font(.caption).foregroundStyle(Palette.textTertiary)
        } else if let team = catalog.find(id) {
            HStack(spacing: Spacing.xs) {
                NationalFlagView(team: team, style: .compact)
                Text(team.shortCode).font(.caption.monospaced())
            }
        }
    }
}
