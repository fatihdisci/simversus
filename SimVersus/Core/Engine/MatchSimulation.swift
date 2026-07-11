//  MatchSimulation.swift
//  Core/Engine
//
//  The deterministic heart of the match. A custom fixed-timestep 2D physics
//  simulation of TWO team balls (badge visuals) inside a rotating circular arena
//  with a SINGLE goal gap. Pure Swift (no SpriteKit) so it can be stepped
//  headlessly and reproducibly: same seed + same teams = same MatchResult
//  (CONSTITUTION §11). `MatchScene` renders this state; it does not drive it.
//
//  TWO-BALL SYSTEM: Each team has its own ball. Balls collide with each other and
//  the arena wall. A ball that goes out through the rotating gap (the goal) →
//  that ball's OWN team scores (football logic). Player discs are permanently
//  retired.

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

/// Which side a ball belongs to.
enum Side {
    case home, away
}

/// A moving circular body (a ball).
struct Disc {
    var position: CGPoint
    var velocity: CGPoint
    let radius: CGFloat
    let mass: CGFloat
    let restitution: CGFloat
    let linearDamping: CGFloat
    /// Cosmetic: current rotation of the disc (for badge texture spin).
    var angularVelocity: CGFloat = 0
    var rotation: CGFloat = 0
}

final class MatchSimulation {
    private let config: MatchConfig
    private var rng: SeededRandomNumberGenerator

    // Rendered state (read by MatchScene each frame).
    private(set) var homeBall: Disc
    private(set) var awayBall: Disc
    private(set) var arenaRotation: CGFloat = 0
    private(set) var homeScore = 0
    private(set) var awayScore = 0
    private(set) var isFinished = false

    private var matchClock: TimeInterval = 0
    private var goalsLog: [Goal] = []
    private var didHalfTime = false
    private var phase: Phase = .kickoff

    // Boost timers — per-ball countdown to next self-impulse.
    private var homeBoostTimer: TimeInterval
    private var awayBoostTimer: TimeInterval
    // Stall timers — per-ball accumulated time below stallSpeedThreshold.
    private var homeStallTimer: TimeInterval = 0
    private var awayStallTimer: TimeInterval = 0

    // Rotation direction changes (Mac-oto inspired).
    private var currentRotationSpeed: CGFloat = PhysicsConstants.arenaRotationSpeed
    private var nextRotationChangeTime: TimeInterval = 0

    // Collision events for visual effects (consumed by MatchScene each frame).
    private(set) var pendingCollisionEvents: [CollisionEvent] = []
    private var ballBallCollidedThisFrame = false
    private var ballWallCollidedThisFrame = false
    private var homeWallCollisionPoint: CGPoint = .zero
    private var awayWallCollisionPoint: CGPoint = .zero

    /// Lightweight collision event for the renderer.
    struct CollisionEvent {
        let position: CGPoint
        /// 0–1 intensity based on impact impulse.
        let intensity: CGFloat
        let isBallBall: Bool
    }

    private enum Phase: Equatable {
        case kickoff
        case playing
        case celebrating(remaining: TimeInterval)
        case halfTime(remaining: TimeInterval)
        case ended
    }

    init(config: MatchConfig) {
        self.config = config
        self.rng = SeededRandomNumberGenerator(seed: config.seed)

        self.homeBall = Disc(position: .zero, velocity: .zero,
                             radius: PhysicsConstants.ballRadius, mass: PhysicsConstants.ballMass,
                             restitution: PhysicsConstants.ballToBallRestitution,
                             linearDamping: PhysicsConstants.ballLinearDamping)
        self.awayBall = Disc(position: .zero, velocity: .zero,
                             radius: PhysicsConstants.ballRadius, mass: PhysicsConstants.ballMass,
                             restitution: PhysicsConstants.ballToBallRestitution,
                             linearDamping: PhysicsConstants.ballLinearDamping)

        self.homeBoostTimer = Self.nextBoostInterval(using: &rng)
        self.awayBoostTimer = Self.nextBoostInterval(using: &rng)
        self.nextRotationChangeTime = TimeInterval(CGFloat.random(in: PhysicsConstants.rotationChangeIntervalRange, using: &rng))

        resetFormation()
    }

    // MARK: Public read-only state

    var displayMinute: Int {
        min(Int(config.duration), max(1, Int(matchClock) + 1))
    }

