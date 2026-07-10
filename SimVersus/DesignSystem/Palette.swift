//  Palette.swift
//  DesignSystem
//
//  Single source of truth for colour tokens (DESIGN_TOKENS.md).
//  No colour may be defined outside this file. Team colours are the only
//  exception and always come from teams.json (Part 1b), never from here.

import SwiftUI

// MARK: - Hex initialiser

extension Color {
    /// Creates a colour from a hex string.
    ///
    /// Accepts `"#RRGGBB"`, `"RRGGBB"`, `"#RRGGBBAA"` or `"RRGGBBAA"`.
    /// Invalid input falls back to opaque black so a typo is visible rather
    /// than crashing.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6: // RRGGBB
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        case 8: // RRGGBBAA
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Colour tokens

/// The SimVersus colour palette — "stadium night match": dark ground, bright
/// arena, UI recedes. Every UI colour comes from one of these tokens.
enum Palette {
    /// `bg.primary` — main dark ground.
    static let bgPrimary = Color(hex: "#0E1116")
    /// `bg.elevated` — cards, sheets.
    static let bgElevated = Color(hex: "#171C24")
    /// `bg.arena` — match scene floor (MVP flat background).
    static let bgArena = Color(hex: "#101820")

    /// `arena.wall` — arena ring stroke.
    static let arenaWall = Color(hex: "#2A3442")
    /// `arena.line` — centre line and markings.
    static let arenaLine = Color(hex: "#3A4656")

    /// `text.primary` — primary text.
    static let textPrimary = Color(hex: "#F2F4F7")
    /// `text.secondary` — secondary / muted text.
    static let textSecondary = Color(hex: "#9AA4B2")

    /// `accent` — CTAs, live-score highlight ("grass-green neon").
    static let accent = Color(hex: "#38E07B")
    /// `accent.warning` — warnings, cautions.
    static let accentWarning = Color(hex: "#F2C230")
    /// `danger` — destructive / error.
    static let danger = Color(hex: "#E5484D")

    /// `goal.flash` — full-screen flash on a goal (white at 85%).
    static let goalFlash = Color(hex: "#FFFFFF").opacity(0.85)
}
