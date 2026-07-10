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
    /// Cards / sheets.
    static let card: CGFloat = 16
    /// Buttons.
    static let button: CGFloat = 14
    /// Badges.
    static let badge: CGFloat = 12
}

/// Layout constants.
enum Layout {
    /// Minimum touch-target size (Apple HIG / DESIGN_TOKENS.md).
    static let minTouchTarget: CGFloat = 44
}
