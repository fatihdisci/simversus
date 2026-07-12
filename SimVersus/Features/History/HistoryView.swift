//  HistoryView.swift
//  Features/History
//
//  Match history (Phase 2c): a broadcast-style list of saved results and a
//  per-team win/goal summary, both drawn from SwiftData `MatchRecord`s and
//  rendered in the shared Night Arena language.

import SwiftUI
import SwiftData

struct HistoryView: View {
    let onPlay: () -> Void

    /// Bundle teams load once for the whole screen — `TeamStore()` re-decodes
    /// teams.json, so building it inside `body` would repeat that work on
    /// every SwiftData-driven render.
    private static let bundleTeams = TeamStore().allTeams

    @Query(sort: \MatchRecord.playedAt, order: .reverse) private var records: [MatchRecord]
    @Query(sort: \CustomTeam.createdAt) private var customTeams: [CustomTeam]
    @State private var selection = 0

    private var teamsByID: [String: Team] {
        Dictionary((Self.bundleTeams + customTeams.map(\.asTeam)).map { ($0.id, $0) },
                   uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ZStack {
            ArenaBackground()
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.s) {
                    ArenaChoicePill(title: "history.matches", isSelected: selection == 0) { selection = 0 }
                    ArenaChoicePill(title: "history.stats", isSelected: selection == 1) { selection = 1 }
                }
                if selection == 0 {
                    matchList
                } else {
                    StatsView(records: records, teamsByID: teamsByID)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("history.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var matchList: some View {
        if records.isEmpty {
            ArenaSurface {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Palette.textTertiary)
                    Text("history.empty").font(.sectionLabel).foregroundStyle(Palette.textSecondary)
                    ArenaCTAButton(title: "home.play", systemImage: "play.fill", action: onPlay)
                }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.s) {
                    ForEach(records) { record in
                        NavigationLink {
                            HistoryDetailView(record: record, teamsByID: teamsByID)
                        } label: {
                            MatchHistoryRow(record: record, teamsByID: teamsByID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Shared lookup helpers

private func teamName(_ id: String, in teamsByID: [String: Team]) -> String {
    // Custom teams carry their raw name as `nameKey`; NSLocalizedString passes
    // unknown keys through unchanged, so both cases resolve with one call.
    teamsByID[id].map { NSLocalizedString($0.nameKey, comment: "") } ?? id
}

/// Orb for a recorded team, or a placeholder when the team no longer exists
/// (e.g. a deleted custom team).
private struct RecordedTeamOrb: View {
    let team: Team?
    let size: CGFloat

    var body: some View {
        if let team {
            TeamOrbView(team: team, size: size)
        } else {
            Image(systemName: "questionmark.circle")
                .font(.system(size: size * 0.66, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Match list

private struct MatchHistoryRow: View {
    let record: MatchRecord
    let teamsByID: [String: Team]

    var body: some View {
        ArenaSurface {
            VStack(spacing: Spacing.s) {
                teamLine(id: record.homeTeamID, score: record.homeScore,
                         won: record.homeScore > record.awayScore)
                teamLine(id: record.awayTeamID, score: record.awayScore,
                         won: record.awayScore > record.homeScore)
                HStack {
                    Text(record.playedAt, format: .relative(presentation: .named))
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func teamLine(id: String, score: Int, won: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            RecordedTeamOrb(team: teamsByID[id], size: 24)
            Text(teamName(id, in: teamsByID))
                .font(.sectionLabel)
                .foregroundStyle(won ? Palette.textPrimary : Palette.textSecondary)
                .lineLimit(1)
            Spacer()
            Text("\(score)")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(won ? Palette.accent : Palette.textPrimary)
        }
    }
}

// MARK: - Match detail

private struct HistoryDetailView: View {
    let record: MatchRecord
    let teamsByID: [String: Team]

    /// Decoded once — `record.goals` decodes JSON on every access.
    private let goals: [Goal]

    init(record: MatchRecord, teamsByID: [String: Team]) {
        self.record = record
        self.teamsByID = teamsByID
        self.goals = record.goals
    }

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: teamsByID[record.homeTeamID]?.primaryColor ?? Palette.energy,
                            secondaryTint: teamsByID[record.awayTeamID]?.primaryColor ?? Palette.accent)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    scoreCard
                    goalTimeline
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("history.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var scoreCard: some View {
        ArenaSurface(padding: Spacing.l, isFocused: true) {
            VStack(spacing: Spacing.m) {
                HStack(spacing: Spacing.m) {
                    detailTeam(id: record.homeTeamID)
                    HStack(spacing: Spacing.s) {
                        Text("\(record.homeScore)")
                        Text(verbatim: "–").foregroundStyle(Palette.textTertiary)
                        Text("\(record.awayScore)")
                    }
                    .font(.finalScore)
                    .foregroundStyle(Palette.textPrimary)
                    .minimumScaleFactor(0.72)
                    .lineLimit(1)
                    detailTeam(id: record.awayTeamID)
                }
                Text(record.playedAt, format: .dateTime.day().month(.wide).hour().minute())
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func detailTeam(id: String) -> some View {
        VStack(spacing: Spacing.xs) {
            RecordedTeamOrb(team: teamsByID[id], size: 56)
            Text(teamName(id, in: teamsByID))
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var goalTimeline: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "result.goals")
            if goals.isEmpty {
                ArenaSurface {
                    Label("result.noGoals", systemImage: "minus.circle")
                        .font(.sectionLabel)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
            } else {
                ArenaSurface(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(goals.indices, id: \.self) { index in
                            ResultGoalRow(goal: goals[index],
                                          team: teamsByID[goals[index].teamID],
                                          homeScoreAfter: runningScores[index].home,
                                          awayScoreAfter: runningScores[index].away)
                            if index != goals.indices.last {
                                Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Cumulative home/away score after each goal (same broadcast progression
    /// as the post-match Result screen).
    private var runningScores: [(home: Int, away: Int)] {
        var home = 0, away = 0
        return goals.map { goal in
            if goal.teamID == record.homeTeamID { home += 1 }
            else if goal.teamID == record.awayTeamID { away += 1 }
            return (home, away)
        }
    }
}

// MARK: - Stats

private struct StatsView: View {
    let records: [MatchRecord]
    let teamsByID: [String: Team]

    private var teamIDs: [String] {
        Array(Set(records.flatMap { [$0.homeTeamID, $0.awayTeamID] })).sorted()
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.s) {
                ArenaSurface {
                    HStack {
                        Text("stats.played")
                            .font(.sectionLabel)
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text("\(records.count)")
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                    }
                }
                ForEach(teamIDs, id: \.self) { id in
                    TeamStatsRow(teamID: id, records: records, team: teamsByID[id],
                                 name: teamName(id, in: teamsByID))
                }
            }
            .padding(.bottom, Spacing.l)
        }
        .scrollIndicators(.hidden)
    }
}

private struct TeamStatsRow: View {
    let teamID: String
    let records: [MatchRecord]
    let team: Team?
    let name: String

    private var played: [MatchRecord] {
        records.filter { $0.homeTeamID == teamID || $0.awayTeamID == teamID }
    }
    private var wins: Int {
        played.filter {
            ($0.homeTeamID == teamID && $0.homeScore > $0.awayScore) ||
            ($0.awayTeamID == teamID && $0.awayScore > $0.homeScore)
        }.count
    }
    private var goals: Int {
        played.reduce(0) { $0 + ($1.homeTeamID == teamID ? $1.homeScore : $1.awayScore) }
    }

    var body: some View {
        ArenaSurface {
            HStack(spacing: Spacing.m) {
                RecordedTeamOrb(team: team, size: 30)
                Text(name)
                    .font(.sectionLabel)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(wins) / \(played.count)").font(.headline).monospacedDigit()
                    Text("stats.wins").font(.caption).foregroundStyle(Palette.textSecondary)
                }
                Divider().frame(height: 28)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(goals)").font(.headline).monospacedDigit()
                    Text("stats.goalsFor").font(.caption).foregroundStyle(Palette.textSecondary)
                }
            }
            .foregroundStyle(Palette.textPrimary)
        }
    }
}
