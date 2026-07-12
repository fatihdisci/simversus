//  TournamentLobbyView.swift
//  Features/Tournament
//
//  Format picker before entering a tournament. Free formats (mini, classic)
//  start immediately; premium formats (groupKO, grand) require a rewarded ad.

import SwiftUI

struct TournamentLobbyView: View {
    let onSelectFormat: (TournamentFormat) -> Void
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var adManager = AdManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Turnuva")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Bir format seç, takımını belirle, kupayı kazan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(TournamentFormat.allCases, id: \.self) { format in
                    FormatCard(format: format, isLocked: !format.isFree && !purchaseManager.isAdFree)
                        .onTapGesture {
                            guard format.isFree || purchaseManager.isAdFree else {
                                adManager.showRewarded {
                                    onSelectFormat(format)
                                }
                                return
                            }
                            onSelectFormat(format)
                        }
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .task { await adManager.preloadRewarded() }
    }
}

private struct FormatCard: View {
    let format: TournamentFormat
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(format.displayName)
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLocked {
                Image(systemName: "play.rectangle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var summary: String {
        let teams = format.teamCount
        if format.hasGroupStage {
            return "\(teams) takım, \(format.groupCount) grup + eleme"
        } else {
            return "\(teams) takım, tek eleme"
        }
    }
}

#Preview {
    TournamentLobbyView(onSelectFormat: { _ in })
        .environmentObject(PurchaseManager.shared)
        .preferredColorScheme(.dark)
}
