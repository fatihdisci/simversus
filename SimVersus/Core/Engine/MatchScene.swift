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

// Particles are SKSpriteNodes sharing two cached textures (circle/square) so
// SpriteKit can batch them into a single draw pass — per-node SKShapeNodes each
// cost their own draw and allocate on every spawn, which caused visible hitches
// on collision/goal bursts. Nodes are recycled through `particlePool`.

private struct CollisionParticle {
    var node: SKSpriteNode
    var velocity: CGPoint
    var lifetime: TimeInterval
    var age: TimeInterval = 0
}

private struct TrailParticle {
    var node: SKSpriteNode
    var lifetime: TimeInterval
    var age: TimeInterval = 0
}

private struct ConfettiParticle {
    var node: SKSpriteNode
    var vx: CGFloat
    var vr: CGFloat
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
    private var homeEffectRing = SKShapeNode()
    private var awayEffectRing = SKShapeNode()

    // Power-up pickup nodes, keyed by the simulation's power-up id.
    private var powerUpNodes: [Int: SKNode] = [:]

    // Live particles + shared sprite pool (recycled nodes, capped size).
    private var collisionParticles: [CollisionParticle] = []
    private var trailParticles: [TrailParticle] = []
    private var confettiParticles: [ConfettiParticle] = []
    private var particlePool: [SKSpriteNode] = []
    private let particlePoolLimit = 256
    private let maxLiveCollisionParticles = 150

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

        // Ball shadows (ellipses under balls) — sized to each team's radius.
        homeShadowNode = makeShadowNode(radius: homeTeam.stats.radius)
        awayShadowNode = makeShadowNode(radius: awayTeam.stats.radius)
        shakeNode.addChild(homeShadowNode)
        shakeNode.addChild(awayShadowNode)

