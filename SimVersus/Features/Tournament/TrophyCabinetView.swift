//  TrophyCabinetView.swift
//  Features/Tournament
//
//  Displays every tournament trophy the player has won. Trophies are grouped
//  by format and sorted by recency. Tapping a trophy shows a detail card.

import SwiftUI
import SwiftData

struct TrophyCabinetView: View {
    @Query(sort: \Trophy.wonAt, order: .reverse) private var trophies: [Trophy]

    var body: some View {
        Group {
            if trophies.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryBanner
                        trophyGrid
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Kupa Dolabı")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Henüz kupa kazanmadın.")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Bir turnuvayı tamamla, ilk kupan burada yerini alsın.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Summary

    private var summaryBanner: some View {
        let byFormat = Dictionary(grouping: trophies) { $0.format }
        return HStack(spacing: 24) {
            StatBanner(value: "\(trophies.count)", label: "Kupa")
            ForEach(TournamentFormat.allCases, id: \.self) { format in
                if let count = byFormat[format]?.count, count > 0 {
                    StatBanner(value: "\(count)", label: format.displayName)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Grid

    private var trophyGrid: some View {
        LazyVGrid(columns: [.init(.adaptive(minimum: 100))], spacing: 12) {
            ForEach(trophies) { trophy in
                trophyCard(trophy)
            }
        }
    }

    private func trophyCard(_ trophy: Trophy) -> some View {
        let primary = Color(hex: trophy.primaryHex)
        let secondary = Color(hex: trophy.secondaryHex)

        return VStack(spacing: 6) {
            ZStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(formatColor(trophy.format))

                TeamBadgeView(team: placeholderTeam(from: trophy),
                              size: 22, showsCode: false)
                    .offset(y: 4)
            }

            Text(trophy.teamName)
                .font(.caption2)
                .lineLimit(1)

            Text(trophy.format.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(trophy.wonAt.formatted(date: .numeric, time: .omitted))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formatColor(_ format: TournamentFormat) -> Color {
        switch format {
        case .mini:     return .gray
        case .classic:  return .orange
        case .groupKO:  return .blue
        case .grand:    return .yellow
        }
    }

    /// Builds a lightweight Team just for the badge view.
    private func placeholderTeam(from trophy: Trophy) -> Team {
        Team(id: trophy.teamID,
             nameKey: trophy.teamName,
             nameTR: trophy.teamName,
             nameEN: trophy.teamName,
             short: trophy.teamShort,
             primary: trophy.primaryHex,
             secondary: trophy.secondaryHex,
             badgeShape: trophy.badgeShape,
             tier: 0,
             baseStrength: 75,
             stats: .balanced,
             pattern: .solid)
    }
}

private struct StatBanner: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        TrophyCabinetView()
    }
    .modelContainer(for: [Trophy.self], inMemory: true)
    .preferredColorScheme(.dark)
}
