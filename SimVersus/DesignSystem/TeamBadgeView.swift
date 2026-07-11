//  TeamBadgeView.swift
//  DesignSystem
//
//  Parametric team logo (DESIGN_TOKENS §TeamBadgeView). A shield filled with the
//  team's primary colour, an outer contour and an abstract inner symbol in the
//  secondary colour, and the short code below. Pure vector (Path/Shape) — no
//  asset images, so it stays sharp at any size. Never draws animal or real-club
//  emblems; the five symbols are strictly geometric.

import SwiftUI

struct TeamBadgeView: View {
    let team: Team
    /// Shield width in points. The overall view is a little taller (shield +
    /// short code beneath it).
    let size: CGFloat

    private var shieldHeight: CGFloat { size * 1.12 }
    private var strokeWidth: CGFloat { max(1.5, size * 0.04) }

    var body: some View {
        VStack(spacing: size * 0.08) {
            ZStack {
                ShieldShape()
                    .fill(team.primaryColor)
                KitPatternShape(pattern: team.pattern)
                    .fill(team.secondaryColor)
                    .clipShape(ShieldShape())
                ShieldShape()
                    .strokeBorder(team.secondaryColor, lineWidth: strokeWidth)
                BadgeSymbolShape(shape: team.badgeShape)
                    .fill(team.secondaryColor, style: FillStyle(eoFill: true))
                    .frame(width: size * 0.46, height: size * 0.46)
                    .offset(y: -shieldHeight * 0.06)
            }
            .frame(width: size, height: shieldHeight)

            Text(team.short)
                .font(.badgeCode(size: size * 0.2))
                .foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(team.nameKey)))
    }
}

// MARK: - Shield

/// Heraldic shield: flat top with rounded shoulders, straight sides, tapering to
/// a rounded point at the bottom centre.
struct ShieldShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let corner = r.width * 0.14
        var p = Path()
        p.move(to: CGPoint(x: r.minX + corner, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - corner, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + corner),
                       control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.5))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY),
                       control: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.12))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.5),
                       control: CGPoint(x: r.minX, y: r.maxY - r.height * 0.12))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + corner))
        p.addQuadCurve(to: CGPoint(x: r.minX + corner, y: r.minY),
                       control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

// MARK: - Inner symbols

/// The five abstract inner symbols, each drawn to fill its frame. Filled with
/// the even-odd rule (needed for the `ring`; harmless for the rest).
struct BadgeSymbolShape: Shape {
    let shape: BadgeShape

    func path(in rect: CGRect) -> Path {
        switch shape {
        case .star: return Self.star(in: rect)
        case .chevron: return Self.chevron(in: rect)
        case .wave: return Self.wave(in: rect)
        case .diamond: return Self.diamond(in: rect)
        case .ring: return Self.ring(in: rect)
        }
    }

    private static func star(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.42
        let points = 5
        for i in 0 ..< points * 2 {
            let radius = i.isMultiple(of: 2) ? outer : inner
            let angle = -CGFloat.pi / 2 + CGFloat(i) * .pi / CGFloat(points)
            let pt = CGPoint(x: c.x + radius * cos(angle), y: c.y + radius * sin(angle))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }

    private static func chevron(in rect: CGRect) -> Path {
        let t = rect.width * 0.30   // horizontal thickness
        let hIn = rect.height * 0.46 // inner-apex drop
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + hIn))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }

    private static func wave(in rect: CGRect) -> Path {
        let amp = rect.height * 0.16
        let thick = rect.height * 0.28
        let baseY = rect.midY - thick / 2
        let steps = 48
        var p = Path()
        for i in 0 ... steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = baseY + sin(CGFloat(i) / CGFloat(steps) * .pi * 2) * amp
            i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = baseY + thick + sin(CGFloat(i) / CGFloat(steps) * .pi * 2) * amp
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.closeSubpath()
        return p
    }

    private static func diamond(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }

    private static func ring(in rect: CGRect) -> Path {
        let outer = min(rect.width, rect.height)
        let inner = outer * 0.56
        var p = Path()
        p.addEllipse(in: CGRect(x: rect.midX - outer / 2, y: rect.midY - outer / 2,
                                width: outer, height: outer))
        p.addEllipse(in: CGRect(x: rect.midX - inner / 2, y: rect.midY - inner / 2,
                                width: inner, height: inner))
        return p
    }
}

#Preview {
    ZStack {
        Palette.bgPrimary.ignoresSafeArea()
        LazyVGrid(columns: Array(repeating: GridItem(), count: 3), spacing: Spacing.l) {
            ForEach(TeamStore().mvpTeams) { team in
                TeamBadgeView(team: team, size: 84)
            }
        }
        .padding()
    }
}
