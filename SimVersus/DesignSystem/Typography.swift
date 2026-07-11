//  Typography.swift
//  DesignSystem
//
//  Font role tokens (DESIGN_TOKENS.md). No font may be defined outside this
//  file. Use via the leading-dot syntax, e.g. `.font(.scoreboard)`.

import SwiftUI

extension Font {
    /// Brand/hero display role.
    static let display = Font.system(size: 42, weight: .black, design: .rounded)

    /// Large screen title.
    static let screenTitle = Font.system(size: 32, weight: .bold, design: .rounded)

    /// Scoreboard — SF Pro Rounded, 34pt heavy, monospaced digits.
    /// Used for the live score and clock so counters never jump width.
    static let scoreboard = Font.system(size: 34, weight: .heavy, design: .rounded)
        .monospacedDigit()

    /// Final score hero.
    static let finalScore = Font.system(size: 56, weight: .black, design: .rounded)
        .monospacedDigit()

    /// Extra-large title — SF Pro Rounded, 28pt bold. Screen titles / wordmark.
    static let titleXL = Font.system(size: 28, weight: .bold, design: .rounded)

    /// Card and section headline.
    static let headline = Font.system(size: 20, weight: .bold, design: .rounded)

    /// Strong button label.
    static let button = Font.system(size: 18, weight: .bold, design: .rounded)

    /// Human-readable section label; mono is reserved for live data.
    static let sectionLabel = Font.system(size: 15, weight: .semibold, design: .rounded)

    /// Supporting copy and compact metadata.
    static let caption = Font.system(size: 12, weight: .medium, design: .rounded)

    /// Compact separator used between two live match scores.
    static let scoreSeparator = Font.system(size: 24, weight: .bold, design: .rounded)

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
