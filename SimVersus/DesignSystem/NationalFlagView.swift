//  NationalFlagView.swift
//  DesignSystem
//
//  A reusable, self-contained flag renderer for World Arena national teams.
//  The repo ships NO flag image assets, so every flag is drawn from geometric
//  primitives (bands, crosses, discs) — there is never an empty `Image(...)`.
//
//  Colours always come from the team's own catalog entry (primary/secondary/
//  tertiary), so the flag stays a single source of truth with the JSON. The
//  arrangement is resolved from `flagAsset` — NOT from `isoCode` — so a nation
//  whose ISO code differs from its footballing flag (e.g. England carries ISO
//  "GB" but must show the St George cross, not the Union Jack) resolves the
//  correct design explicitly through `flagAsset` ("flag_gb" → upright cross).
//
//  Brand safety: these are simplified national-flag colour arrangements, not
//  federation crests or football-federation logos. Emblem-heavy flags degrade
//  to their nearest geometric form (a crescent/star becomes a centred disc),
//  never a real emblem.

import SwiftUI

// MARK: - Public style

/// Visual weight for a rendered flag. Only the framing changes (corner radius,
/// hairline, default size); the arrangement is identical across styles so the
/// same flag reads consistently in a list row and a hero.
enum NationalFlagStyle {
    /// Small inline flag for list rows and metadata.
    case compact
    /// Larger flag for headers and detail contexts.
    case standard

    var cornerRadius: CGFloat {
        switch self {
        case .compact:  return NationalFlagMetrics.compactCorner
        case .standard: return NationalFlagMetrics.standardCorner
        }
    }

    /// Default height when the caller does not impose one via `.frame`.
    var defaultHeight: CGFloat {
        switch self {
        case .compact:  return NationalFlagMetrics.compactHeight
        case .standard: return NationalFlagMetrics.standardHeight
        }
    }
}

/// Named rendering constants (no inline magic numbers). Flags use the
/// conventional 3:2 field ratio.
private enum NationalFlagMetrics {
    static let aspectRatio: CGFloat = 3.0 / 2.0
    static let compactHeight: CGFloat = 18
    static let standardHeight: CGFloat = 34
    static let compactCorner: CGFloat = 3
    static let standardCorner: CGFloat = 5
    /// Cross-arm thickness as a fraction of the shorter side.
    static let crossThickness: CGFloat = 0.20
    /// Nordic cross offset from centre as a fraction of width.
    static let nordicOffset: CGFloat = 0.14
    /// Centred-disc diameter as a fraction of height.
    static let discDiameter: CGFloat = 0.62
    /// Canton size as a fraction of width / height.
    static let cantonWidth: CGFloat = 0.42
    static let cantonHeight: CGFloat = 0.54
}

// MARK: - Flag arrangement

/// The geometric recipe for a flag. Every case carries the resolved colours so
/// rendering never has to reach back into the catalog.
enum FlagArrangement: Equatable {
    case verticalTricolor(Color, Color, Color)
    case horizontalTricolor(Color, Color, Color)
    case verticalBicolor(Color, Color)
    case horizontalBicolor(Color, Color)
    /// Centred upright cross (St George, Switzerland). field, cross.
    case uprightCross(field: Color, cross: Color)
    /// Off-centre Scandinavian cross. field, cross.
    case nordicCross(field: Color, cross: Color)
    /// Solid field with a centred disc (approximates crescent/star/sun emblems).
    case centeredDisc(field: Color, disc: Color)
    /// Two triangles split along the leading diagonal.
    case diagonalSplit(Color, Color)
    /// Three horizontal stripes (alternating) with a top-leading canton.
    case stripesWithCanton(stripe: Color, alt: Color, canton: Color)
    /// Plain field with a single bottom band (neutral fallback / minimal flags).
    case plainWithBand(field: Color, band: Color)
}

/// A resolved flag design plus whether it came from the safety fallback.
struct FlagDesign: Equatable {
    let arrangement: FlagArrangement
    /// True only when `flagAsset` had no explicit mapping and the design was
    /// synthesised from the team's two primary colours.
    var isFallback: Bool = false
}

// MARK: - Catalog

/// Resolves a `NationalTeamDefinition` to a drawable `FlagDesign`. Pure and
/// testable — no SwiftUI needed to exercise it.
enum FlagCatalog {

