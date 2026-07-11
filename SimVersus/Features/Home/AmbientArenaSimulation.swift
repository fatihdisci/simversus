//  AmbientArenaSimulation.swift
//  Features/Home
//
//  A tiny, self-contained physics loop for the Home hero: a single neutral
//  ball bouncing inside a rotating circular ring. Purely decorative — no
//  teams, no goals, no score, no power-ups.
//
//  The vector helpers and the integrate / speed-normalize / disc-disc collide /
//  wall-bounce math are deliberately mirrored from `MatchSimulation.swift` and
//  kept duplicated here: the match engine is the deterministic, unit-tested
//  heart of the game (CONSTITUTION §11) and must not be touched for a cosmetic
//  backdrop. The ambient loop also wants different physics anyway (perfect
//  restitution, no damping, no RNG), so sharing would be a poor fit.

import CoreGraphics
import Foundation

// MARK: - Vector helpers (CGPoint used as a 2D vector)

private extension CGPoint {
    static func + (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x + r.x, y: l.y + r.y) }
    static func - (l: CGPoint, r: CGPoint) -> CGPoint { CGPoint(x: l.x - r.x, y: l.y - r.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }
    var length: CGFloat { (x * x + y * y).squareRoot() }
    func dot(_ o: CGPoint) -> CGFloat { x * o.x + y * o.y }
    var normalized: CGPoint { let l = length; return l > 0 ? CGPoint(x: x / l, y: y / l) : .zero }
}

// MARK: - Ball

/// A neutral orb. No team, no badge — just a coloured circle with a short trail.
struct AmbientBall {
    var position: CGPoint
    var velocity: CGPoint
    let radius: CGFloat
    let mass: CGFloat
    let targetSpeed: CGFloat
    /// Index into the renderer's neutral palette (energy / accent / info).
    let colorIndex: Int

    /// Fixed-capacity ring buffer of recent positions for the fading trail.
    /// Pre-allocated once; written in place so `step()` never allocates.
    var trail: [CGPoint]
    var trailHead: Int = 0
    var trailCount: Int = 0

    init(position: CGPoint, velocity: CGPoint, radius: CGFloat, colorIndex: Int) {
        self.position = position
        self.velocity = velocity
        self.radius = radius
        // Heavier orbs feel weightier in a collision (area-proportional mass).
        self.mass = radius * radius / (AmbientArenaSimulation.Constants.baseRadius * AmbientArenaSimulation.Constants.baseRadius)
        self.colorIndex = colorIndex
        self.targetSpeed = AmbientArenaSimulation.Constants.targetSpeed
        self.trail = Array(repeating: position, count: AmbientArenaSimulation.Constants.trailCapacity)
    }

    /// Records the current position into the ring buffer (no allocation).
    mutating func sampleTrail() {
        trail[trailHead] = position
        trailHead = (trailHead + 1) % trail.count
        if trailCount < trail.count { trailCount += 1 }
    }

    /// Visits trail points oldest → newest with a 0...1 age (0 = oldest kept).
    func forEachTrailPoint(_ body: (_ point: CGPoint, _ age: CGFloat) -> Void) {
        guard trailCount > 1 else { return }
        let capacity = trail.count
        // Oldest kept sample sits `trailCount` steps behind the head.
        let start = (trailHead - trailCount + capacity) % capacity
        for i in 0..<trailCount {
            let idx = (start + i) % capacity
            let age = CGFloat(i) / CGFloat(trailCount - 1)
            body(trail[idx], age)
        }
    }
}

// MARK: - Simulation

/// Drives the Home hero backdrop. A plain reference type (intentionally NOT
/// `@Observable`): it is mutated once per frame from inside the `Canvas` draw
/// closure, and only `TimelineView` should schedule redraws — observing it would
/// double the work by also invalidating the view body every frame.
final class AmbientArenaSimulation {

    enum Constants {
        /// Arena radius in fixed sim units. The renderer scales this to points.
        static let simRadius: CGFloat = 100
        static let baseRadius: CGFloat = 11

        /// Fixed physics step and the per-frame budget — mirrors `MatchScene`
        /// so a hitch or a resume can never trigger a catch-up burst.
        static let fixedStep: TimeInterval = 1.0 / 120.0
        static let maxStepsPerFrame = 4
        static let maxFrameDelta: TimeInterval = 1.0 / 20.0

        /// Single orb radius (sim units).
        static let ballRadius: CGFloat = 13
        /// Brisk cruising speed (sim units/s) — an arena crossing takes ~2–3 s.
        static let targetSpeed: CGFloat = 50
        /// Gentle blend back toward the cruising speed (softer than the match).
        static let speedBlend: CGFloat = 0.03
        /// Perfectly elastic — energy-neutral, so motion never dies down.
        static let restitution: CGFloat = 1.0
        /// Tiny inset off the wall to avoid re-colliding on the next step.
        static let wallInset: CGFloat = 0.5

        /// Decorative ring rotation (rad/s). The dashed ring and the notches
        /// spin at different rates for cheap parallax depth.
        static let dashRingSpeed: CGFloat = 0.32
        static let notchSpeed: CGFloat = 0.13

        static let trailCapacity = 12
        /// Sample the trail every N steps → ~40 samples/s → ~0.3 s streak.
        static let trailSampleEveryNSteps = 3
    }

    private(set) var balls: [AmbientBall]
    private(set) var dashAngle: CGFloat = 0
    private(set) var notchAngle: CGFloat = 0