    var isFirstHalf: Bool { matchClock < config.duration / 2 }

    func result() -> MatchResult? {
        guard isFinished else { return nil }
        return MatchResult(homeTeamID: config.homeTeam.id, awayTeamID: config.awayTeam.id,
                           homeScore: homeScore, awayScore: awayScore, goals: goalsLog)
    }

    /// Steps the simulation to the final whistle and returns the result. Used by
    /// tests to run a full match headlessly and fast.
    func runToCompletion() -> MatchResult {
        let maxSteps = Int(config.duration / PhysicsConstants.fixedTimeStep) * 8 + 100_000
        var steps = 0
        while !isFinished && steps < maxSteps {
            step()
            steps += 1
        }
        if !isFinished { endMatch() }
        return result()!
    }

    // MARK: Stepping

    /// Advances one fixed timestep.
    func step() {
        guard !isFinished else { return }
        let dt = PhysicsConstants.fixedTimeStep

        // Rotation is handled in stepPlaying; during non-playing phases use base speed.
        if phase != .playing {
            arenaRotation += PhysicsConstants.arenaRotationSpeed * CGFloat(dt)
        }

        switch phase {
        case .kickoff:
            kickoff()
            phase = .playing
        case .celebrating(let remaining):
            phase = remaining - dt <= 0 ? resumeWithKickoff() : .celebrating(remaining: remaining - dt)
        case .halfTime(let remaining):
            phase = remaining - dt <= 0 ? resumeWithKickoff() : .halfTime(remaining: remaining - dt)
        case .playing:
            stepPlaying(dt: dt)
        case .ended:
            break
        }
    }

    private func resumeWithKickoff() -> Phase {
        kickoff()
        return .playing
    }

    private func stepPlaying(dt: TimeInterval) {
        let fdt = CGFloat(dt)
        matchClock += dt

        // Reset collision tracking for this frame.
        pendingCollisionEvents.removeAll(keepingCapacity: true)
        ballBallCollidedThisFrame = false
        ballWallCollidedThisFrame = false

        // Rotation direction changes (Mac-oto inspired).
        if matchClock > nextRotationChangeTime {
            nextRotationChangeTime = matchClock + TimeInterval(CGFloat.random(in: PhysicsConstants.rotationChangeIntervalRange, using: &rng))
            let direction: CGFloat = Bool.random(using: &rng) ? 1 : -1
            currentRotationSpeed = direction * CGFloat.random(in: PhysicsConstants.rotationSpeedRange, using: &rng)
        }
        arenaRotation += currentRotationSpeed * fdt

        // Boost — periodic self-impulse to keep balls lively.
        applyBoost(ball: &homeBall, timer: &homeBoostTimer, dt: dt)
        applyBoost(ball: &awayBall, timer: &awayBoostTimer, dt: dt)

        // Integration.
        integrate(&homeBall, fdt: fdt)
        integrate(&awayBall, fdt: fdt)

        // Speed normalization — blend toward target speed (Mac-oto inspired).
        normalizeBallSpeed(&homeBall)
        normalizeBallSpeed(&awayBall)

        // Collisions.
        resolveBallBallCollision()

        // Wall/goal: for each ball, if past wall boundary check gap → goal or bounce.
        // MUST happen before wall clamping so exit-through-gap can be detected.
        if processWallOrGoal(ball: &homeBall, side: .home) { return }
        if processWallOrGoal(ball: &awayBall, side: .away) { return }

        // Stall protection.
        updateStall(ball: &homeBall, timer: &homeStallTimer, dt: dt)
        updateStall(ball: &awayBall, timer: &awayStallTimer, dt: dt)

        if !didHalfTime, matchClock >= config.duration / 2 {
            didHalfTime = true
            phase = .halfTime(remaining: PhysicsConstants.halfTimePause)
            return
        }
        if matchClock >= config.duration {
            endMatch()
        }
    }

    // MARK: Boost (self-impulse)

