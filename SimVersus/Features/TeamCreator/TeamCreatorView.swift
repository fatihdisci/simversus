//  TeamCreatorView.swift
//  Features/TeamCreator
//
//  Custom-team creator: name + two colours + badge shape + kit pattern + a
//  fixed-budget stat spread (steppers, total locked to PhysicsConstants.statBudget).
//  A live TeamBadgeView preview reflects every change. Saving inserts a
//  `CustomTeam` into SwiftData and pops back to team select. The rewarded-ad
//  Rewarded ads unlock additional slots up to the Phase 2b maximum.

import SwiftUI
import SwiftData

/// The 12 brand-safe preset colours the creator offers (team colours live
/// outside Palette by design — CONSTITUTION §DESIGN, teams.json exception).
enum CreatorPalette {
    static let colors = [
        "#D64545", "#E08A1E", "#E8C33A", "#2E9E5B", "#1FA6A6", "#2E6FD6",
        "#26356B", "#7A3FA0", "#C0417F", "#F0EFEA", "#1A1A1A", "#6B7280"
    ]
}

enum TeamStylePreset: CaseIterable {
    case balanced, powerful, fast, large

    var titleKey: LocalizedStringKey {
        switch self {
        case .balanced: "creator.preset.balanced"
        case .powerful: "creator.preset.powerful"
        case .fast: "creator.preset.fast"
        case .large: "creator.preset.large"
        }
    }

    /// (weight, speed, size) spread this preset applies — also used to detect
    /// which preset matches the current steppers so its chip can highlight.
    var distribution: (weight: Int, speed: Int, size: Int) {
        switch self {
        case .balanced: (3, 3, 3)
        case .powerful: (5, 2, 2)
        case .fast: (2, 5, 2)
        case .large: (2, 2, 5)
        }
    }
}

// MARK: - View model

final class TeamCreatorModel: ObservableObject {
    @Published var name = ""
    @Published var primaryHex = CreatorPalette.colors[0]
    @Published var secondaryHex = CreatorPalette.colors[9]
    @Published var badgeShape: BadgeShape = .star
    @Published var pattern: KitPattern = .solid
    @Published var weight = 3
    @Published var speed = 3
    @Published var size = 3

    var remainingPoints: Int { PhysicsConstants.statBudget - (weight + speed + size) }
    var stats: TeamStats { TeamStats(weight: weight, speed: speed, size: size) }

    var nameFailure: TeamNameValidator.Failure? { TeamNameValidator.validate(name) }
    var colorsDistinct: Bool { primaryHex.caseInsensitiveCompare(secondaryHex) != .orderedSame }
    var canSave: Bool { nameFailure == nil && colorsDistinct && remainingPoints == 0 }

    /// Live preview team built from the current selections.
    var previewTeam: Team {
        Team(id: "preview",
             nameKey: name.isEmpty ? "creator.preview.placeholder" : name,
             nameTR: name, nameEN: name,
             short: CustomTeam.shortCode(from: name),
             primary: primaryHex, secondary: secondaryHex,
             badgeShape: badgeShape, tier: 0, baseStrength: 75,
             stats: stats, pattern: pattern)
    }

    func canIncrement(_ level: Int) -> Bool {
        level < PhysicsConstants.statLevelRange.upperBound && remainingPoints > 0
    }
    func canDecrement(_ level: Int) -> Bool {
        level > PhysicsConstants.statLevelRange.lowerBound
    }
    func increment(_ path: ReferenceWritableKeyPath<TeamCreatorModel, Int>) {
        if canIncrement(self[keyPath: path]) { self[keyPath: path] += 1 }
    }
    func decrement(_ path: ReferenceWritableKeyPath<TeamCreatorModel, Int>) {
        if canDecrement(self[keyPath: path]) { self[keyPath: path] -= 1 }
    }

    func apply(_ preset: TeamStylePreset) {
        (weight, speed, size) = preset.distribution
    }

