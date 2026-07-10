//  MatchScene.swift
//  Core/Engine
//
//  Renders a `MatchSimulation` with SpriteKit. The scene owns the simulation,
//  steps it with a fixed-timestep accumulator, and each frame positions the two
//  ball nodes (circular badge visuals) and rotates the arena to match the
//  simulation state. It never drives the physics itself, and it never reads
//  touches — the match is spectator-only (CONSTITUTION §4.1).
//
//  TWO-BALL SYSTEM: Each team has its own circular ball with badge symbol.
//  The arena has a SINGLE rotating goal gap. Visual effects inspired by Mac-oto
//  (collision particles, ball trail, confetti, camera shake, neon wall).

import SpriteKit
import UIKit

/// Lightweight HUD state pushed to SwiftUI each time it changes.
struct MatchHUDSnapshot: Equatable {
    var homeScore = 0
    var awayScore = 0
    var minute = 0
    var isFirstHalf = true
}

// MARK: - Particle types

private struct CollisionParticle {
    var node: SKShapeNode
    var velocity: CGPoint
    var lifetime: TimeInterval
    var age: TimeInterval = 0
}

private struct TrailParticle {
    var node: SKShapeNode
    var lifetime: TimeInterval
    var age: TimeInterval = 0
}

final class MatchScene: SKScene {
    private let simulation: MatchSimulation
    private let homeTeam: Team
    private let awayTeam: Team

    var onMatchEnded: ((MatchResult) -> Void)?
    var onHUDUpdate: ((MatchHUDSnapshot) -> Void)?
    var onGoalScored: (() -> Void)?

    // Hierarchy: world → shakeNode → arenaNode + ballNodes + particles.
    private let worldNode = SKNode()
    private let shakeNode = SKNode()
    private let arenaNode = SKNode()
    private var homeBallNode = SKSpriteNode()
    private var awayBallNode = SKSpriteNode()
    private var homeShadowNode = SKShapeNode()
    private var awayShadowNode = SKShapeNode()

    // Particle pools.
    private var collisionParticles: [CollisionParticle] = []
    private var trailParticles: [TrailParticle] = []
    private var confettiNodes: [SKShapeNode] = []

    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: TimeInterval = 0
    private var lastSnapshot = MatchHUDSnapshot()
    private var lastTotalGoals = 0

    // Camera shake.
    private var shakeIntensity: CGFloat = 0
    private var shakePhase: CGFloat = 0

    // Cosmetic values.
    private let wallStrokeWidth: CGFloat = 3
    private let centerRingFraction: CGFloat = 0.18

    // Track last processed collision events to avoid duplicates.
    private var processedCollisionCount: Int = 0

    init(config: MatchConfig) {
        simulation = MatchSimulation(config: config)
        homeTeam = config.homeTeam
        awayTeam = config.awayTeam
        super.init(size: CGSize(width: 390, height: 780))
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(Palette.bgArena)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        guard worldNode.parent == nil else { return }
        buildNodes()
        layoutWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutWorld()
    }

    // MARK: Build

    private func buildNodes() {
        addChild(worldNode)
        worldNode.addChild(shakeNode)
        shakeNode.addChild(arenaNode)
        buildArena()

        homeBallNode = makeBallNode(team: homeTeam)
        awayBallNode = makeBallNode(team: awayTeam)
        shakeNode.addChild(homeBallNode)
        shakeNode.addChild(awayBallNode)

        // Ball shadows (ellipses under balls).
        homeShadowNode = makeShadowNode()
        awayShadowNode = makeShadowNode()
        shakeNode.addChild(homeShadowNode)
        shakeNode.addChild(awayShadowNode)
    }

    private func makeShadowNode() -> SKShapeNode {
        let w = PhysicsConstants.ballRadius * 1.45 * 2
        let h = max(6, PhysicsConstants.ballRadius * 0.42) * 2
        let node = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        node.fillColor = UIColor.black.withAlphaComponent(0.18)
        node.strokeColor = .clear
        node.zPosition = -1
        return node
    }

