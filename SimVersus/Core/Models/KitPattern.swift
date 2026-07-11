//  KitPattern.swift
//  Core/Models
//
//  Abstract kit patterns painted over a team's primary colour with its secondary
//  colour. Strictly geometric (CONSTITUTION §4.2 brand-safety): stripes, checks,
//  diagonals, halves — never a club emblem. The pattern is expressed as a single
//  `Path` of the secondary-coloured regions, so the SAME definition renders in
//  SwiftUI (`TeamBadgeView`, via `Path`) and SpriteKit (`MatchScene` ball texture,
//  via `path.cgPath`). Consumers fill primary first, then this path with secondary,
//  clipped to the badge/ball outline.

import SwiftUI

enum KitPattern: String, Codable, CaseIterable {
    case solid
    case verticalStripes
    case horizontalStripes
    case checkered
    case diagonal
    case halves

    /// String-catalog key for the pattern's display name.
    var labelKey: String { "pattern.\(rawValue)" }

    /// The regions painted in the SECONDARY colour within `rect`. Empty for
    /// `.solid` (all primary). Drawn generously at the edges since every consumer
    /// clips to the badge/ball outline.
    func secondaryRegions(in rect: CGRect) -> Path {
        var p = Path()
        switch self {
        case .solid:
            break

        case .verticalStripes:
            let bands = 5
            let w = rect.width / CGFloat(bands)
            for i in stride(from: 1, to: bands, by: 2) {
                p.addRect(CGRect(x: rect.minX + CGFloat(i) * w, y: rect.minY, width: w, height: rect.height))
            }

        case .horizontalStripes:
            let bands = 5
            let h = rect.height / CGFloat(bands)
            for i in stride(from: 1, to: bands, by: 2) {
                p.addRect(CGRect(x: rect.minX, y: rect.minY + CGFloat(i) * h, width: rect.width, height: h))
            }

        case .checkered:
            let n = 4
            let w = rect.width / CGFloat(n)
            let h = rect.height / CGFloat(n)
            for row in 0..<n {
                for col in 0..<n where (row + col).isMultiple(of: 2) {
                    p.addRect(CGRect(x: rect.minX + CGFloat(col) * w,
                                     y: rect.minY + CGFloat(row) * h,
                                     width: w, height: h))
                }
            }

        case .diagonal:
            let band = (rect.width + rect.height) / 8
            let step = band * 2
            var offset = -rect.height
            while offset < rect.width + rect.height {
                p.move(to: CGPoint(x: rect.minX + offset, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + offset + band, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + offset + band - rect.height, y: rect.maxY))
                p.addLine(to: CGPoint(x: rect.minX + offset - rect.height, y: rect.maxY))
                p.closeSubpath()
                offset += step
            }

        case .halves:
            p.addRect(CGRect(x: rect.midX, y: rect.minY, width: rect.width / 2, height: rect.height))
        }
        return p
    }

    /// Core Graphics form of `secondaryRegions`, for SpriteKit/UIKit callers that
    /// don't work in SwiftUI's `Path` (e.g. the ball-texture renderer).
    func secondaryRegionsCGPath(in rect: CGRect) -> CGPath {
        secondaryRegions(in: rect).cgPath
    }
}

/// A `Shape` wrapper so the pattern can be filled and clipped in SwiftUI.
struct KitPatternShape: Shape {
    let pattern: KitPattern
    func path(in rect: CGRect) -> Path { pattern.secondaryRegions(in: rect) }
}