    /// The preset whose spread matches the current steppers, if any.
    var activePreset: TeamStylePreset? {
        TeamStylePreset.allCases.first { $0.distribution == (weight, speed, size) }
    }

    /// Localization key for the save-bar hint, mentioning only what is still
    /// missing — a static "enter a name and spend the points" reads stale the
    /// moment one half is already done.
    var saveHintKey: String? {
        let nameMissing = nameFailure != nil
        let pointsRemaining = remainingPoints != 0
        switch (nameMissing, pointsRemaining) {
        case (true, true): return "creator.save.hint"
        case (true, false): return "creator.save.hint.name"
        case (false, true): return "creator.save.hint.points"
        // Only the colour rule can still block here; its error is inline.
        case (false, false): return nil
        }
    }

    func makeCustomTeam() -> CustomTeam {
        CustomTeam(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                   primaryHex: primaryHex, secondaryHex: secondaryHex,
                   badgeShape: badgeShape, pattern: pattern, stats: stats)
    }
}

// MARK: - View

struct TeamCreatorView: View {
    @Environment(\.modelContext) private var modelContext
    /// Existing custom teams — drives the slot lock.
    @Query private var existingTeams: [CustomTeam]
    /// Called after a successful save to pop back to team select.
    let onDone: () -> Void

    @StateObject private var model = TeamCreatorModel()
    @ObservedObject private var adManager = AdManager.shared
    @State private var showUnlockPrompt = false

    private var slotAvailable: Bool { CustomTeamStore.canCreate(existingCount: existingTeams.count) }