    /// Creates a circular ball sprite with the team badge symbol.
    private func makeBallNode(team: Team) -> SKSpriteNode {
        let diameter = PhysicsConstants.ballRadius * 2
        let size = CGSize(width: diameter, height: diameter)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(team.primaryColor).setFill()
            ctx.cgContext.fillEllipse(in: rect)
            UIColor(team.secondaryColor).setStroke()
            ctx.cgContext.setLineWidth(2)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            let symbolRect = rect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22)
            UIColor(team.secondaryColor).setFill()
            Self.drawBadgeSymbol(shape: team.badgeShape, in: symbolRect, ctx: ctx.cgContext)
        }

        let node = SKSpriteNode(texture: SKTexture(image: image))
        node.size = size
        node.zPosition = 10
        return node
    }

    // MARK: Badge symbol paths (static)

    private static func drawBadgeSymbol(shape: BadgeShape, in rect: CGRect, ctx: CGContext) {
        let path: CGPath
        switch shape {
        case .star:    path = Self.starPath(in: rect)
        case .chevron: path = Self.chevronPath(in: rect)
        case .wave:    path = Self.wavePath(in: rect)
        case .diamond: path = Self.diamondPath(in: rect)
        case .ring:    path = Self.ringPath(in: rect)
        }
        ctx.addPath(path)
        ctx.fillPath()
    }

    private static func starPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2, inner = outer * 0.42
        for i in 0..<10 {
            let r = i.isMultiple(of: 2) ? outer : inner
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.closeSubpath(); return path
    }

    private static func chevronPath(in rect: CGRect) -> CGPath {
        let t = rect.width * 0.30, hIn = rect.height * 0.46
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY + hIn))
        path.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath(); return path
    }

    private static func wavePath(in rect: CGRect) -> CGPath {
        let amp = rect.height * 0.16, thick = rect.height * 0.28, baseY = rect.midY - thick / 2, steps = 48
        let path = CGMutablePath()
        for i in 0...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = baseY + sin(CGFloat(i) / CGFloat(steps) * .pi * 2) * amp
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = baseY + thick + sin(CGFloat(i) / CGFloat(steps) * .pi * 2) * amp
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath(); return path
    }

    private static func diamondPath(in rect: CGRect) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath(); return path
    }

    private static func ringPath(in rect: CGRect) -> CGPath {
        let outer = min(rect.width, rect.height), inner = outer * 0.56
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: rect.midX - outer / 2, y: rect.midY - outer / 2, width: outer, height: outer))
        path.addEllipse(in: CGRect(x: rect.midX - inner / 2, y: rect.midY - inner / 2, width: inner, height: inner))
        return path
    }

    // MARK: Arena

    private func buildArena() {
        let r = PhysicsConstants.arenaRadius
        let half = PhysicsConstants.gapWidth / 2

        // Arena background circle (darker inner, depth).
        let bgCircle = SKShapeNode(circleOfRadius: r)
        bgCircle.fillColor = UIColor(red: 0.086, green: 0.118, blue: 0.173, alpha: 1)
        bgCircle.strokeColor = .clear
        arenaNode.addChild(bgCircle)

        // Neon glow layers.
        let cyan = UIColor(red: 0, green: 0.9, blue: 1, alpha: 1)
        for (width, alpha) in [(CGFloat(22), CGFloat(0.05)), (CGFloat(12), CGFloat(0.10)), (CGFloat(6), CGFloat(0.22))] {
            let glow = SKShapeNode(path: wallArcPath(radius: r, half: half))
            glow.strokeColor = cyan.withAlphaComponent(alpha)
            glow.lineWidth = width
            glow.lineCap = .round
            arenaNode.addChild(glow)
        }

        // Main wall — thick cyan.
        let wall = SKShapeNode(path: wallArcPath(radius: r, half: half))
        wall.strokeColor = cyan
        wall.lineWidth = 4.5
        wall.lineCap = .round
        arenaNode.addChild(wall)

        // Inner bright white core.
        let core = SKShapeNode(path: wallArcPath(radius: r, half: half))
        core.strokeColor = UIColor.white.withAlphaComponent(0.75)
        core.lineWidth = 1.5
        core.lineCap = .round
        arenaNode.addChild(core)

        // ── GOAL MOUTH (Mac-oto inspired) ──

        let goalR: CGFloat = r + 4  // slightly outside wall

        // Goal threshold line across the gap opening.
        let threshold = CGMutablePath()
        let t1 = CGPoint(x: cos(-half) * goalR, y: sin(-half) * goalR)
        let t2 = CGPoint(x: cos(half) * goalR, y: sin(half) * goalR)
        threshold.move(to: t1)
        threshold.addLine(to: t2)
        let thresholdNode = SKShapeNode(path: threshold)
        thresholdNode.strokeColor = UIColor.white
        thresholdNode.lineWidth = 3
        thresholdNode.lineCap = .round
        arenaNode.addChild(thresholdNode)

        // Goalposts — thick bright posts at each edge, angled outward.
        for side: CGFloat in [-1, 1] {
            let a = side * half
            let inner = CGPoint(x: cos(a) * goalR, y: sin(a) * goalR)
            let outer = CGPoint(x: cos(a + side * 0.35) * (goalR + 28),
                                y: sin(a + side * 0.35) * (goalR + 28))
            let post = CGMutablePath()
            post.move(to: inner)
            post.addLine(to: outer)
            let postNode = SKShapeNode(path: post)
            postNode.strokeColor = UIColor(red: 1, green: 0.84, blue: 0.1, alpha: 1) // gold
            postNode.lineWidth = 5
            postNode.lineCap = .round
            arenaNode.addChild(postNode)

            // Bright white tip at post end.
            let tip = SKShapeNode(circleOfRadius: 4)
            tip.fillColor = .white
            tip.strokeColor = .clear
            tip.position = outer
            arenaNode.addChild(tip)
        }

        // Net — horizontal lines extending outward from gap.
        for i in 1...4 {
            let ext = goalR + CGFloat(i) * 11
            let n1 = CGPoint(x: cos(-half) * ext, y: sin(-half) * ext)
            let n2 = CGPoint(x: cos(half) * ext, y: sin(half) * ext)
            let netLine = CGMutablePath()
            netLine.move(to: n1)
            netLine.addLine(to: n2)
            let netNode = SKShapeNode(path: netLine)
            netNode.strokeColor = UIColor.white.withAlphaComponent(CGFloat(0.22 - Double(i) * 0.04))
            netNode.lineWidth = 1.5
            arenaNode.addChild(netNode)
        }

        // Vertical net lines connecting the horizontal ones.
        for j in [-1, 1] {
            let a = CGFloat(j) * half
            let path = CGMutablePath()
            let inner = CGPoint(x: cos(a) * goalR, y: sin(a) * goalR)
            let outer = CGPoint(x: cos(a) * (goalR + 44), y: sin(a) * (goalR + 44))
            path.move(to: inner)
            path.addLine(to: outer)
            let vNode = SKShapeNode(path: path)
            vNode.strokeColor = UIColor.white.withAlphaComponent(0.18)
            vNode.lineWidth = 2
            arenaNode.addChild(vNode)
        }

        // Centre marks so rotation is visible.
        let line = SKShapeNode(rectOf: CGSize(width: r * 2, height: wallStrokeWidth))
        line.fillColor = UIColor(Palette.arenaLine)
        line.strokeColor = .clear
        arenaNode.addChild(line)

        let ring = SKShapeNode(circleOfRadius: r * centerRingFraction)
        ring.strokeColor = UIColor(Palette.arenaLine)
        ring.lineWidth = wallStrokeWidth
        ring.fillColor = .clear
        arenaNode.addChild(ring)
    }

    private func wallArcPath(radius: CGFloat, half: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: half, endAngle: 2 * .pi - half, clockwise: false)
        return path
    }

    private func layoutWorld() {
        guard size.width > 0 else { return }
        worldNode.setScale(PhysicsConstants.arenaRenderWidthFraction * size.width / PhysicsConstants.arenaRadius)
        worldNode.position = .zero
    }

    // MARK: Step & render

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let delta = min(currentTime - lastUpdateTime, 0.25)
        lastUpdateTime = currentTime

        accumulator += delta * TimeInterval(PhysicsConstants.maxSimSpeed)
        var stepsThisFrame = 0
        while accumulator >= PhysicsConstants.fixedTimeStep, stepsThisFrame < 20, !simulation.isFinished {
            simulation.step()
            // Spawn collision particles from events generated this step.
            spawnCollisionEffects()
            accumulator -= PhysicsConstants.fixedTimeStep
            stepsThisFrame += 1
        }

        // Visual effects update (frame-rate dependent, not sim-step).
        updateParticles(dt: CGFloat(delta))
        updateCameraShake(dt: CGFloat(delta))

        renderState()
        publishEvents()

        if simulation.isFinished, let result = simulation.result() {
            onMatchEnded?(result)
            onMatchEnded = nil
            isPaused = true
        }
    }

    private func renderState() {
        homeBallNode.position = simulation.homeBall.position
        homeBallNode.zRotation = simulation.homeBall.rotation
        awayBallNode.position = simulation.awayBall.position
        awayBallNode.zRotation = simulation.awayBall.rotation
        arenaNode.zRotation = simulation.arenaRotation

        // Ball shadows (offset slightly below each ball).
        let shadowOffY: CGFloat = PhysicsConstants.ballRadius * 0.78
        homeShadowNode.position = CGPoint(x: simulation.homeBall.position.x, y: simulation.homeBall.position.y + shadowOffY)
        awayShadowNode.position = CGPoint(x: simulation.awayBall.position.x, y: simulation.awayBall.position.y + shadowOffY)

        // Spawn ball trail particles.
        spawnTrail(for: simulation.homeBall, color: UIColor(homeTeam.primaryColor))
        spawnTrail(for: simulation.awayBall, color: UIColor(awayTeam.primaryColor))
    }

    private func publishEvents() {
        let snapshot = MatchHUDSnapshot(homeScore: simulation.homeScore,
                                        awayScore: simulation.awayScore,
                                        minute: simulation.displayMinute,
                                        isFirstHalf: simulation.isFirstHalf)
        if snapshot != lastSnapshot {
            lastSnapshot = snapshot
            onHUDUpdate?(snapshot)
        }
        let total = simulation.homeScore + simulation.awayScore
        if total > lastTotalGoals {
            lastTotalGoals = total
            onGoalScored?()
            triggerGoalEffects()
        }
    }

    // MARK: Collision particles (Mac-oto inspired)

    private func spawnCollisionEffects() {
        let events = simulation.pendingCollisionEvents
        guard events.count > processedCollisionCount else { return }
        let newEvents = events.suffix(from: processedCollisionCount)
        processedCollisionCount = events.count

        for event in newEvents {
            let count = event.isBallBall ? 30 : 15
            let colors: [UIColor] = event.isBallBall
                ? [.white, UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), UIColor(red: 0, green: 0.9, blue: 1, alpha: 1), UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)]
                : [.white, UIColor(red: 0, green: 0.7, blue: 1, alpha: 1), UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)]
            for _ in 0..<count {
                let angle = CGFloat.random(in: 0..<2 * .pi)
                let speed = CGFloat.random(in: 80...400) * event.intensity
                let size = CGFloat.random(in: 2...6) * event.intensity
                let node = SKShapeNode(circleOfRadius: max(1, size))
                node.fillColor = colors.randomElement() ?? .white
                node.strokeColor = .clear
                node.position = event.position
                node.zPosition = 20
                shakeNode.addChild(node)
                collisionParticles.append(CollisionParticle(
                    node: node,
                    velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                    lifetime: TimeInterval(CGFloat.random(in: 0.3...0.7))
                ))
            }
        }
    }

    private func updateParticles(dt: CGFloat) {
        // Collision particles.
        var aliveCollision: [CollisionParticle] = []
        for var p in collisionParticles {
            p.age += TimeInterval(dt)
            if p.age >= p.lifetime { p.node.removeFromParent(); continue }
            p.velocity.y -= 400 * dt // gravity-like
            p.velocity.x *= 0.94
            p.velocity.y *= 0.94
            p.node.position.x += p.velocity.x * dt
            p.node.position.y += p.velocity.y * dt
            let progress = CGFloat(p.age / p.lifetime)
            p.node.alpha = 1 - progress
            p.node.setScale(1 - progress * 0.5)
            aliveCollision.append(p)
        }
        collisionParticles = aliveCollision

        // Trail particles.
        var aliveTrail: [TrailParticle] = []
        for var p in trailParticles {
            p.age += TimeInterval(dt)
            if p.age >= p.lifetime { p.node.removeFromParent(); continue }
            let progress = CGFloat(p.age / p.lifetime)
            p.node.alpha = 0.18 * (1 - progress)
            p.node.setScale(1 + progress * 0.3)
            aliveTrail.append(p)
        }
        trailParticles = aliveTrail

        // Confetti (gravity + rotate).
        for node in confettiNodes {
            node.position.y -= 300 * dt
            node.position.x += (node.userData?["vx"] as? CGFloat ?? 0) * dt
            node.zRotation += (node.userData?["vr"] as? CGFloat ?? 0) * dt
            node.alpha -= 0.5 * dt
        }
        confettiNodes.removeAll { $0.alpha <= 0 }
        for dead in confettiNodes where dead.alpha <= 0 { dead.removeFromParent() }
    }

    // MARK: Ball trail (Mac-oto inspired — subtle white dust)

    private func spawnTrail(for ball: Disc, color: UIColor) {
        // Only spawn trail when moving fast enough and randomly (not every frame).
        let speed = hypot(ball.velocity.x, ball.velocity.y)
        guard speed > 80, CGFloat.random(in: 0...1) < 0.4 else { return }
        let nx = ball.velocity.x / speed
        let ny = ball.velocity.y / speed
        let tx = ball.position.x - nx * PhysicsConstants.ballRadius * 0.7
        let ty = ball.position.y - ny * PhysicsConstants.ballRadius * 0.7
        let size = CGFloat.random(in: 1.5...4)
        let node = SKShapeNode(circleOfRadius: size)
        node.fillColor = UIColor.white.withAlphaComponent(0.25)
        node.strokeColor = .clear
        node.position = CGPoint(x: tx + CGFloat.random(in: -3...3), y: ty + CGFloat.random(in: -3...3))
        node.zPosition = 5
        shakeNode.addChild(node)
        trailParticles.append(TrailParticle(node: node, lifetime: TimeInterval(CGFloat.random(in: 0.15...0.35))))
    }

    // MARK: Camera shake (Mac-oto inspired)

    private func triggerGoalEffects() {
        shakeIntensity = 1.0
        spawnConfetti()
    }

    private func updateCameraShake(dt: CGFloat) {
        shakeIntensity = max(0, shakeIntensity - 0.045 * dt * 60)
        shakePhase += 1.0 * dt * 60
        guard shakeIntensity > 0.02 else {
            shakeNode.position = .zero
            return
        }
        let dx = sin(shakePhase * 0.42) * shakeIntensity * 4
        let dy = cos(shakePhase * 0.37) * shakeIntensity * 3
        shakeNode.position = CGPoint(x: dx, y: dy)
    }

    // MARK: Confetti (Mac-oto inspired)

    private func spawnConfetti() {
        let homeColor = UIColor(homeTeam.primaryColor)
        let awayColor = UIColor(awayTeam.primaryColor)
        let colors: [UIColor] = [homeColor, awayColor, .white, UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1),
                                  UIColor(red: 0.5, green: 0.9, blue: 0.6, alpha: 1)]
        for _ in 0..<60 {
            let size = CGFloat.random(in: 4...10)
            let shape: SKShapeNode
            if Bool.random() {
                shape = SKShapeNode(rectOf: CGSize(width: size * 3, height: size))
            } else {
                shape = SKShapeNode(circleOfRadius: size)
            }
            shape.fillColor = colors.randomElement() ?? .white
            shape.strokeColor = .clear
            shape.position = CGPoint(x: CGFloat.random(in: -120...120), y: CGFloat.random(in: 200...350))
            shape.zPosition = 30
            shape.zRotation = CGFloat.random(in: 0..<2 * .pi)
            shape.userData = [
                "vx": CGFloat.random(in: -200...200),
                "vr": CGFloat.random(in: -6...6)
            ] as NSMutableDictionary
            shakeNode.addChild(shape)
            confettiNodes.append(shape)
        }
    }
}
