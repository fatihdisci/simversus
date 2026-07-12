//  TournamentPickMyTeamView.swift
//  Features/Tournament
//
//  After choosing a format, the player picks ONE team to pilot through the
//  tournament (CONSTITUTION §4.12). The remaining slots are filled randomly
//  from the pool. Once confirmed, the engine generates fixtures and the
//  tournament begins.

import SwiftUI
import SwiftData

struct TournamentPickMyTeamView: View {
    let format: TournamentFormat
    let onStart: (TournamentState) -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomTeam.name) private var customTeams: [CustomTeam]
    @State private var selectedTeamID: String?
    @State private var tournamentSeed = UInt64.random(in: 1 ... .max)

    private let presetTeams: [Team] = TeamStore().allTeams

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("tournament.pick.your.team")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Bu takım turnuva boyunca seni temsil edecek. Yalnızca bu takımın maçlarını izleyeceksin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if !customTeams.isEmpty {
                    Text("Takımlarım")
                        .font(.sectionLabel)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top)

                    LazyVGrid(columns: [.init(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(customTeams) { ct in
                            teamCard(team: ct.asTeam)
                        }
                    }
                }

                Text("Hazır Takımlar")
                    .font(.sectionLabel)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top)

                LazyVGrid(columns: [.init(.adaptive(minimum: 100))], spacing: 12) {
                    ForEach(presetTeams) { team in
                        teamCard(team: team)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if selectedTeamID != nil {
                Button {
                    startTournament()
                } label: {
                    Text("Turnuvayı Başlat")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    private func teamCard(team: Team) -> some View {
        let isSelected = selectedTeamID == team.id
        return Button {
            selectedTeamID = isSelected ? nil : team.id
        } label: {
            VStack(spacing: 6) {
                TeamBadgeView(team: team, size: 40, showsCode: false)
                Text(team.nameTR)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? team.primaryColor.opacity(0.2) : .clear,
                        in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(team.primaryColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func startTournament() {
        guard let playerTeamID = selectedTeamID else { return }

        var pool = presetTeams.map(\.id)
        pool.append(contentsOf: customTeams.map { $0.id.uuidString })
        var unique = Array(Set(pool))
        if !unique.contains(playerTeamID) { unique.append(playerTeamID) }
        var rng = SeededRandomNumberGenerator(seed: tournamentSeed)
        unique.shuffle(using: &rng)

        var selected = [playerTeamID]
        for id in unique where id != playerTeamID && selected.count < format.teamCount {
            selected.append(id)
        }

        let fixtures = TournamentEngine.generateFixtures(
            format: format,
            teams: selected,
            tournamentSeed: tournamentSeed)

        let state = TournamentState(
            format: format,
            playerTeamID: playerTeamID,
            teams: selected,
            fixtures: fixtures)

        modelContext.insert(state)
        try? modelContext.save()
        onStart(state)
    }
}

#Preview {
    TournamentPickMyTeamView(format: .mini, onStart: { _ in })
        .modelContainer(for: [CustomTeam.self, MatchRecord.self, TournamentState.self],
                        inMemory: true)
        .preferredColorScheme(.dark)
}