    /// Every `flagAsset` with an explicit, hand-tuned arrangement. Used by the
    /// catalog switch and by tests to guarantee full coverage of the 48 teams.
    static let explicitFlagAssets: Set<String> = [
        "flag_tr", "flag_de", "flag_fr", "flag_br", "flag_ar", "flag_es",
        "flag_gb", "flag_it", "flag_nl", "flag_pt", "flag_be", "flag_hr",
        "flag_uy", "flag_co", "flag_mx", "flag_us", "flag_ma", "flag_sn",
        "flag_jp", "flag_kr", "flag_ir", "flag_au", "flag_gr", "flag_hu",
        "flag_dk", "flag_se", "flag_pl", "flag_at", "flag_ch", "flag_rs",
        "flag_ua", "flag_cz", "flag_no", "flag_eg", "flag_ng", "flag_cm",
        "flag_cl", "flag_ec", "flag_pe", "flag_py", "flag_ca", "flag_cr",
        "flag_gh", "flag_ci", "flag_dz", "flag_tn", "flag_sa", "flag_qa",
    ]

    /// Resolves the flag design for a team. Falls back to a two-band design for
    /// any unmapped asset so the UI is never empty.
    static func design(for team: NationalTeamDefinition) -> FlagDesign {
        let p = team.primaryColor
        let s = team.secondaryColor
        let t = team.tertiaryColor
        guard let arrangement = arrangement(for: team.flagAsset, p: p, s: s, t: t) else {
            return FlagDesign(arrangement: .plainWithBand(field: p, band: s), isFallback: true)
        }
        return FlagDesign(arrangement: arrangement)
    }

    // Colours are always sourced from the team; only the geometry is per-flag.
    private static func arrangement(for flagAsset: String, p: Color, s: Color, t: Color) -> FlagArrangement? {
        switch flagAsset {
        // Pot 1
        case "flag_tr": return .centeredDisc(field: p, disc: s)
        case "flag_de": return .horizontalTricolor(p, s, t)
        case "flag_fr": return .verticalTricolor(p, t, s)
        case "flag_br": return .centeredDisc(field: p, disc: s)
        case "flag_ar": return .horizontalTricolor(p, s, p)
        case "flag_es": return .horizontalTricolor(p, s, p)
        case "flag_gb": return .uprightCross(field: p, cross: s)      // England — St George, via flagAsset not ISO
        case "flag_it": return .verticalTricolor(p, s, t)
        case "flag_nl": return .horizontalTricolor(p, s, p)
        case "flag_pt": return .verticalBicolor(p, s)
        case "flag_be": return .verticalTricolor(p, s, t)
        case "flag_hr": return .horizontalTricolor(p, s, t)
        // Pot 2
        case "flag_uy": return .stripesWithCanton(stripe: s, alt: p, canton: t)
        case "flag_co": return .horizontalTricolor(p, s, t)
        case "flag_mx": return .verticalTricolor(p, s, t)
        case "flag_us": return .stripesWithCanton(stripe: s, alt: t, canton: p)
        case "flag_ma": return .centeredDisc(field: p, disc: s)
        case "flag_sn": return .verticalTricolor(p, s, t)
        case "flag_jp": return .centeredDisc(field: s, disc: p)
        case "flag_kr": return .centeredDisc(field: p, disc: s)
        case "flag_ir": return .horizontalTricolor(p, s, t)
        case "flag_au": return .diagonalSplit(p, s)
        case "flag_gr": return .stripesWithCanton(stripe: s, alt: p, canton: p)
        case "flag_hu": return .horizontalTricolor(p, s, t)
        // Pot 3
        case "flag_dk": return .nordicCross(field: p, cross: s)
        case "flag_se": return .nordicCross(field: p, cross: s)
        case "flag_pl": return .horizontalBicolor(p, s)
        case "flag_at": return .horizontalTricolor(p, s, p)
        case "flag_ch": return .uprightCross(field: p, cross: s)
        case "flag_rs": return .horizontalTricolor(p, s, t)
        case "flag_ua": return .horizontalBicolor(p, s)
        case "flag_cz": return .diagonalSplit(t, s)
        case "flag_no": return .nordicCross(field: p, cross: s)
        case "flag_eg": return .horizontalTricolor(p, s, t)
        case "flag_ng": return .verticalTricolor(p, s, p)
        case "flag_cm": return .verticalTricolor(p, s, t)
        // Pot 4
        case "flag_cl": return .stripesWithCanton(stripe: t, alt: p, canton: s)
        case "flag_ec": return .horizontalTricolor(p, s, t)
        case "flag_pe": return .verticalTricolor(p, s, p)
        case "flag_py": return .horizontalTricolor(p, t, s)
        case "flag_ca": return .verticalTricolor(p, s, p)
        case "flag_cr": return .horizontalTricolor(p, t, s)
        case "flag_gh": return .horizontalTricolor(p, s, t)
        case "flag_ci": return .verticalTricolor(p, t, s)
        case "flag_dz": return .verticalBicolor(p, s)
        case "flag_tn": return .centeredDisc(field: p, disc: s)
        case "flag_sa": return .plainWithBand(field: p, band: s)
        case "flag_qa": return .verticalBicolor(p, s)
        default: return nil
        }
    }
}

