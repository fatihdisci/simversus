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

/// A power-up's effect kind. Two buffs + two debuffs so the average impact on
/// scoring stays roughly neutral (keeps the goal-band calibration stable).
enum PowerUpKind: CaseIterable {
    case grow, shrink, speedUp, slowDown
}

/// A pickup sitting in the arena until a ball reaches it. `id` is a plain
/// counter (not random) so the renderer can track nodes without breaking
/// determinism.
struct PowerUp {
    let id: Int
    let kind: PowerUpKind
    let position: CGPoint
}

/// A moving circular body (a ball).
struct Disc {
    var position: CGPoint
    var velocity: CGPoint
    let radius: CGFloat
    let mass: CGFloat
    let restitution: CGFloat
    let linearDamping: CGFloat
    /// Per-team speed this ball is normalized toward (from `TeamStats.speed`).
    let targetSpeed: CGFloat
    /// Cosmetic: current rotation of the disc (for badge texture spin).
    var angularVelocity: CGFloat = 0
    var rotation: CGFloat = 0

    // Power-up modifiers (1 = no effect). Reset when the effect expires.
    var radiusScale: CGFloat = 1
    var speedScale: CGFloat = 1
    var powerUpRemaining: TimeInterval = 0
    /// The currently active pickup effect, if any (drives the visual ring).
    var activePowerUp: PowerUpKind? = nil

    /// Physical radius after any active power-up.
    var effectiveRadius: CGFloat { radius * radiusScale }
    /// Normalization target speed after any active power-up.
    var effectiveTargetSpeed: CGFloat { targetSpeed * speedScale }
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
    private var homeIsExiting = false
    private var awayIsExiting = false

    // Boost timers — per-ball countdown to next self-impulse.
    private var homeBoostTimer: TimeInterval
    private var awayBoostTimer: TimeInterval
    // Stall timers — per-ball accumulated time below stallSpeedThreshold.
    private var homeStallTimer: TimeInterval = 0
    private var awayStallTimer: TimeInterval = 0

    // Rotation direction changes (Mac-oto inspired).
    private var currentRotationSpeed: CGFloat = PhysicsConstants.arenaRotationSpeed
    private var nextRotationChangeTime: TimeInterval = 0