    var body: some View {
        ZStack {
            ArenaBackground(primaryTint: Color(hex: model.primaryHex),
                            secondaryTint: Color(hex: model.secondaryHex))
            ScrollView {
                VStack(spacing: Spacing.l) {
                    identityCard
                    appearanceCard
                    statCard
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.l)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .top) { previewBar }
        .safeAreaInset(edge: .bottom) { saveBar }
        .navigationTitle("creator.title")
        .navigationBarTitleDisplayMode(.inline)
        .task { await adManager.preloadRewarded() }
        .alert("slots.unlock.title", isPresented: $showUnlockPrompt) {
            Button("slots.unlock.cta", action: watchRewarded)
                .disabled(!adManager.isRewardedReady)
            Button("common.cancel", role: .cancel) {}
        } message: { Text("slots.unlock.adfreeNote") }
    }

    // MARK: Preview

    private var previewBar: some View {
        HStack(spacing: Spacing.m) {
            TeamBadgeView(team: model.previewTeam, size: 62)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("creator.preview.live")
                    .font(.caption)
                    .foregroundStyle(Palette.accent)
                    .textCase(.uppercase)
                Text(model.name.isEmpty ? String(localized: "creator.preview.placeholder") : model.name)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            }
            Spacer()
            // Round kit token — a preview of how this team's ball looks in the
            // arena (primary + secondary + pattern), distinct from the shield.
            ZStack {
                Circle().fill(Color(hex: model.primaryHex))
                KitPatternShape(pattern: model.pattern)
                    .fill(Color(hex: model.secondaryHex))
                    .clipShape(Circle())
                Circle().stroke(Palette.borderStrong, lineWidth: 1)
            }
            .frame(width: 34, height: 34)
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.borderSubtle).frame(height: 1) }
    }

    private var identityCard: some View {
        ArenaSurface {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ArenaSectionHeader(title: "creator.section.identity", eyebrow: "creator.step.one")
                nameSection
                colorSection
            }
        }
    }

    private var appearanceCard: some View {
        ArenaSurface {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ArenaSectionHeader(title: "creator.section.appearance", eyebrow: "creator.step.two")
                shapeSection
                patternSection
            }
        }
    }

    private var statCard: some View {
        ArenaSurface {
            VStack(alignment: .leading, spacing: Spacing.m) {
                ArenaSectionHeader(title: "creator.section.stats", eyebrow: "creator.step.three")
                Text("creator.stats.help")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                presetPicker
                statSection
            }
        }
    }

    // MARK: Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("creator.name.placeholder", text: $model.name)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .textInputAutocapitalization(.words)
                .padding(Spacing.m)
                .background(Palette.bgDeep.opacity(0.72), in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.button).stroke(Palette.borderSubtle))
            if let failure = model.nameFailure, !model.name.isEmpty {
                Text(LocalizedStringKey(failure.messageKey))
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            }
        }
    }

    // MARK: Colours

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("creator.section.primary")
            SwatchGrid(selected: $model.primaryHex, disabledHex: nil)
            sectionTitle("creator.section.secondary")
            SwatchGrid(selected: $model.secondaryHex, disabledHex: model.primaryHex)
            if !model.colorsDistinct {
                Text("creator.error.sameColor")
                    .font(.caption)
                    .foregroundStyle(Palette.danger)
            }
        }
    }

    // MARK: Badge shape

    private var shapeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("creator.section.shape")
            HStack(spacing: Spacing.s) {
                ForEach(BadgeShape.allCases, id: \.self) { shape in
                    SelectableChip(isSelected: model.badgeShape == shape) {
                        model.badgeShape = shape
                    } content: {
                        BadgeSymbolShape(shape: shape)
                            .fill(Palette.textPrimary, style: FillStyle(eoFill: true))
                            .frame(width: 26, height: 26)
                    }
                }
            }
        }
    }

    // MARK: Pattern

    private var patternSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            sectionTitle("creator.section.pattern")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    ForEach(KitPattern.allCases, id: \.self) { pattern in
                        SelectableChip(isSelected: model.pattern == pattern) {
                            model.pattern = pattern
                        } content: {
                            patternSwatch(pattern)
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    private func patternSwatch(_ pattern: KitPattern) -> some View {
        ZStack {
            Circle().fill(Color(hex: model.primaryHex))
            KitPatternShape(pattern: pattern)
                .fill(Color(hex: model.secondaryHex))
                .clipShape(Circle())
        }
        .frame(width: 30, height: 30)
    }

    // MARK: Stats

    private var statSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("creator.remaining \(model.remainingPoints)")
                    .font(.caption)
                    .foregroundStyle(model.remainingPoints == 0 ? Palette.accent : Palette.accentWarning)
                Spacer()
            }
            StatStepperRow(titleKey: "creator.stat.weight", level: model.weight,
                           canDec: model.canDecrement(model.weight), canInc: model.canIncrement(model.weight),
                           dec: { model.decrement(\.weight) }, inc: { model.increment(\.weight) })
            StatStepperRow(titleKey: "creator.stat.speed", level: model.speed,
                           canDec: model.canDecrement(model.speed), canInc: model.canIncrement(model.speed),
                           dec: { model.decrement(\.speed) }, inc: { model.increment(\.speed) })
            StatStepperRow(titleKey: "creator.stat.size", level: model.size,
                           canDec: model.canDecrement(model.size), canInc: model.canIncrement(model.size),
                           dec: { model.decrement(\.size) }, inc: { model.increment(\.size) })
        }
    }

    private var presetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(TeamStylePreset.allCases, id: \.self) { preset in
                    let isActive = model.activePreset == preset
                    Button { model.apply(preset) } label: {
                        Text(preset.titleKey)
                            .font(.caption)
                            .foregroundStyle(isActive ? Palette.bgDeep : Palette.textPrimary)
                            .padding(.horizontal, Spacing.m)
                            .frame(minHeight: 40)
                            .background(isActive ? Palette.accent : Palette.bgElevatedStrong, in: Capsule())
                            .overlay(Capsule().stroke(isActive ? Palette.accent : Palette.borderStrong))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
        }
    }

    // MARK: Save

    private var saveBar: some View {
        VStack(spacing: Spacing.s) {
            Button(action: save) {
                HStack {
                    Text("creator.save")
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
            .buttonStyle(ArenaButtonStyle(kind: .primary))
            .disabled(!model.canSave || !slotAvailable)

            if !slotAvailable {
                if CustomTeamStore.unlockedSlots >= CustomTeamStore.maxSlots {
                    Text("slots.max").font(.caption).foregroundStyle(Palette.textSecondary)
                } else {
                    Button("slots.unlock.cta") { showUnlockPrompt = true }
                        .font(.sectionLabel)
                        .foregroundStyle(adManager.isRewardedReady ? Palette.accent : Palette.textTertiary)
                        .frame(minHeight: Layout.minTouchTarget)
                    if !adManager.isRewardedReady { Text("ads.rewarded.unavailable").font(.caption).foregroundStyle(Palette.textSecondary) }
                }
            } else if !model.canSave, let hintKey = model.saveHintKey {
                Text(LocalizedStringKey(hintKey))
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.borderSubtle).frame(height: 1) }
    }

    private func save() {
        guard model.canSave, slotAvailable else { return }
        modelContext.insert(model.makeCustomTeam())
        try? modelContext.save()
        onDone()
    }

    private func watchRewarded() {
        adManager.showRewarded { CustomTeamStore.unlockAdditionalSlot() }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.sectionLabel).foregroundStyle(Palette.textPrimary)
    }
}

