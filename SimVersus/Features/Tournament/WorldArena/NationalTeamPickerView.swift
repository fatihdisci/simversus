//  NationalTeamPickerView.swift

import SwiftUI

struct NationalTeamPickerView: View {
    let onContinue: (String) -> Void

    @State private var selectedTeamID: String?
    @State private var searchText = ""
    private let teams = NationalTeamStore().allTeams

    private var filteredTeams: [NationalTeamDefinition] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return teams }
        return teams.filter { team in
            localizedName(team).range(of: query,
                                      options: [.caseInsensitive, .diacriticInsensitive]) != nil
                || team.shortCode.range(of: query,
                                        options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Palette.accentWarning,
                            secondaryTint: Palette.energy)
            ScrollView {
                LazyVStack(spacing: Spacing.s) {
                    ForEach(filteredTeams) { team in
                        NationalTeamRow(team: team,
                                        isSelected: selectedTeamID == team.id) {
                            selectedTeamID = team.id
                        }
                    }
                    if filteredTeams.isEmpty { emptyState }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.m)
                .padding(.bottom, 88)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("tournament.worldArena.picker.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText,
                    prompt: "tournament.worldArena.picker.search")
        .safeAreaInset(edge: .bottom) { continueBar }
    }

    private var continueBar: some View {
        ArenaCTAButton(title: "common.continue",
                       systemImage: "arrow.right",
                       isEnabled: selectedTeamID != nil) {
            if let selectedTeamID { onContinue(selectedTeamID) }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        ContentUnavailableView("tournament.worldArena.picker.empty",
                               systemImage: "magnifyingglass")
            .foregroundStyle(Palette.textSecondary)
            .padding(.top, Spacing.xl)
    }

    private func localizedName(_ team: NationalTeamDefinition) -> String {
        NSLocalizedString(team.nameKey, comment: "")
    }
}

private struct NationalTeamRow: View {
    let team: NationalTeamDefinition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m) {
                NationalFlagView(team: team, style: .compact)
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(LocalizedStringKey(team.nameKey))
                        .font(.body)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2)
                    Text(team.shortCode)
                        .font(.caption.monospaced())
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Text(String.localizedStringWithFormat(
                    NSLocalizedString("tournament.worldArena.picker.pot", comment: ""), team.pot))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.accent : Palette.borderStrong)
            }
            .padding(Spacing.m)
            .background(isSelected ? Palette.bgElevatedStrong : Palette.bgElevated,
                        in: RoundedRectangle(cornerRadius: Radius.button))
            .overlay(RoundedRectangle(cornerRadius: Radius.button)
                .stroke(isSelected ? Palette.accent : Palette.borderSubtle,
                        lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(ArenaTileButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { NationalTeamPickerView(onContinue: { _ in }) }
        .preferredColorScheme(.dark)
}