        // Active power-up rings (hidden until a ball holds an effect).
        homeEffectRing = makeEffectRing(radius: homeTeam.stats.radius + 5)
        awayEffectRing = makeEffectRing(radius: awayTeam.stats.radius + 5)
        shakeNode.addChild(homeEffectRing)
        shakeNode.addChild(awayEffectRing)
    }

    private func makeEffectRing(radius: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(circleOfRadius: radius)
        node.fillColor = .clear
        node.lineWidth = 2.5
        node.strokeColor = .white
        node.zPosition = 9
        node.isHidden = true
        return node
    }

    private func makeShadowNode(radius: CGFloat) -> SKShapeNode {
        let w = radius * 1.45 * 2
        let h = max(6, radius * 0.42) * 2
        let node = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        node.fillColor = UIColor.black.withAlphaComponent(0.18)
        node.strokeColor = .clear
        node.zPosition = -1
        return node
    }

    /// Creates a circular ball sprite with the team badge symbol.
    private func makeBallNode(team: Team) -> SKSpriteNode {
        let diameter = team.stats.radius * 2
        let size = CGSize(width: diameter, height: diameter)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let cg = ctx.cgContext
            UIColor(team.primaryColor).setFill()
            cg.fillEllipse(in: rect)

            // Kit pattern — secondary-coloured regions clipped to the ball.
            let patternPath = team.pattern.secondaryRegionsCGPath(in: rect)
            if !patternPath.isEmpty {
                cg.saveGState()
                cg.addEllipse(in: rect)
                cg.clip()
                cg.addPath(patternPath)
                UIColor(team.secondaryColor).setFill()
                cg.fillPath()
                cg.restoreGState()
            }

            UIColor(team.secondaryColor).setStroke()
            cg.setLineWidth(2)
            cg.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            let symbolRect = rect.insetBy(dx: diameter * 0.22, dy: diameter * 0.22)
            UIColor(team.secondaryColor).setFill()
            Self.drawBadgeSymbol(shape: team.badgeShape, in: symbolRect, ctx: ctx.cgContext)
        }

        let node = SKSpriteNode(texture: SKTexture(image: image))
        node.size = size
        node.zPosition = 10
        return node
    }

    // MARK: Particle textures & pool

    /// Shared white circle texture — tinted per particle via `color`/`colorBlendFactor`.
    private static let circleParticleTexture: SKTexture = {
        let d: CGFloat = 16
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: image)
    }()

    /// Shared white square texture for confetti rectangles.
    private static let squareParticleTexture: SKTexture = {
        let d: CGFloat = 8
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: d, height: d))
        }
        return SKTexture(image: image)
    }()

    private func obtainParticleSprite(texture: SKTexture, size: CGSize, color: UIColor) -> SKSpriteNode {
        let node: SKSpriteNode
        if let recycled = particlePool.popLast() {
            node = recycled
            node.texture = texture
        } else {
            node = SKSpriteNode(texture: texture)
        }
        node.size = size
        node.xScale = 1
        node.yScale = 1
        node.zRotation = 0
        node.alpha = 1
        node.color = color
        node.colorBlendFactor = 1
        return node
    }

    private func recycleParticleSprite(_ node: SKSpriteNode) {
        node.removeFromParent()
        if particlePool.count < particlePoolLimit {
            particlePool.append(node)
        }
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

        // ── GOAL (net box seated in the rotating wall gap) ──
        buildGoal(radius: r, half: half)

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

    /// Builds a rectangular goal (frame + net mesh) seated in the wall gap.
    /// Gap is centred on the +X axis in arena-local space; `arenaNode` (this goal
    /// included) is rotated to the live gap angle each frame, so the goal always
    /// stays glued to the opening. The frame is an outward "⊐" bracket whose open
    /// mouth faces the arena interior — the direction a ball travels to score.
    private func buildGoal(radius r: CGFloat, half: CGFloat) {
        let depth: CGFloat = 34                 // how far the goal box extends past the wall
        let frontX = cos(half) * r              // both gap edges share this x (mouth is a chord)
        let topY = sin(half) * r
        let botY = -topY
        let backX = frontX + depth

        // Net mesh — subtle white crosshatch filling the box (behind the frame).
        let mesh = CGMutablePath()
        let columns = 3                         // lines parallel to the back bar
        for i in 1...columns {
            let x = frontX + depth * CGFloat(i) / CGFloat(columns + 1)
            mesh.move(to: CGPoint(x: x, y: botY))
            mesh.addLine(to: CGPoint(x: x, y: topY))
        }
        let rows = 3                            // lines parallel to the posts
        for i in 1...rows {
            let y = botY + (topY - botY) * CGFloat(i) / CGFloat(rows + 1)
            mesh.move(to: CGPoint(x: frontX, y: y))
            mesh.addLine(to: CGPoint(x: backX, y: y))
        }
        let meshNode = SKShapeNode(path: mesh)
        meshNode.strokeColor = UIColor.white.withAlphaComponent(0.16)
        meshNode.lineWidth = 1
        arenaNode.addChild(meshNode)

        // Frame path — top post, back bar, bottom post (mouth stays open).
        let frame = CGMutablePath()
        frame.move(to: CGPoint(x: frontX, y: topY))
        frame.addLine(to: CGPoint(x: backX, y: topY))
        frame.addLine(to: CGPoint(x: backX, y: botY))
        frame.addLine(to: CGPoint(x: frontX, y: botY))

        // Soft white glow under the frame (neon-consistent with the arena wall).
        let glow = SKShapeNode(path: frame)
        glow.strokeColor = UIColor.white.withAlphaComponent(0.22)
        glow.lineWidth = 8
        glow.lineCap = .round
        glow.lineJoin = .round
        arenaNode.addChild(glow)

        // Bright solid frame.
        let frameNode = SKShapeNode(path: frame)
        frameNode.strokeColor = .white
        frameNode.lineWidth = 3.5
        frameNode.lineCap = .round
        frameNode.lineJoin = .round
        arenaNode.addChild(frameNode)
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
        // Cap delta hard: after a hitch/backgrounding the sim clock slips slightly
        // instead of bursting many catch-up steps in one frame (chained stutter).
        let delta = min(currentTime - lastUpdateTime, 1.0 / 20.0)
        lastUpdateTime = currentTime

        accumulator += delta * TimeInterval(PhysicsConstants.maxSimSpeed)
        var stepsThisFrame = 0
        while accumulator >= PhysicsConstants.fixedTimeStep, stepsThisFrame < 4, !simulation.isFinished {
            simulation.step()
            // Spawn collision particles from events generated this step.
            spawnCollisionEffects()
            accumulator -= PhysicsConstants.fixedTimeStep
            stepsThisFrame += 1
        }
        // Drop leftover debt beyond one frame's budget so a sustained slow
        // stretch can never build an ever-growing catch-up queue.
        accumulator = min(accumulator, PhysicsConstants.fixedTimeStep * 4)

        // Visual effects update (frame-rate dependent, not sim-step).
        updateParticles(dt: CGFloat(delta))
        updateCameraShake(dt: CGFloat(delta))

        renderState()
        syncPowerUps()
        publishEvents()

        if simulation.isFinished, let result = simulation.result() {
            onMatchEnded?(result)
            onMatchEnded = nil
            isPaused = true
        }
    }

    private func renderState() {
        let home = simulation.homeBall
        let away = simulation.awayBall

        homeBallNode.position = home.position
        homeBallNode.zRotation = home.rotation
        homeBallNode.setScale(home.radiusScale) // grow/shrink power-up
        awayBallNode.position = away.position
        awayBallNode.zRotation = away.rotation
        awayBallNode.setScale(away.radiusScale)
        arenaNode.zRotation = simulation.arenaRotation

        // Ball shadows (offset slightly below each ball, scaled to its radius).
        homeShadowNode.position = CGPoint(x: home.position.x, y: home.position.y + home.effectiveRadius * 0.78)
        homeShadowNode.setScale(home.radiusScale)
        awayShadowNode.position = CGPoint(x: away.position.x, y: away.position.y + away.effectiveRadius * 0.78)
        awayShadowNode.setScale(away.radiusScale)

        // Active power-up rings track the ball and take the effect's colour.
        updateEffectRing(homeEffectRing, ball: home)
        updateEffectRing(awayEffectRing, ball: away)

        // Spawn ball trail particles.
        spawnTrail(for: home, color: UIColor(homeTeam.primaryColor))
        spawnTrail(for: away, color: UIColor(awayTeam.primaryColor))
    }

    private func updateEffectRing(_ ring: SKShapeNode, ball: Disc) {
        guard let kind = ball.activePowerUp else { ring.isHidden = true; return }
        ring.isHidden = false
        ring.position = ball.position
        ring.setScale(ball.radiusScale)
        ring.strokeColor = Self.powerUpStyle(kind).color
    }

    // MARK: Power-up pickups

    /// Reconciles the on-screen pickup nodes with the simulation's live list:
    /// removes collected ones, adds newly spawned ones.
    private func syncPowerUps() {
        let current = simulation.activePowerUps
        let liveIDs = Set(current.map(\.id))
        // Snapshot keys first — never mutate the dictionary while iterating it.
        for id in Array(powerUpNodes.keys) where !liveIDs.contains(id) {
            powerUpNodes[id]?.removeFromParent()
            powerUpNodes[id] = nil
        }
        for pu in current where powerUpNodes[pu.id] == nil {
            let node = makePowerUpNode(kind: pu.kind)
            node.position = pu.position
            shakeNode.addChild(node)
            powerUpNodes[pu.id] = node
        }
    }

    private func makePowerUpNode(kind: PowerUpKind) -> SKNode {
        let style = Self.powerUpStyle(kind)
        let r = PhysicsConstants.powerUpRadius
        let container = SKNode()
        container.zPosition = 8

        let glow = SKShapeNode(circleOfRadius: r + 3)
        glow.fillColor = style.color.withAlphaComponent(0.20)
        glow.strokeColor = .clear
        container.addChild(glow)

        let disc = SKShapeNode(circleOfRadius: r)
        disc.fillColor = style.color.withAlphaComponent(0.9)
        disc.strokeColor = .white
        disc.lineWidth = 1.5
        container.addChild(disc)

        let label = SKLabelNode(text: style.glyph)
        label.fontName = "AvenirNext-Bold"
        label.fontSize = r * 1.2
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        container.addChild(label)

        // Gentle pulse so pickups read as "collectable".
        container.run(.repeatForever(.sequence([
            .scale(to: 1.12, duration: 0.6),
            .scale(to: 1.0, duration: 0.6)
        ])))
        return container
    }

    private static func powerUpStyle(_ kind: PowerUpKind) -> (color: UIColor, glyph: String) {
        switch kind {
        case .grow:     return (UIColor(red: 0.22, green: 0.85, blue: 0.45, alpha: 1), "+")
        case .shrink:   return (UIColor(red: 0.20, green: 0.75, blue: 0.95, alpha: 1), "-")
        case .speedUp:  return (UIColor(red: 1.00, green: 0.82, blue: 0.20, alpha: 1), "»")
        case .slowDown: return (UIColor(red: 0.70, green: 0.45, blue: 0.95, alpha: 1), "«")
        }
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
        // The simulation clears its event list at the start of every playing
        // step; a shrunken list means a new step began, so restart the cursor.
        if events.count < processedCollisionCount { processedCollisionCount = 0 }
        guard events.count > processedCollisionCount else { return }
        let newEvents = events.suffix(from: processedCollisionCount)
        processedCollisionCount = events.count

        for event in newEvents {
            // Subtle: a light spark, not a burst. Fewer, smaller, softer than before.
            let desired = event.isBallBall ? 12 : 6
            let count = min(desired, maxLiveCollisionParticles - collisionParticles.count)
            guard count > 0 else { continue }
            let colors: [UIColor] = event.isBallBall
                ? [.white, UIColor(red: 1, green: 0.92, blue: 0.6, alpha: 1), UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1)]
                : [.white, UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 1)]
            for _ in 0..<count {
                let angle = CGFloat.random(in: 0..<2 * .pi)
                let speed = CGFloat.random(in: 50...220) * event.intensity
                let radius = max(1, CGFloat.random(in: 1.2...3.5) * event.intensity)
                let node = obtainParticleSprite(texture: Self.circleParticleTexture,
                                                size: CGSize(width: radius * 2, height: radius * 2),
                                                color: colors.randomElement() ?? .white)
                node.position = event.position
                node.zPosition = 20
                shakeNode.addChild(node)
                collisionParticles.append(CollisionParticle(
                    node: node,
                    velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                    lifetime: TimeInterval(CGFloat.random(in: 0.22...0.45))
                ))
            }
        }
    }

    private func updateParticles(dt: CGFloat) {
        // All three arrays are compacted in place (write-index) so a frame never
        // allocates a fresh array, and expired nodes go back to the pool.

        // Collision particles.
        var write = 0
        for read in 0..<collisionParticles.count {
            var p = collisionParticles[read]
            p.age += TimeInterval(dt)
            if p.age >= p.lifetime { recycleParticleSprite(p.node); continue }
            p.velocity.y -= 400 * dt // gravity-like
            p.velocity.x *= 0.94
            p.velocity.y *= 0.94
            p.node.position.x += p.velocity.x * dt
            p.node.position.y += p.velocity.y * dt
            let progress = CGFloat(p.age / p.lifetime)
            p.node.alpha = 0.9 * (1 - progress)
            p.node.setScale(1 - progress * 0.5)
            collisionParticles[write] = p
            write += 1
        }
        collisionParticles.removeLast(collisionParticles.count - write)

        // Trail particles.
        write = 0
        for read in 0..<trailParticles.count {
            var p = trailParticles[read]
            p.age += TimeInterval(dt)
            if p.age >= p.lifetime { recycleParticleSprite(p.node); continue }
            let progress = CGFloat(p.age / p.lifetime)
            // Fade + taper so the tail thins to nothing behind the ball.
            p.node.alpha = 0.22 * (1 - progress)
            p.node.setScale(1 - progress * 0.4)
            trailParticles[write] = p
            write += 1
        }
        trailParticles.removeLast(trailParticles.count - write)

        // Confetti (gravity + rotate).
        write = 0
        for read in 0..<confettiParticles.count {
            let p = confettiParticles[read]
            p.node.position.y -= 300 * dt
            p.node.position.x += p.vx * dt
            p.node.zRotation += p.vr * dt
            p.node.alpha -= 0.5 * dt
            if p.node.alpha <= 0 { recycleParticleSprite(p.node); continue }
            confettiParticles[write] = p
            write += 1
        }
        confettiParticles.removeLast(confettiParticles.count - write)
    }

    // MARK: Ball trail (thin, team-tinted tail that thins out behind the ball)

    private func spawnTrail(for ball: Disc, color: UIColor) {
        let speed = hypot(ball.velocity.x, ball.velocity.y)
        // Fairly continuous while moving, but each dot is tiny and short-lived so
        // the result reads as one thin tail rather than a dust cloud.
        guard speed > 70, CGFloat.random(in: 0...1) < 0.6 else { return }
        let nx = ball.velocity.x / speed
        let ny = ball.velocity.y / speed
        // Sit just behind the ball along its heading, with a slight perpendicular
        // jitter only (no radial scatter) to keep the tail tight and aligned.
        let jitter = CGFloat.random(in: -1.5...1.5)
        let er = ball.effectiveRadius
        let tx = ball.position.x - nx * er * 0.55 + (-ny) * jitter
        let ty = ball.position.y - ny * er * 0.55 + nx * jitter
        let size = max(1.5, er * 0.16)
        let node = obtainParticleSprite(texture: Self.circleParticleTexture,
                                        size: CGSize(width: size * 2, height: size * 2),
                                        color: color)
        node.alpha = 0.22
        node.position = CGPoint(x: tx, y: ty)
        node.zPosition = 5
        shakeNode.addChild(node)
        trailParticles.append(TrailParticle(node: node, lifetime: TimeInterval(CGFloat.random(in: 0.18...0.3))))
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
            let node: SKSpriteNode
            if Bool.random() {
                node = obtainParticleSprite(texture: Self.squareParticleTexture,
                                            size: CGSize(width: size * 3, height: size),
                                            color: colors.randomElement() ?? .white)
            } else {
                node = obtainParticleSprite(texture: Self.circleParticleTexture,
                                            size: CGSize(width: size * 2, height: size * 2),
                                            color: colors.randomElement() ?? .white)
            }
            node.position = CGPoint(x: CGFloat.random(in: -120...120), y: CGFloat.random(in: 200...350))
            node.zPosition = 30
            node.zRotation = CGFloat.random(in: 0..<2 * .pi)
            shakeNode.addChild(node)
            confettiParticles.append(ConfettiParticle(
                node: node,
                vx: CGFloat.random(in: -200...200),
                vr: CGFloat.random(in: -6...6)
            ))
        }
    }
}