    private func applyBoost(ball: inout Disc, timer: inout TimeInterval, dt: TimeInterval) {
        timer -= dt
        guard timer <= 0 else { return }
        // Reset timer for next boost.
        timer = Self.nextBoostInterval(using: &rng)

        let impulse = PhysicsConstants.boostImpulseBase

        // Direction: mostly current heading + noise; if very slow, pick a random direction.
        var baseAngle: CGFloat
        if ball.velocity.length < 1 {
            baseAngle = CGFloat.random(in: 0..<2 * .pi, using: &rng)
        } else {
            baseAngle = atan2(ball.velocity.y, ball.velocity.x)
        }
        let noise = CGFloat.random(in: -1...1, using: &rng) * PhysicsConstants.boostDirectionNoise * .pi
        let angle = baseAngle + noise
        let direction = CGPoint(x: cos(angle), y: sin(angle))

        let speed = impulse / ball.mass
        ball.velocity = ball.velocity + direction * speed
    }

    private static func nextBoostInterval(using rng: inout SeededRandomNumberGenerator) -> TimeInterval {
        TimeInterval(CGFloat.random(in: PhysicsConstants.boostIntervalRange, using: &rng))
    }

    // MARK: Forces & integration

    private func integrate(_ disc: inout Disc, fdt: CGFloat) {
        disc.velocity = disc.velocity * max(0, 1 - disc.linearDamping * fdt)
        disc.position = disc.position + disc.velocity * fdt
        // Cosmetic spin from horizontal velocity.
        disc.angularVelocity = disc.velocity.x * 0.01
        disc.angularVelocity *= max(0, 1 - PhysicsConstants.ballAngularDamping * fdt)
        disc.rotation += disc.angularVelocity * fdt
    }

    // MARK: Speed normalization (Mac-oto inspired)

    /// Blends ball velocity toward `targetBallSpeed` while preserving direction.
    /// Prevents balls from getting too slow or too fast; keeps gameplay lively.
    private func normalizeBallSpeed(_ ball: inout Disc) {
        let speed = ball.velocity.length
        guard speed > 0.01 else { return }
        let target = PhysicsConstants.targetBallSpeed
        let blend = PhysicsConstants.speedNormalizationBlend
        let newSpeed = speed + (target - speed) * blend
        ball.velocity = ball.velocity.normalized * newSpeed
    }

    // MARK: Ball-ball collision

    private func resolveBallBallCollision() {
        let preSpeed = (homeBall.velocity - awayBall.velocity).length
        let (a, b) = Self.collide(homeBall, awayBall, restitution: PhysicsConstants.ballToBallRestitution)
        homeBall = a
        awayBall = b
        // Track collision intensity for visual effects.
        let postSpeed = (homeBall.velocity - awayBall.velocity).length
        let impulse = abs(postSpeed - preSpeed)
        if impulse > 10 {
            let midPoint = CGPoint(x: (homeBall.position.x + awayBall.position.x) / 2,
                                   y: (homeBall.position.y + awayBall.position.y) / 2)
            let intensity = min(1.0, impulse / 300)
            pendingCollisionEvents.append(CollisionEvent(position: midPoint, intensity: intensity, isBallBall: true))
        }
    }

    /// Elastic disc-disc collision with positional correction.
    private static func collide(_ aIn: Disc, _ bIn: Disc, restitution: CGFloat) -> (Disc, Disc) {
        var a = aIn, b = bIn
        let delta = b.position - a.position
        let dist = delta.length
        let minDist = a.radius + b.radius
        guard dist < minDist, dist > 0.0001 else { return (a, b) }

        let n = delta * (1 / dist)
        let invA = 1 / a.mass, invB = 1 / b.mass, totalInv = invA + invB

        let overlap = minDist - dist
        a.position = a.position - n * (overlap * invA / totalInv)
        b.position = b.position + n * (overlap * invB / totalInv)

        let relativeVelocity = b.velocity - a.velocity
        let velocityAlongNormal = relativeVelocity.dot(n)
        if velocityAlongNormal < 0 {
            let impulse = n * (-(1 + restitution) * velocityAlongNormal / totalInv)
            a.velocity = a.velocity - impulse * invA
            b.velocity = b.velocity + impulse * invB
        }
        return (a, b)
    }

    // MARK: Wall collision + goal detection (combined — exit check before clamp)

