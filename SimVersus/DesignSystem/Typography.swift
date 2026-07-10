//  Typography.swift
//  DesignSystem
//
//  Font role tokens (DESIGN_TOKENS.md). No font may be defined outside this
//  file. Use via the leading-dot syntax, e.g. `.font(.scoreboard)`.

import SwiftUI

extension Font {
    /// Scoreboard — SF Pro Rounded, 34pt heavy, monospaced digits.
    /// Used for the live score and clock so counters never jump width.
    static let scoreboard = Font.system(size: 34, weight: .heavy, design: .rounded)
        .monospacedDigit()

    /// Extra-large title — SF Pro Rounded, 28pt bold. Screen titles / wordmark.
    static let titleXL = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Label / short code — SF Mono, 13pt semibold. Badges, tags, short codes.
    static let label = Font.system(size: 13, weight: .semibold, design: .monospaced)

    /// Badge short-code — SF Mono semibold, sized to the badge (`TeamBadgeView`).
    /// Scales with the badge so it stays crisp and proportional at any size.
    static func badgeCode(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // Body text intentionally reuses the built-in `Font.body` (SF Pro, 17pt
    // regular, Dynamic Type), which already matches the DESIGN_TOKENS body role.
    // It is not redefined here because `Font.body` cannot be overridden.
}
