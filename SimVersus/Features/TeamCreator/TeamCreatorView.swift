//  TeamCreatorView.swift
//  Features/TeamCreator
//
//  Custom-team creator: name + two colours + badge shape + kit pattern + a
//  fixed-budget stat spread (steppers, total locked to PhysicsConstants.statBudget).
//  A live TeamBadgeView preview reflects every change. Saving inserts a
//  `CustomTeam` into SwiftData and pops back to team select. The rewarded-ad
//  slot unlock is Phase 2b — here a full slot just disables Save (CONSTITUTION).

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

    private var slotAvailable: Bool { CustomTeamStore.canCreate(existingCount: existingTeams.count) }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Spacing.l) {
                    preview
                    nameSection
                    colorSection
                    shapeSection
                    patternSection
                    statSection
                    saveSection
                }
                .padding(Spacing.l)
            }
        }
        .navigationTitle("creator.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Preview

    private var preview: some View {
        TeamBadgeView(team: model.previewTeam, size: 96)
            .padding(.top, Spacing.s)
    }

    // MARK: Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            TextField("creator.name.placeholder", text: $model.name)
                .font(.body)
                .foregroundStyle(Palette.textPrimary)
                .textInputAutocapitalization(.words)
                .padding(Spacing.m)
                .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            if let failure = model.nameFailure, !model.name.isEmpty {
                Text(LocalizedStringKey(failure.messageKey))
                    .font(.label)
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
                    .font(.label)
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
                sectionTitle("creator.section.stats")
                Spacer()
                Text("creator.remaining \(model.remainingPoints)")
                    .font(.label)
                    .foregroundStyle(model.remainingPoints == 0 ? Palette.textSecondary : Palette.accent)
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

    // MARK: Save

    private var saveSection: some View {
        VStack(spacing: Spacing.s) {
            Button(action: save) {
                Text("creator.save")
                    .font(.titleXL)
                    .foregroundStyle(Palette.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.m)
                    .background(
                        (model.canSave && slotAvailable) ? Palette.accent : Palette.arenaLine,
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!model.canSave || !slotAvailable)

            if !slotAvailable {
                Label("creator.slot.locked", systemImage: "lock.fill")
                    .font(.label)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    private func save() {
        guard model.canSave, slotAvailable else { return }
        modelContext.insert(model.makeCustomTeam())
        try? modelContext.save()
        onDone()
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.label).foregroundStyle(Palette.textSecondary)
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
                Circle()
                    .fill(Color(hex: hex))
                    .frame(height: 34)
                    .overlay(
                        Circle().strokeBorder(
                            selected == hex ? Palette.accent : Palette.arenaLine,
                            lineWidth: selected == hex ? 3 : 1)
                    )
                    .opacity(isDisabled ? 0.25 : 1)
                    .onTapGesture { if !isDisabled { selected = hex } }
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
                .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 2)
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
