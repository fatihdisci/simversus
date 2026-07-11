//  Spacing.swift
//  DesignSystem
//
//  8-point spacing grid, corner radii and layout constants (DESIGN_TOKENS.md).

import CoreGraphics

/// 8-point spacing grid. Layout gaps are multiples of the base unit
/// (a single 4pt half-step, `xs`, is allowed for tight groupings).
enum Spacing {
    /// Base grid unit — 8pt.
    static let unit: CGFloat = 8

    static let xs: CGFloat = 4    // 0.5×
    static let s: CGFloat = 8     // 1×
    static let m: CGFloat = 16    // 2×
    static let l: CGFloat = 24    // 3×
    static let xl: CGFloat = 32   // 4×
    static let xxl: CGFloat = 48  // 6×
}

/// Corner radii (DESIGN_TOKENS.md).
enum Radius {
    /// Large hero panels.
    static let hero: CGFloat = 28
    /// Cards / sheets.
    static let card: CGFloat = 20
    /// Buttons.
    static let button: CGFloat = 14
    /// Badges.
    static let badge: CGFloat = 12
    /// Pills and status capsules.
    static let pill: CGFloat = 999
}

/// Layout constants.
enum Layout {
    /// Minimum touch-target size (Apple HIG / DESIGN_TOKENS.md).
    static let minTouchTarget: CGFloat = 44

    // MARK: Call-to-action

    /// Standard height of a hero CTA (Maçı Başlat / Başlama Vuruşu / Rövanş).
    /// Every primary and secondary CTA shares it so buttons never drift per screen.
    static let ctaMinHeight: CGFloat = 56
    /// Balanced horizontal inset for CTA content — keeps the leading label off the
    /// left edge and the trailing icon off the right edge instead of hugging them.
    static let ctaContentPadding: CGFloat = Spacing.l
    /// Diameter of a CTA's trailing icon accessory. Sized to the button height so
    /// the icon reads as an intentional accessory, not a glyph pinned to the edge.
    static let ctaAccessory: CGFloat = 30
    /// Point size of the glyph inside the trailing accessory.
    static let ctaAccessoryIcon: CGFloat = 15
}
