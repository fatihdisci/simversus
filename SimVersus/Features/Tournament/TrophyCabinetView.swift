//  TrophyCabinetView.swift

import SwiftUI
import SwiftData

struct TrophyCabinetView: View {
    @Query(sort: \Trophy.wonAt, order: .reverse) private var trophies: [Trophy]
    private let nationalCatalog = NationalTeamStore()

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            if trophies.isEmpty { emptyState }
            else {
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        summaryBanner
                        trophyGrid
                    }
                    .padding(Spacing.l)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("trophy.cabinet.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("trophy.cabinet.empty", systemImage: "trophy.fill")
        } description: {
            Text("trophy.cabinet.emptyHint")
        }
        .foregroundStyle(Palette.textSecondary)
    }

    private var summaryBanner: some View {
        let worldCount = trophies.filter {
            $0.competitionID == TournamentDefinition.WorldArena.id
        }.count
        return ArenaSurface {
            HStack(spacing: Spacing.l) {
                TrophyStat(value: trophies.count, key: "trophy.cabinet.total")
                if worldCount > 0 {
                    TrophyStat(value: worldCount, key: "tournament.worldArena.name")
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.title2).foregroundStyle(Palette.accentWarning)
            }
        }
    }

    private var trophyGrid: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 132))], spacing: Spacing.m) {
            ForEach(trophies) { trophy in
                TrophyCard(trophy: trophy,
                           nationalTeam: nationalCatalog.find(trophy.teamID))
            }
        }
    }
}

private struct TrophyCard: View {
    let trophy: Trophy
    let nationalTeam: NationalTeamDefinition?

    private var isWorldArena: Bool {
        trophy.competitionID == TournamentDefinition.WorldArena.id
    }

    var body: some View {
        VStack(spacing: Spacing.s) {
            ZStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(isWorldArena ? Palette.accentWarning : formatColor)
                identityMark.offset(y: 5)
            }
            Text(trophy.teamName).font(.caption).lineLimit(2)
                .multilineTextAlignment(.center)
            competitionLabel
                .font(.caption2).foregroundStyle(Palette.textSecondary)
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(trophy.wonAt.formatted(date: .numeric, time: .omitted))
                .font(.caption2.monospacedDigit()).foregroundStyle(Palette.textTertiary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(Color(hex: trophy.primaryHex).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Radius.card)
            .stroke(isWorldArena ? Palette.accentWarning.opacity(0.6)
                                 : Palette.borderSubtle))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var identityMark: some View {
        if isWorldArena, let nationalTeam {
            NationalFlagView(team: nationalTeam, style: .compact)
        } else {
            TeamBadgeView(team: placeholderTeam, size: 24, showsCode: false)
        }
    }

    @ViewBuilder
    private var competitionLabel: some View {
        if isWorldArena { Text("tournament.worldArena.name") }
        else { Text(verbatim: trophy.format.displayName) }
    }

    private var formatColor: Color {
        switch trophy.format {
        case .mini: return .gray
        case .classic: return .orange
        case .groupKO: return .blue
        case .grand: return .yellow
        }
    }

    private var placeholderTeam: Team {
        Team(id: trophy.teamID, nameKey: trophy.teamName,
             nameTR: trophy.teamName, nameEN: trophy.teamName,
             short: trophy.teamShort, primary: trophy.primaryHex,
             secondary: trophy.secondaryHex, badgeShape: trophy.badgeShape,
             tier: 0, baseStrength: 75, stats: .balanced, pattern: .solid)
    }
}

private struct TrophyStat: View {
    let value: Int
    let key: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(value)").font(.headline.monospacedDigit())
            Text(key).font(.caption2).foregroundStyle(Palette.textSecondary)
        }
    }
}

#Preview {
    NavigationStack { TrophyCabinetView() }
        .modelContainer(for: [Trophy.self], inMemory: true)
        .preferredColorScheme(.dark)
}
