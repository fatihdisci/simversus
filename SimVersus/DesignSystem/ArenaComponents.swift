//  ArenaComponents.swift
//  Shared "Night Arena / Live Broadcast" primitives.

import SwiftUI

struct ArenaBackground: View {
    var primaryTint: Color = Palette.energy
    var secondaryTint: Color = Palette.accent
    var showsRings = true

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Palette.bgDeep, Palette.bgPrimary, Palette.bgDeep],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)

                RadialGradient(colors: [primaryTint.opacity(0.16), .clear],
                               center: .topTrailing,
                               startRadius: 0,
                               endRadius: proxy.size.width * 0.9)

                RadialGradient(colors: [secondaryTint.opacity(0.10), .clear],
                               center: .bottomLeading,
                               startRadius: 0,
                               endRadius: proxy.size.width)

                if showsRings {
                    Circle()
                        .stroke(Palette.energy.opacity(0.055), lineWidth: 1)
                        .frame(width: proxy.size.width * 1.16)
                        .offset(x: proxy.size.width * 0.28, y: -proxy.size.height * 0.31)
                    Circle()
                        .stroke(Palette.accent.opacity(0.04), lineWidth: 20)
                        .frame(width: proxy.size.width * 0.88)
                        .offset(x: -proxy.size.width * 0.33, y: proxy.size.height * 0.36)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct ArenaSurface<Content: View>: View {
    var padding: CGFloat = Spacing.m
    var isFocused = false
    let content: Content

    init(padding: CGFloat = Spacing.m,
         isFocused: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.isFocused = isFocused
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                LinearGradient(colors: [
                    isFocused ? Palette.bgElevatedStrong : Palette.bgElevated,
                    Palette.bgDeep.opacity(0.86)
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(isFocused ? Palette.borderStrong : Palette.borderSubtle, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.24), radius: 20, y: 10)
    }
}

enum ArenaButtonKind {
    case primary, secondary, destructive
}

struct ArenaButtonStyle: ButtonStyle {
    let kind: ArenaButtonKind
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.button)
            .foregroundStyle(foreground)
            .padding(.horizontal, Layout.ctaContentPadding)
            .frame(maxWidth: .infinity, minHeight: Layout.ctaMinHeight)
            .background(background(configuration.isPressed),
                        in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.textSecondary }
        return kind == .primary ? Palette.bgDeep : Palette.textPrimary
    }

    private func background(_ pressed: Bool) -> Color {
        guard isEnabled else { return Palette.bgElevated }
        switch kind {
        case .primary: return Palette.accent.opacity(pressed ? 0.78 : 1)
        case .secondary: return Palette.bgElevatedStrong.opacity(pressed ? 0.72 : 1)
        case .destructive: return Palette.danger.opacity(pressed ? 0.65 : 0.18)
        }
    }

    private var border: Color {
        guard isEnabled else { return Palette.borderSubtle }
        switch kind {
        case .primary: return Palette.accent
        case .secondary: return Palette.borderStrong
        case .destructive: return Palette.danger.opacity(0.65)
        }
    }
}

/// A hero call-to-action with a leading title and an optically balanced trailing
/// icon accessory. Unifies every primary/secondary CTA of the app — Maçı Başlat,
/// Başlama Vuruşu, Rövanş, Yeni Maç — into a single family so text weight, height,
/// corner radius, internal padding and icon placement never drift per screen.
///
/// The primary variant wraps the trailing glyph in a subtle chip so it reads as a
/// deliberate accessory; the lighter secondary variant shows the glyph bare, which
/// keeps the same leading-title / trailing-icon structure at a lower visual weight.
struct ArenaCTAButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var kind: ArenaButtonKind = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let systemImage {
                    Spacer(minLength: Spacing.s)
                    Image(systemName: systemImage)
                        .font(.system(size: Layout.ctaAccessoryIcon, weight: .bold))
                        .frame(width: Layout.ctaAccessory, height: Layout.ctaAccessory)
                        .background(accessoryFill, in: Circle())
                }
            }
        }
        .buttonStyle(ArenaButtonStyle(kind: kind))
        .disabled(!isEnabled)
    }

    /// Primary CTAs carry a chip behind the glyph (dark on the neon fill);
    /// secondary/destructive keep the glyph bare for a lighter read.
    private var accessoryFill: Color {
        kind == .primary ? Palette.bgDeep.opacity(0.15) : Color.clear
    }
}

struct ArenaIconButton: View {
    let systemName: String
    let accessibilityKey: LocalizedStringKey
    var tint: Color = Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: Layout.minTouchTarget, height: Layout.minTouchTarget)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Palette.borderStrong.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityKey))
    }
}

/// A pill-shaped choice button for small exclusive option groups (match
/// length, history tabs). Selection combines fill, stroke and text colour —
/// never hue alone — and reports `.isSelected` to assistive tech.
struct ArenaChoicePill: View {
    /// Localization key of the label.
    let title: String
    /// Optional pre-localized supporting line (e.g. "45 sn").
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

struct ArenaSectionHeader: View {
    let title: LocalizedStringKey
    var eyebrow: LocalizedStringKey?
    var trailingText: LocalizedStringKey?

    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption)
                        .foregroundStyle(Palette.accent)
                        .textCase(.uppercase)
                }
                Text(title)
                    .font(.sectionLabel)
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }
}

struct TeamGlow: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color.opacity(0.18))
            .blur(radius: 24)
            .allowsHitTesting(false)
    }
}

struct TeamOrbView: View {
    let team: Team
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(team.primaryColor)
            KitPatternShape(pattern: team.pattern)
                .fill(team.secondaryColor)
                .clipShape(Circle())
            Circle()
                .stroke(team.secondaryColor, lineWidth: max(2, size * 0.045))
            BadgeSymbolShape(shape: team.badgeShape)
                .fill(team.secondaryColor, style: FillStyle(eoFill: true))
                .frame(width: size * 0.44, height: size * 0.44)
        }
        .frame(width: size, height: size)
        .background(TeamGlow(color: team.primaryColor).frame(width: size * 1.35, height: size * 1.35))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(team.nameKey)))
    }
}