    // Power-ups — pickups waiting in the arena, plus the next seeded spawn time.
    private(set) var activePowerUps: [PowerUp] = []
    private var nextPowerUpSpawnTime: TimeInterval = 0
    private var nextPowerUpID = 0

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
        case ended
    }

    init(config: MatchConfig) {
        self.config = config
        self.rng = SeededRandomNumberGenerator(seed: config.seed)

        // Each ball's physical body comes from its team's stats (weight → mass,
        // size → radius, speed → targetSpeed). Restitution/damping stay shared.
        let homeStats = config.homeTeam.stats
        let awayStats = config.awayTeam.stats
        self.homeBall = Disc(position: .zero, velocity: .zero,
                             radius: homeStats.radius, mass: homeStats.mass,
                             restitution: PhysicsConstants.ballToBallRestitution,
                             linearDamping: PhysicsConstants.ballLinearDamping,
                             targetSpeed: homeStats.targetSpeed)
        self.awayBall = Disc(position: .zero, velocity: .zero,
                             radius: awayStats.radius, mass: awayStats.mass,
                             restitution: PhysicsConstants.ballToBallRestitution,
                             linearDamping: PhysicsConstants.ballLinearDamping,
                             targetSpeed: awayStats.targetSpeed)

        self.homeBoostTimer = Self.nextBoostInterval(using: &rng)
        self.awayBoostTimer = Self.nextBoostInterval(using: &rng)
        self.nextRotationChangeTime = TimeInterval(CGFloat.random(in: PhysicsConstants.rotationChangeIntervalRange, using: &rng))
        self.nextPowerUpSpawnTime = TimeInterval(CGFloat.random(in: PhysicsConstants.powerUpSpawnIntervalRange, using: &rng))

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

        // Rotation is handled in stepPlaying; kickoff lasts only one fixed step.
        if phase != .playing {
            arenaRotation += PhysicsConstants.arenaRotationSpeed * CGFloat(dt)
        }

        switch phase {
        case .kickoff:
            kickoff()
            phase = .playing
        case .playing:
            stepPlaying(dt: dt)
        case .ended:
            break
        }
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

        // Power-ups: tick active effects, spawn new pickups, collect touched ones.
        if config.powerUpsEnabled { updatePowerUps(dt: dt) }

        // Wall/goal: for each ball, if past wall boundary check gap → goal or bounce.
        // MUST happen before wall clamping so exit-through-gap can be detected.
        processWallOrGoal(ball: &homeBall, side: .home)
        processWallOrGoal(ball: &awayBall, side: .away)

        // Stall protection.
        updateStall(ball: &homeBall, timer: &homeStallTimer, dt: dt)
        updateStall(ball: &awayBall, timer: &awayStallTimer, dt: dt)

        if !didHalfTime, matchClock >= config.duration / 2 {
            didHalfTime = true
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
        let target = ball.effectiveTargetSpeed
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
        let minDist = a.effectiveRadius + b.effectiveRadius
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
    /// bounces it off the wall.
    private func processWallOrGoal(ball: inout Disc, side: Side) {
        let dist = ball.position.length
        let wallBoundary = PhysicsConstants.arenaRadius - ball.effectiveRadius
        let wasExiting = side == .home ? homeIsExiting : awayIsExiting
        if wasExiting, dist <= wallBoundary {
            // A collision can send a ball back through the mouth before it fully
            // clears the net. It must re-enter the goal normally on its next try.
            setExiting(false, for: side)
        }

        // The two arc endpoints are physical round posts. Resolving these as
        // point-vs-disc contacts gives glancing corner hits their real normal,
        // instead of a radial wall bounce or a false goal.
        if resolveGoalPostCollision(ball: &ball) { return }

        guard dist > wallBoundary, dist > 0.0001 else { return }

        let angle = atan2(ball.position.y, ball.position.x)
        let outwardVelocity = ball.velocity.dot(ball.position.normalized)
        let isExiting = side == .home ? homeIsExiting : awayIsExiting

        if isExiting {
            // Once inside, the upper/lower goal rails remain solid. This closes
            // the old loophole where an exiting ball could clip through a corner.
            if resolveGoalSideRailCollision(ball: &ball) { return }

            // A scoring ball may never roam freely outside the arena. It either
            // crosses the line while still inside the goal corridor, or loses
            // exit permission immediately and is contained by the circular wall.
            let reachedHardExitLimit = dist >= PhysicsConstants.arenaRadius + PhysicsConstants.exitMargin
            if hasCrossedGoalLine(ball) || reachedHardExitLimit {
                recordGoal(scoredBy: side)
                resetBallAfterGoal(&ball, side: side)
                setExiting(false, for: side)
                return
            }

            guard isInsideGoalCorridor(ball) else {
                setExiting(false, for: side)
                bounceOffArenaWall(ball: &ball, distance: dist, boundary: wallBoundary)
                return
            }
            return
        }

        // Crossing the mouth only starts an exit. The score is awarded after the
        // ball visibly travels through the entire goal and beyond the arena ring.
        if isInsideGoalMouth(ball: ball, angle: angle, distance: dist), outwardVelocity > 0 {
            setExiting(true, for: side)
            return
        }

        // Not in gap: bounce off the wall.
        bounceOffArenaWall(ball: &ball, distance: dist, boundary: wallBoundary)
    }

    private func bounceOffArenaWall(ball: inout Disc, distance: CGFloat, boundary: CGFloat) {
        let inwardNormal = ball.position * (-1 / distance)
        let velocityAlongNormal = ball.velocity.dot(inwardNormal)
        let impactSpeed = abs(velocityAlongNormal)
        if velocityAlongNormal < 0 {
            ball.velocity = ball.velocity - inwardNormal * ((1 + PhysicsConstants.ballToWallRestitution) * velocityAlongNormal)
        }
        enforceMinimumSeparation(on: &ball.velocity, awayFrom: inwardNormal)
        let separatedBoundary = max(0, boundary - PhysicsConstants.wallSeparationInset)
        ball.position = ball.position * (separatedBoundary / distance)

        // Track wall collision for visual effects.
        if impactSpeed > 20 {
            let intensity = min(1.0, impactSpeed / 250)
            pendingCollisionEvents.append(CollisionEvent(position: ball.position, intensity: intensity, isBallBall: false))
        }
    }

    private func setExiting(_ value: Bool, for side: Side) {
        switch side {
        case .home: homeIsExiting = value
        case .away: awayIsExiting = value
        }
    }

    private func resolveGoalPostCollision(ball: inout Disc) -> Bool {
        let half = PhysicsConstants.gapWidth / 2
        let localX = cos(half) * PhysicsConstants.arenaRadius
        let localY = sin(half) * PhysicsConstants.arenaRadius
        let c = cos(arenaRotation), s = sin(arenaRotation)
        let posts = [CGPoint(x: localX * c - localY * s, y: localX * s + localY * c),
                     CGPoint(x: localX * c + localY * s, y: localX * s - localY * c)]

        for post in posts {
            let delta = ball.position - post
            let distance = delta.length
            guard distance < ball.effectiveRadius else { continue }
            let normal = distance > 0.0001 ? delta * (1 / distance) : post.normalized * -1
            ball.position = post + normal * ball.effectiveRadius
            let speedIntoPost = ball.velocity.dot(normal)
            if speedIntoPost < 0 {
                ball.velocity = ball.velocity - normal * ((1 + PhysicsConstants.ballToWallRestitution) * speedIntoPost)
            }
            enforceMinimumSeparation(on: &ball.velocity, awayFrom: normal)
            ball.position = ball.position + normal * PhysicsConstants.wallSeparationInset
            pendingCollisionEvents.append(CollisionEvent(position: post,
                                                          intensity: min(1, abs(speedIntoPost) / 250),
                                                          isBallBall: false))
            return true
        }
        return false
    }

    private func resolveGoalSideRailCollision(ball: inout Disc) -> Bool {
        let c = cos(arenaRotation), s = sin(arenaRotation)
        var localPosition = CGPoint(x: ball.position.x * c + ball.position.y * s,
                                    y: -ball.position.x * s + ball.position.y * c)
        var localVelocity = CGPoint(x: ball.velocity.x * c + ball.velocity.y * s,
                                    y: -ball.velocity.x * s + ball.velocity.y * c)
        let half = PhysicsConstants.gapWidth / 2
        let frontX = cos(half) * PhysicsConstants.arenaRadius
        let backX = frontX + PhysicsConstants.exitMargin + 8
        let railLimit = sin(half) * PhysicsConstants.arenaRadius - ball.effectiveRadius
        guard localPosition.x >= frontX,
              localPosition.x <= backX,
              abs(localPosition.y) > railLimit else { return false }

        let side: CGFloat = localPosition.y >= 0 ? 1 : -1
        localPosition.y = side * railLimit
        if localVelocity.y * side > 0 {
            localVelocity.y = -localVelocity.y * PhysicsConstants.ballToWallRestitution
        }
        let separationDirection = -side
        if localVelocity.y * separationDirection < PhysicsConstants.minimumWallSeparationSpeed {
            localVelocity.y = separationDirection * PhysicsConstants.minimumWallSeparationSpeed
        }
        localPosition.y -= side * PhysicsConstants.wallSeparationInset
        ball.position = CGPoint(x: localPosition.x * c - localPosition.y * s,
                                y: localPosition.x * s + localPosition.y * c)
        ball.velocity = CGPoint(x: localVelocity.x * c - localVelocity.y * s,
                                y: localVelocity.x * s + localVelocity.y * c)
        pendingCollisionEvents.append(CollisionEvent(position: ball.position, intensity: 0.65, isBallBall: false))
        return true
    }

    private func enforceMinimumSeparation(on velocity: inout CGPoint, awayFrom normal: CGPoint) {
        let separationSpeed = velocity.dot(normal)
        guard separationSpeed < PhysicsConstants.minimumWallSeparationSpeed else { return }
        velocity = velocity + normal * (PhysicsConstants.minimumWallSeparationSpeed - separationSpeed)
    }

    private func hasCrossedGoalLine(_ ball: Disc) -> Bool {
        let c = cos(arenaRotation), s = sin(arenaRotation)
        let localX = ball.position.x * c + ball.position.y * s
        return localX >= PhysicsConstants.arenaRadius + PhysicsConstants.exitMargin
    }

    private func isInsideGoalCorridor(_ ball: Disc) -> Bool {
        let c = cos(arenaRotation), s = sin(arenaRotation)
        let localPosition = CGPoint(x: ball.position.x * c + ball.position.y * s,
                                    y: -ball.position.x * s + ball.position.y * c)
        let half = PhysicsConstants.gapWidth / 2
        let frontX = cos(half) * PhysicsConstants.arenaRadius
        let backX = frontX + PhysicsConstants.exitMargin + 8
        let railLimit = sin(half) * PhysicsConstants.arenaRadius - ball.effectiveRadius
        return localPosition.x >= frontX - ball.effectiveRadius
            && localPosition.x <= backX
            && abs(localPosition.y) <= railLimit + 1
    }

    /// The gap is visually wider than a ball. A centre point is only admitted
    /// when its entire circle clears both goal posts; otherwise it bounces.
    /// This is the physical guard that prevents corner clipping into a goal.
    private func isInsideGoalMouth(ball: Disc, angle: CGFloat, distance: CGFloat) -> Bool {
        let half = PhysicsConstants.gapWidth / 2
        let mouthHalfHeight = PhysicsConstants.arenaRadius * sin(half)
        let centreClearance = mouthHalfHeight - ball.effectiveRadius
        guard centreClearance > 0 else { return false }
        let localAngle = angularDistance(angle, arenaRotation)
        let lateralOffset = distance * sin(localAngle)
        return lateralOffset <= centreClearance
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
    }

    /// Respawns only the scoring ball. The opponent and match clock never freeze.
    private func resetBallAfterGoal(_ ball: inout Disc, side: Side) {
        clearPowerUpEffect(&ball)
        let spawnRadius = CGFloat.random(in: 0...PhysicsConstants.ballRadius * 0.35, using: &rng)
        let spawnAngle = CGFloat.random(in: 0..<2 * .pi, using: &rng)
        ball.position = CGPoint(x: cos(spawnAngle) * spawnRadius, y: sin(spawnAngle) * spawnRadius)
        let launchAngle = CGFloat.random(in: 0..<2 * .pi, using: &rng)
        let magnitude = CGFloat.random(in: PhysicsConstants.kickoffImpulseRange, using: &rng) / ball.mass
        ball.velocity = CGPoint(x: cos(launchAngle) * magnitude, y: sin(launchAngle) * magnitude)
        ball.rotation = 0
        switch side {
        case .home: homeStallTimer = 0; homeBoostTimer = Self.nextBoostInterval(using: &rng)
        case .away: awayStallTimer = 0; awayBoostTimer = Self.nextBoostInterval(using: &rng)
        }
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
        homeIsExiting = false
        awayIsExiting = false
        // Clear any active power-up effects for a fresh start (kickoff / post-goal).
        clearPowerUpEffect(&homeBall)
        clearPowerUpEffect(&awayBall)
        // Place balls symmetrically near centre, offset slightly by their radius.
        homeBall.position = CGPoint(x: -homeBall.radius * 0.8, y: 0)
        homeBall.velocity = .zero
        homeBall.rotation = 0
        awayBall.position = CGPoint(x: awayBall.radius * 0.8, y: 0)
        awayBall.velocity = .zero
        awayBall.rotation = 0
    }

    // MARK: Power-ups (periodic seeded pickups — temporary ball modifiers)

    private func updatePowerUps(dt: TimeInterval) {
        tickPowerUpTimer(&homeBall, dt: dt)
        tickPowerUpTimer(&awayBall, dt: dt)

        if activePowerUps.count < PhysicsConstants.maxActivePowerUps, matchClock > nextPowerUpSpawnTime {
            nextPowerUpSpawnTime = matchClock + TimeInterval(CGFloat.random(in: PhysicsConstants.powerUpSpawnIntervalRange, using: &rng))
            spawnPowerUp()
        }

        collectPowerUps(&homeBall)
        collectPowerUps(&awayBall)
    }

    private func spawnPowerUp() {
        let kind = PowerUpKind.allCases.randomElement(using: &rng) ?? .grow
        let maxR = PhysicsConstants.arenaRadius * PhysicsConstants.powerUpSpawnInnerFraction
        let r = CGFloat.random(in: 0...maxR, using: &rng)
        let a = CGFloat.random(in: 0..<2 * .pi, using: &rng)
        activePowerUps.append(PowerUp(id: nextPowerUpID, kind: kind,
                                      position: CGPoint(x: cos(a) * r, y: sin(a) * r)))
        nextPowerUpID += 1
    }

    private func collectPowerUps(_ ball: inout Disc) {
        guard !activePowerUps.isEmpty else { return }
        var remaining: [PowerUp] = []
        for pu in activePowerUps {
            let dx = pu.position.x - ball.position.x
            let dy = pu.position.y - ball.position.y
            let reach = ball.effectiveRadius + PhysicsConstants.powerUpRadius
            if dx * dx + dy * dy < reach * reach {
                applyPowerUp(pu.kind, to: &ball)
            } else {
                remaining.append(pu)
            }
        }
        activePowerUps = remaining
    }

    private func applyPowerUp(_ kind: PowerUpKind, to ball: inout Disc) {
        ball.radiusScale = 1
        ball.speedScale = 1
        switch kind {
        case .grow:     ball.radiusScale = PhysicsConstants.powerUpGrowScale
        case .shrink:   ball.radiusScale = PhysicsConstants.powerUpShrinkScale
        case .speedUp:  ball.speedScale = PhysicsConstants.powerUpSpeedUpScale
        case .slowDown: ball.speedScale = PhysicsConstants.powerUpSlowScale
        }
        ball.activePowerUp = kind
        ball.powerUpRemaining = PhysicsConstants.powerUpDuration
    }

    private func tickPowerUpTimer(_ ball: inout Disc, dt: TimeInterval) {
        guard ball.activePowerUp != nil else { return }
        ball.powerUpRemaining -= dt
        if ball.powerUpRemaining <= 0 { clearPowerUpEffect(&ball) }
    }

    private func clearPowerUpEffect(_ ball: inout Disc) {
        ball.radiusScale = 1
        ball.speedScale = 1
        ball.powerUpRemaining = 0
        ball.activePowerUp = nil
    }
}
