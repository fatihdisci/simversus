//  SettingsView.swift
//  Features/Settings
//
//  Phase 2d: match speed, match duration and about. Presented as a sheet
//  from Home. Purchases/restore stay out until StoreKit is wired up
//  (Core/Monetization is still a stub — see AdGate.swift).

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    let onDone: () -> Void

    var body: some View {
        ZStack {
            ArenaBackground(showsRings: false)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    speedSection
                    durationSection
                    aboutSection
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
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

    private var speedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "settings.speed")
            ArenaSurface {
                HStack(spacing: Spacing.s) {
                    ForEach(MatchSpeedOption.allCases) { option in
                        SettingsOptionButton(title: option.titleKey,
                                              isSelected: appState.matchSpeed == option) {
                            appState.matchSpeed = option
                        }
                    }
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ArenaSectionHeader(title: "settings.duration")
            ArenaSurface {
                HStack(spacing: Spacing.s) {
                    ForEach(MatchDurationOption.allCases) { option in
                        SettingsOptionButton(title: option.titleKey,
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

/// A pill-shaped choice button used for the speed/duration option rows —
/// scoped to Settings since it needs a text label (not the fixed-size icon
/// glyph `SelectableChip` in TeamCreatorView is built for).
private struct SettingsOptionButton: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(LocalizedStringKey(title))
                    .font(.sectionLabel)
                    .foregroundStyle(isSelected ? Palette.bgDeep : Palette.textPrimary)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? Palette.bgDeep.opacity(0.7) : Palette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Layout.minTouchTarget)
            .background(isSelected ? Palette.accent : Palette.bgElevatedStrong,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SettingsView(onDone: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