// MARK: - View

/// Renders a national team's flag as a geometric SwiftUI drawing. Never empty:
/// unmapped assets fall back to a two-band design.
struct NationalFlagView: View {
    let team: NationalTeamDefinition
    var style: NationalFlagStyle = .standard

    var body: some View {
        let design = FlagCatalog.design(for: team)
        FlagArrangementShape(arrangement: design.arrangement)
            .frame(height: style.defaultHeight)
            .frame(width: style.defaultHeight * NationalFlagMetrics.aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                    .stroke(Palette.borderStrong.opacity(0.55), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey(team.nameKey)))
    }
}

/// The Canvas-free drawing of a `FlagArrangement`, laid out to fill its frame.
private struct FlagArrangementShape: View {
    let arrangement: FlagArrangement

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                switch arrangement {
                case let .verticalTricolor(a, b, c):
                    HStack(spacing: 0) { band(a); band(b); band(c) }

                case let .horizontalTricolor(a, b, c):
                    VStack(spacing: 0) { band(a); band(b); band(c) }

                case let .verticalBicolor(a, b):
                    HStack(spacing: 0) { band(a); band(b) }

                case let .horizontalBicolor(a, b):
                    VStack(spacing: 0) { band(a); band(b) }

                case let .uprightCross(field, cross):
                    field
                    upright(cross, w: w, h: h, centerX: w / 2)

                case let .nordicCross(field, cross):
                    field
                    upright(cross, w: w, h: h, centerX: w * (0.5 - NationalFlagMetrics.nordicOffset))

                case let .centeredDisc(field, disc):
                    field
                    Circle().fill(disc)
                        .frame(width: h * NationalFlagMetrics.discDiameter,
                               height: h * NationalFlagMetrics.discDiameter)

                case let .diagonalSplit(a, b):
                    a
                    Path { p in
                        p.move(to: .zero)
                        p.addLine(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: 0, y: h))
                        p.closeSubpath()
                    }.fill(b)

                case let .stripesWithCanton(stripe, alt, canton):
                    VStack(spacing: 0) { band(stripe); band(alt); band(stripe) }
                    canton
                        .frame(width: w * NationalFlagMetrics.cantonWidth,
                               height: h * NationalFlagMetrics.cantonHeight)
                        .position(x: w * NationalFlagMetrics.cantonWidth / 2,
                                  y: h * NationalFlagMetrics.cantonHeight / 2)

                case let .plainWithBand(field, band):
                    field
                    band.frame(height: h / 3).position(x: w / 2, y: h - h / 6)
                }
            }
            .frame(width: w, height: h)
        }
    }

    /// One equal flexible band (used inside H/VStacks).
    private func band(_ color: Color) -> some View {
        color.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// An upright (vertical + horizontal) cross centred on `centerX`.
    private func upright(_ color: Color, w: CGFloat, h: CGFloat, centerX: CGFloat) -> some View {
        let arm = min(w, h) * NationalFlagMetrics.crossThickness
        return ZStack {
            color.frame(width: arm, height: h).position(x: centerX, y: h / 2)
            color.frame(width: w, height: arm).position(x: w / 2, y: h / 2)
        }
    }
}

#Preview {
    let store = NationalTeamStore()
    return ScrollView {
        VStack(spacing: Spacing.s) {
            ForEach(store.allTeams) { team in
                HStack(spacing: Spacing.m) {
                    NationalFlagView(team: team, style: .compact)
                    NationalFlagView(team: team, style: .standard)
                    Text(LocalizedStringKey(team.nameKey))
                        .font(.sectionLabel)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, Spacing.m)
            }
        }
        .padding(.vertical, Spacing.l)
    }
    .background(Palette.bgPrimary)
    .preferredColorScheme(.dark)
}
