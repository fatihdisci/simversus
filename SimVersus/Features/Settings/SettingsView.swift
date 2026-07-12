//  SettingsView.swift
//  Features/Settings
//
//  Match duration, purchase management and about. Presented as a sheet from Home.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var purchaseManager: PurchaseManager
    let onDone: () -> Void
    @State private var showRemoveAds = false
    @State private var restoreMessage: String?

    var body: some View {
        ZStack {
            ArenaBackground(showsRings: false)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    durationSection
                    purchasesSection
                    aboutSection
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showRemoveAds) { RemoveAdsSheet() }
    }

    private var purchasesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "settings.purchases")
            ArenaSurface {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    // Status row states a fact ("Reklamlar etkin" / "Reklamsız
                    // aktif"); the action button below carries the CTA — the two
                    // must not repeat the same label.
                    HStack {
                        Text(purchaseManager.isAdFree ? "settings.purchases.active" : "settings.purchases.inactive")
                            .font(.sectionLabel).foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: purchaseManager.isAdFree ? "checkmark.seal.fill" : "megaphone.fill")
                            .foregroundStyle(purchaseManager.isAdFree ? Palette.accent : Palette.textSecondary)
                    }
                    if !purchaseManager.isAdFree {
                        Button("home.removeAds") { showRemoveAds = true }
                            .buttonStyle(ArenaButtonStyle(kind: .secondary))
                    }
                    Button("iap.restore") { restorePurchases() }
                        .font(.sectionLabel).foregroundStyle(Palette.textSecondary)
                    if let restoreMessage { Text(LocalizedStringKey(restoreMessage)).font(.caption).foregroundStyle(Palette.textSecondary) }
                }
            }
        }
    }

    private func restorePurchases() {
        Task { restoreMessage = await purchaseManager.restore() ? "iap.restore.success" : "iap.restore.empty" }
    }

    private var header: some View {
        HStack {
            Text("settings.title")
                .font(.screenTitle)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            ArenaIconButton(systemName: "xmark", accessibilityKey: "common.close", action: onDone)
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "settings.duration")
            ArenaSurface {
                HStack(spacing: Spacing.s) {
                    ForEach(MatchDurationOption.allCases) { option in
                        ArenaChoicePill(title: option.titleKey,
                                        subtitle: Self.durationSubtitle(option),
                                        isSelected: appState.matchDuration == option) {
                            appState.matchDuration = option
                        }
                    }
                }
            }
        }
    }

    private static func durationSubtitle(_ option: MatchDurationOption) -> String {
        let format = NSLocalizedString("match.duration.seconds %d", comment: "")
        return String.localizedStringWithFormat(format, Int(option.seconds))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "settings.about")
            ArenaSurface(padding: 0) {
                VStack(spacing: 0) {
                    aboutRow("settings.about.version") {
                        Text(verbatim: Self.appVersion)
                    }
                    Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                    aboutRow("settings.about.builtWith") {
                        Text("settings.about.builtWith.value")
                    }
                    Rectangle().fill(Palette.borderSubtle).frame(height: 1)
                    aboutRow("settings.about.privacy") {
                        Text("settings.about.privacy.value")
                    }
                }
            }
        }
    }

    private func aboutRow<Trailing: View>(_ titleKey: LocalizedStringKey,
                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(titleKey)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            trailing()
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.m)
        .frame(minHeight: 52)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

#Preview {
    SettingsView(onDone: {})
        .environmentObject(AppState())
        .environmentObject(PurchaseManager.shared)
        .preferredColorScheme(.dark)
}