// MARK: - Reusable pieces

/// A 12-colour swatch grid. The swatch equal to `disabledHex` (the other slot's
/// colour) is dimmed and non-selectable so the two colours can't match.
private struct SwatchGrid: View {
    @Binding var selected: String
    let disabledHex: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.s), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Spacing.s) {
            ForEach(CreatorPalette.colors, id: \.self) { hex in
                let isDisabled = hex.caseInsensitiveCompare(disabledHex ?? "") == .orderedSame
                Button { if !isDisabled { selected = hex } } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(height: 34)
                        .overlay(
                            Circle().strokeBorder(
                                selected == hex ? Palette.accent : Palette.arenaLine,
                                lineWidth: selected == hex ? 3 : 1)
                        )
                        .overlay {
                            if selected == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black, radius: 2)
                            } else if isDisabled {
                                // A dimmed swatch alone can pass for a dark
                                // colour; the slash states "taken by the other
                                // slot" explicitly.
                                Image(systemName: "line.diagonal")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.35 : 1)
                .accessibilityLabel(Text(verbatim: hex))
                .accessibilityAddTraits(selected == hex ? .isSelected : [])
            }
        }
    }
}

/// A tappable chip with a selected outline, wrapping arbitrary content.
private struct SelectableChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(width: 44, height: 44)
                .background(Palette.bgDeep.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .strokeBorder(isSelected ? Palette.accent : Palette.borderSubtle, lineWidth: isSelected ? 2 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// One stat row: label, minus, five level pips, plus.
private struct StatStepperRow: View {
    let titleKey: LocalizedStringKey
    let level: Int
    let canDec: Bool
    let canInc: Bool
    let dec: () -> Void
    let inc: () -> Void

    var body: some View {
        HStack(spacing: Spacing.m) {
            Text(titleKey)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 72, alignment: .leading)
            stepButton("minus", enabled: canDec, action: dec)
            HStack(spacing: Spacing.xs) {
                ForEach(1...5, id: \.self) { i in
                    Capsule()
                        .fill(i <= level ? Palette.accent : Palette.arenaLine)
                        .frame(width: 14, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", enabled: canInc, action: inc)
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Palette.textPrimary : Palette.arenaLine)
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    NavigationStack {
        TeamCreatorView(onDone: {})
    }
    .modelContainer(for: CustomTeam.self, inMemory: true)
    .preferredColorScheme(.dark)
}
