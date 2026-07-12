//  AmbientArenaView.swift
//  Features/Home
//
//  The Home hero backdrop: a rotating neon ring with a few neutral orbs
//  bouncing inside it. Rendered with a single `Canvas` driven by
//  `TimelineView(.animation)`. Purely decorative — see AmbientArenaSimulation.

import SwiftUI

struct AmbientArenaView: View {
    /// Side length of the square canvas. Adaptive: Home shrinks it on short
    /// screens so the action card stays fully visible without losing the brand.
    var size: CGFloat = Layout.heroArenaRegular

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var simulation = AmbientArenaSimulation()
    @State private var isVisible = true

    /// Stop ticking when off-screen, backgrounded, or Reduce Motion is on. A
    /// paused schedule produces zero frames (no battery cost) but still renders
    /// one static frame — which is exactly the Reduce-Motion fallback.
    private var isPaused: Bool {
        reduceMotion || !isVisible || scenePhase != .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isPaused)) { timeline in
            Canvas { context, size in
                if !isPaused {
                    simulation.advance(to: timeline.date)
                }
                AmbientArenaRenderer.draw(simulation, into: context, size: size)
            }
        }
        .frame(width: size, height: size)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .onChange(of: isPaused) { _, paused in
            // Reset the sim clock on resume so the first frame's dt is ~0 and
            // the balls don't teleport by the wall-clock gap spent paused.
            if !paused { simulation.resetClock() }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Renderer

private enum AmbientArenaRenderer {
    /// Ring radius as a fraction of the canvas side, so the arena scales with the
    /// frame. Chosen (108/250) so the widest glow stroke and a ball's halo at the
    /// wall both stay inside the frame at any size.
    static let ringRadiusFraction: CGFloat = 108.0 / 250.0

    /// Neutral orb palette — identity colours, never team colours. All three
    /// already tint `ArenaBackground`, so the composition harmonises.
    static let ballColors: [Color] = [Palette.energy, Palette.accent, Palette.info]

    static func draw(_ sim: AmbientArenaSimulation, into context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let ringRadius = min(size.width, size.height) * ringRadiusFraction
        let scale = ringRadius / AmbientArenaSimulation.Constants.simRadius

        drawVolumeFill(context, center: center, ringRadius: ringRadius)
        drawRingGlow(context, center: center, ringRadius: ringRadius)
        drawNotches(sim, context, center: center, ringRadius: ringRadius)
        drawDashedRing(sim, context, center: center, ringRadius: ringRadius)
        drawTrails(sim, context, center: center, scale: scale)
        drawBalls(sim, context, center: center, scale: scale)
    }

    // 1. Inner volume — a soft radial wash so the arena reads as a lit floor.
    private static func drawVolumeFill(_ context: GraphicsContext, center: CGPoint, ringRadius: CGFloat) {
        let rect = circleRect(center: center, radius: ringRadius)
        context.fill(
            Circle().path(in: rect),
            with: .radialGradient(Gradient(colors: [Palette.energy.opacity(0.045), .clear]),
                                  center: center, startRadius: 0, endRadius: ringRadius)
        )
    }

    // 2. Neon wall — stacked glow strokes (a whisper of the match-scene recipe).
    private static func drawRingGlow(_ context: GraphicsContext, center: CGPoint, ringRadius: CGFloat) {
        let path = Circle().path(in: circleRect(center: center, radius: ringRadius))
        context.stroke(path, with: .color(Palette.energy.opacity(0.04)), lineWidth: 14)
        context.stroke(path, with: .color(Palette.energy.opacity(0.08)), lineWidth: 8)
        context.stroke(path, with: .color(Palette.energy.opacity(0.16)), lineWidth: 4)
        context.stroke(path, with: .color(Palette.energy.opacity(0.65)), lineWidth: 2)
        context.stroke(path, with: .color(Palette.textPrimary.opacity(0.35)), lineWidth: 1)
    }

    // 3. Rotation notches — three short ticks on the wall so the (otherwise
    //    featureless) ring visibly rotates.
    private static func drawNotches(_ sim: AmbientArenaSimulation, _ context: GraphicsContext, center: CGPoint, ringRadius: CGFloat) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(Double(sim.notchAngle)))
        let color = Palette.textPrimary.opacity(0.28)
        for i in 0..<3 {
            let base = Double(i) * (2 * .pi / 3)
            var p = Path()
            p.addArc(center: .zero, radius: ringRadius,
                     startAngle: .radians(base), endAngle: .radians(base + 0.09), clockwise: false)
            layer.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    // 4. Rotating dashed inner ring — echoes the old hero's dashed circle and
    //    adds parallax depth (spins faster than the notches).
    private static func drawDashedRing(_ sim: AmbientArenaSimulation, _ context: GraphicsContext, center: CGPoint, ringRadius: CGFloat) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.rotate(by: .radians(Double(sim.dashAngle)))
        let r = ringRadius * 0.8
        layer.stroke(
            Circle().path(in: CGRect(x: -r, y: -r, width: r * 2, height: r * 2)),
            with: .color(Palette.accent.opacity(0.12)),
            style: StrokeStyle(lineWidth: 10, dash: [2, 14])
        )
    }

    // 5. Fading trails — additive so overlaps brighten like light.
    private static func drawTrails(_ sim: AmbientArenaSimulation, _ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        var layer = context
        layer.blendMode = .plusLighter
        for ball in sim.balls {
            let color = ballColors[ball.colorIndex]
            let rr = ball.radius * scale
            ball.forEachTrailPoint { point, age in
                let p = screenPoint(point, center: center, scale: scale)
                let alpha = 0.02 + 0.10 * age
                let radius = rr * (0.3 + 0.45 * age)
                layer.fill(Circle().path(in: circleRect(center: p, radius: radius)),
                           with: .color(color.opacity(Double(alpha))))
            }
        }
    }

    // 6 + 7. Ball halos (additive) then glossy bodies.
    private static func drawBalls(_ sim: AmbientArenaSimulation, _ context: GraphicsContext, center: CGPoint, scale: CGFloat) {
        var halo = context
        halo.blendMode = .plusLighter
        for ball in sim.balls {
            let color = ballColors[ball.colorIndex]
            let p = screenPoint(ball.position, center: center, scale: scale)
            let haloR = ball.radius * scale * 2.2
            halo.fill(
                Circle().path(in: circleRect(center: p, radius: haloR)),
                with: .radialGradient(Gradient(colors: [color.opacity(0.20), .clear]),
                                      center: p, startRadius: 0, endRadius: haloR)
            )
        }

        for ball in sim.balls {
            let color = ballColors[ball.colorIndex]
            let p = screenPoint(ball.position, center: center, scale: scale)
            let rr = ball.radius * scale
            let path = Circle().path(in: circleRect(center: p, radius: rr))
            context.fill(
                path,
                with: .radialGradient(
                    Gradient(stops: [
                        .init(color: Palette.textPrimary.opacity(0.9), location: 0),
                        .init(color: Palette.textPrimary.opacity(0.5), location: 0.35),
                        .init(color: color, location: 1)
                    ]),
                    center: p, startRadius: 0, endRadius: rr)
            )
            context.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1)
        }
    }

    // MARK: Helpers

    private static func screenPoint(_ p: CGPoint, center: CGPoint, scale: CGFloat) -> CGPoint {
        CGPoint(x: center.x + p.x * scale, y: center.y + p.y * scale)
    }

    private static func circleRect(center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

#Preview {
    ZStack {
        ArenaBackground()
        AmbientArenaView()
    }
    .preferredColorScheme(.dark)
}