    private var lastDate: Date?
    private var accumulator: TimeInterval = 0
    private var stepCounter = 0

    init() {
        // Deterministic starting position (no RNG): one orb launched tangentially
        // from a mid-radius circle. This doubles as the static Reduce-Motion
        // frame, so it is composed to look good at rest. A circular billiard
        // launched off-tangent never retraces the same chord, so a single ball
        // still reads as lively rather than orbiting in a fixed loop.
        let spawnRadius = Constants.simRadius * 0.55
        let angle = -CGFloat.pi / 2
        let position = CGPoint(x: cos(angle) * spawnRadius, y: sin(angle) * spawnRadius)
        let tangent = CGPoint(x: -sin(angle), y: cos(angle))
        let velocity = tangent * Constants.targetSpeed
        balls = [AmbientBall(position: position,
                             velocity: velocity,
                             radius: Constants.ballRadius,
                             colorIndex: 1)]
    }

    /// Call when unpausing so the first resumed frame has dt = 0 (no teleport
    /// from the wall-clock gap that accrued while paused).
    func resetClock() {
        lastDate = nil
    }

    /// Advances the simulation to `date` using a fixed-timestep accumulator.
    func advance(to date: Date) {
        let dt = min(date.timeIntervalSince(lastDate ?? date), Constants.maxFrameDelta)
        lastDate = date

        accumulator += dt
        var steps = 0
        while accumulator >= Constants.fixedStep, steps < Constants.maxStepsPerFrame {
            step(CGFloat(Constants.fixedStep))
            accumulator -= Constants.fixedStep
            steps += 1
        }
        // Drop leftover debt beyond one frame's budget: a sustained slow stretch
        // can never build an ever-growing catch-up queue.
        accumulator = min(accumulator, Constants.fixedStep * Double(Constants.maxStepsPerFrame))
    }

    // MARK: One fixed step

    private func step(_ fdt: CGFloat) {
        for i in balls.indices {
            integrate(&balls[i], fdt: fdt)
            normalizeSpeed(&balls[i])
        }

        // Pairwise elastic collisions. A no-op today (single ball, zero pairs);
        // kept generic so a future formation change is a data-only edit.
        for a in 0..<balls.count {
            for b in (a + 1)..<balls.count {
                collide(a, b)
            }
        }

        for i in balls.indices {
            bounceOffWall(&balls[i])
        }

        stepCounter += 1
        if stepCounter % Constants.trailSampleEveryNSteps == 0 {
            for i in balls.indices { balls[i].sampleTrail() }
        }

        let twoPi: CGFloat = 2 * .pi
        dashAngle = (dashAngle + Constants.dashRingSpeed * fdt).truncatingRemainder(dividingBy: twoPi)
        notchAngle = (notchAngle + Constants.notchSpeed * fdt).truncatingRemainder(dividingBy: twoPi)
    }

    private func integrate(_ ball: inout AmbientBall, fdt: CGFloat) {
        // No linear damping: perfect restitution keeps the system energy-neutral.
        ball.position = ball.position + ball.velocity * fdt
    }

    /// Blends speed toward the cruising target while preserving direction — the
    /// same trick the match engine uses to keep motion lively and bounded.
    private func normalizeSpeed(_ ball: inout AmbientBall) {
        let speed = ball.velocity.length
        guard speed > 0.01 else { return }
        let newSpeed = speed + (ball.targetSpeed - speed) * Constants.speedBlend
        ball.velocity = ball.velocity.normalized * newSpeed
    }

    /// Elastic disc-disc collision with positional correction (mirrors
    /// `MatchSimulation.collide`).
    private func collide(_ i: Int, _ j: Int) {
        var a = balls[i], b = balls[j]
        let delta = b.position - a.position
        let dist = delta.length
        let minDist = a.radius + b.radius
        guard dist < minDist, dist > 0.0001 else { return }

        let n = delta * (1 / dist)
        let invA = 1 / a.mass, invB = 1 / b.mass, totalInv = invA + invB

        let overlap = minDist - dist
        a.position = a.position - n * (overlap * invA / totalInv)
        b.position = b.position + n * (overlap * invB / totalInv)

        let relativeVelocity = b.velocity - a.velocity
        let velocityAlongNormal = relativeVelocity.dot(n)
        if velocityAlongNormal < 0 {
            let impulse = n * (-(1 + Constants.restitution) * velocityAlongNormal / totalInv)
            a.velocity = a.velocity - impulse * invA
            b.velocity = b.velocity + impulse * invB
        }
        balls[i] = a
        balls[j] = b
    }

    /// Perfect reflection off the circular wall (no gap, no goal). Simpler than
    /// the match version because ambient speeds never need the separation floor
    /// or tangential damping the gameplay wall uses.
    private func bounceOffWall(_ ball: inout AmbientBall) {
        let dist = ball.position.length
        let boundary = Constants.simRadius - ball.radius
        guard dist > boundary, dist > 0.0001 else { return }

        let inwardNormal = ball.position * (-1 / dist)
        let velocityAlongNormal = ball.velocity.dot(inwardNormal)
        if velocityAlongNormal < 0 {
            ball.velocity = ball.velocity - inwardNormal * ((1 + Constants.restitution) * velocityAlongNormal)
        }
        let separated = max(0, boundary - Constants.wallInset)
        ball.position = ball.position * (separated / dist)
    }

    #if DEBUG
    /// Test hook: advance exactly one fixed step (used by AmbientArenaTests).
    func stepOnceForTesting() { step(CGFloat(Constants.fixedStep)) }
    #endif
}