    /// Processes a ball that is past the arena wall boundary. If the ball is in the
    /// gap region → goal for the ball's OWN side (it went in the net). Otherwise
    /// bounces it off the wall. Returns `true` if a goal was scored.
    private func processWallOrGoal(ball: inout Disc, side: Side) -> Bool {
        let dist = ball.position.length
        let wallBoundary = PhysicsConstants.arenaRadius - ball.radius
        guard dist > wallBoundary, dist > 0.0001 else { return false }

        let angle = atan2(ball.position.y, ball.position.x)

        // Ball past wall AND in the gap AND moving outward → it goes IN the goal →
        // the ball's OWN team scores (football logic: you put your ball in the net).
        let outwardVelocity = ball.velocity.dot(ball.position.normalized)
        if isInGap(angle), outwardVelocity > 0 {
            let scorer: Side = side
            recordGoal(scoredBy: scorer)
            return true
        }

        // Not in gap: bounce off the wall.
        let inwardNormal = ball.position * (-1 / dist)
        let velocityAlongNormal = ball.velocity.dot(inwardNormal)
        let impactSpeed = abs(velocityAlongNormal)
        if velocityAlongNormal < 0 {
            ball.velocity = ball.velocity - inwardNormal * ((1 + PhysicsConstants.ballToWallRestitution) * velocityAlongNormal)
        }
        ball.position = ball.position * (wallBoundary / dist)

        // Track wall collision for visual effects.
        if impactSpeed > 20 {
            let intensity = min(1.0, impactSpeed / 250)
            pendingCollisionEvents.append(CollisionEvent(position: ball.position, intensity: intensity, isBallBall: false))
        }
        return false
    }

    /// Whether the given world-space angle aligns with the rotating gap.
    private func isInGap(_ angle: CGFloat) -> Bool {
        let half = PhysicsConstants.gapWidth / 2
        return angularDistance(angle, arenaRotation) <= half
    }

    private func angularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let d = a - b
        return abs(atan2(sin(d), cos(d)))
    }

    // MARK: Stall protection

    private func updateStall(ball: inout Disc, timer: inout TimeInterval, dt: TimeInterval) {
        if ball.velocity.length < PhysicsConstants.stallSpeedThreshold {
            timer += dt
            if timer >= PhysicsConstants.stallTimeThreshold {
                let angle = CGFloat.random(in: 0..<2 * .pi, using: &rng)
                let speed = PhysicsConstants.stallKickImpulse / ball.mass
                ball.velocity = ball.velocity + CGPoint(x: cos(angle) * speed, y: sin(angle) * speed)
                timer = 0
            }
        } else {
            timer = 0
        }
    }

    // MARK: Match events

    private func recordGoal(scoredBy side: Side) {
        switch side {
        case .home:
            homeScore += 1
            goalsLog.append(Goal(minute: displayMinute, teamID: config.homeTeam.id))
        case .away:
            awayScore += 1
            goalsLog.append(Goal(minute: displayMinute, teamID: config.awayTeam.id))
        }
        phase = .celebrating(remaining: PhysicsConstants.goalCelebrationPause)
    }

    private func endMatch() {
        phase = .ended
        isFinished = true
    }

    private func kickoff() {
        resetFormation()
        // Give each ball a random impulse from opposite-ish directions for visual interest.
        let baseAngle = CGFloat.random(in: 0..<2 * .pi, using: &rng)
        let homeMagnitude = CGFloat.random(in: PhysicsConstants.kickoffImpulseRange, using: &rng)
        let awayMagnitude = CGFloat.random(in: PhysicsConstants.kickoffImpulseRange, using: &rng)
        let homeSpeed = homeMagnitude / homeBall.mass
        let awaySpeed = awayMagnitude / awayBall.mass
        let homeAngle = baseAngle
        let awayAngle = baseAngle + .pi
        homeBall.velocity = CGPoint(x: cos(homeAngle) * homeSpeed, y: sin(homeAngle) * homeSpeed)
        awayBall.velocity = CGPoint(x: cos(awayAngle) * awaySpeed, y: sin(awayAngle) * awaySpeed)
        homeStallTimer = 0
        awayStallTimer = 0
    }

    private func resetFormation() {
        // Place balls symmetrically near centre, offset slightly.
        homeBall.position = CGPoint(x: -PhysicsConstants.ballRadius * 0.8, y: 0)
        homeBall.velocity = .zero
        homeBall.rotation = 0
        awayBall.position = CGPoint(x: PhysicsConstants.ballRadius * 0.8, y: 0)
        awayBall.velocity = .zero
        awayBall.rotation = 0
    }
}
