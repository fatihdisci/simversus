//  PhysicsConstants.swift
//  Core/Engine
//
//  Single source of truth for every physics value, generated from
//  PHYSICS_CONSTANTS.md. No magic numbers in the simulation or scene — every
//  tunable lives here with the same name as in the .md.
//
//  TWO-BALL SYSTEM: Two team balls (badge visuals) collide inside a rotating
//  circular arena with a SINGLE goal gap. No player discs — the concept is
//  permanently retired (CONSTITUTION §4.3–4.6, §6).

import Foundation

enum PhysicsConstants {

    // MARK: Arena

    /// Arena radius in fixed simulation-space points. Kept constant (not screen
    /// derived) so the simulation is identical on every device; the scene scales
    /// it to `arenaRenderWidthFraction` of the screen width when rendering.
    static let arenaRadius: CGFloat = 160
    /// Constant rotation speed of the arena wall + gap (rad/s).
    static let arenaRotationSpeed: CGFloat = 0.8
    /// Wall bounce elasticity.
    static let arenaWallRestitution: CGFloat = 0.9
    /// Minimum speed directed away from a wall after contact. Prevents shallow
    /// grazing hits from visually sticking to and sliding around the ring.
    static let minimumWallSeparationSpeed: CGFloat = 105
    /// Fraction of tangential velocity retained after an arena-wall collision.
    /// Gives the rounded wall a little friction so shallow hits visibly rebound.
    static let arenaWallTangentRetention: CGFloat = 0.72
    /// Tiny positional inset after a wall collision, avoiding repeat contact on
    /// the immediately following fixed step due to floating-point tolerance.
    static let wallSeparationInset: CGFloat = 0.75
    /// Angular width of the single goal gap on the arena ring (rad).
    static let gapWidth: CGFloat = 0.54
    /// Extra distance beyond arenaRadius a ball centre must pass to be "out".
    static let exitMargin: CGFloat = 24

    // MARK: Balls (each is a team's badge — no separate ball asset)

    /// Baseline ball radius (level-3 reference). Per-team radius comes from
    /// `TeamStats.size` via `ballRadiusByLevel`; this stays the neutral value.
    static let ballRadius: CGFloat = 28
    /// Restitution when two balls collide.
    static let ballToBallRestitution: CGFloat = 0.85
    /// Restitution when a ball bounces off the arena wall.
    static let ballToWallRestitution: CGFloat = 0.9
    /// Linear damping applied each frame.
    static let ballLinearDamping: CGFloat = 0.06
    /// Angular damping (cosmetic spin decay).
    static let ballAngularDamping: CGFloat = 0.25
    /// Baseline ball mass (level-3 reference). Per-team mass comes from
    /// `TeamStats.weight` via `massByLevel`; this stays the neutral value.
    static let ballMass: CGFloat = 1.0
    /// Random impulse magnitude range applied to each ball at kickoff/reset.
    static let kickoffImpulseRange: ClosedRange<CGFloat> = 85...155

    // MARK: Team stats (per-team modifiers — level 1...5, fixed budget)

    /// Fixed point budget every team (preset or custom) spends across its three
    /// stats, so no team is globally stronger — they only differ in profile.
    static let statBudget: Int = 9
    /// Valid per-stat level range.
    static let statLevelRange: ClosedRange<Int> = 1...5
    /// Level 1...5 → `Disc.mass`. Index 2 (level 3) equals `ballMass` baseline.
    static let massByLevel: [CGFloat] = [0.85, 0.925, 1.00, 1.075, 1.15]
    /// Level 1...5 → `targetBallSpeed`. Index 2 equals `targetBallSpeed` baseline.
    static let targetSpeedByLevel: [CGFloat] = [165, 172.5, 180, 187.5, 195]
    /// Level 1...5 → `Disc.radius`. Index 2 equals `ballRadius` baseline.
    static let ballRadiusByLevel: [CGFloat] = [26, 27, 28, 29, 30]

    // MARK: Boost (periodic self-impulse — keeps balls lively)

    /// Random interval between self-impulses for each ball (seeded RNG).
    static let boostIntervalRange: ClosedRange<CGFloat> = 0.9...2.1
    /// Boost impulse magnitude. All teams equal; future power-ups may scale this.
    static let boostImpulseBase: CGFloat = 28
    /// Random deviation (0–1) added to the boost direction (seeded RNG).
    static let boostDirectionNoise: CGFloat = 0.4

    // MARK: Stall protection (dead-ball prevention for both balls)

    /// Speed below which a ball is "stalling" (pt/s).
    static let stallSpeedThreshold: CGFloat = 4
    /// Seconds a ball may stall before being nudged.
    static let stallTimeThreshold: TimeInterval = 3
    /// Impulse magnitude of the stall nudge.
    static let stallKickImpulse: CGFloat = 15

    // MARK: Speed normalization (Mac-oto inspired — keeps balls lively)

    /// Baseline target speed (level-3 reference). Per-team target comes from
    /// `TeamStats.speed` via `targetSpeedByLevel`; this stays the neutral value.
    static let targetBallSpeed: CGFloat = 180
    /// Blend factor for speed normalization per frame (0–1, lower = smoother).
    static let speedNormalizationBlend: CGFloat = 0.035

    // MARK: Rotation direction changes (Mac-oto inspired — chaotic)

    /// Min/max interval between random rotation direction changes (seconds).
    static let rotationChangeIntervalRange: ClosedRange<CGFloat> = 5...9
    /// Range of possible rotation speeds when direction changes (rad/s).
    static let rotationSpeedRange: ClosedRange<CGFloat> = 0.5...1.05

    // MARK: Power-ups (periodic seeded pickups — temporary ball modifiers)

    /// How long a collected power-up stays active on a ball (seconds).
    static let powerUpDuration: TimeInterval = 5
    /// Seeded interval between power-up spawns (seconds).
    static let powerUpSpawnIntervalRange: ClosedRange<CGFloat> = 8...15
    /// Most power-ups on the pitch at once.
    static let maxActivePowerUps: Int = 2
    /// Pickup collision radius (a ball collects it within its own radius + this).
    static let powerUpRadius: CGFloat = 15
    /// Power-ups spawn within this fraction of the arena radius (reachable, inner).
    static let powerUpSpawnInnerFraction: CGFloat = 0.55
    /// Radius multiplier for the grow / shrink pickups.
    static let powerUpGrowScale: CGFloat = 1.25
    static let powerUpShrinkScale: CGFloat = 0.80
    /// Target-speed multiplier for the speed-up / slow-down pickups.
    static let powerUpSpeedUpScale: CGFloat = 1.25
    static let powerUpSlowScale: CGFloat = 0.80

    // MARK: Match flow

    /// Total real-time match duration. The HUD maps this interval onto 90 match minutes.
    static let matchDuration: TimeInterval = 30
    /// Regulation minutes shown by the HUD regardless of real-time duration.
    static let displayMatchMinutes: Int = 90
    /// Duration of the non-blocking half-time announcement.
    static let halfTimePause: TimeInterval = 1.8
    /// Duration of the non-blocking goal overlay + celebration.
    static let goalCelebrationPause: TimeInterval = 1.6
    /// Simulation speed multiplier (1× in the MVP; 1/2/4× arrives in Phase 2d).
    static let maxSimSpeed: CGFloat = 1

    // MARK: Simulation / rendering

    /// Fixed integration step (120 Hz) — the basis of determinism.
    static let fixedTimeStep: TimeInterval = 1.0 / 120.0
    /// Fraction of the screen width spanned by the rendered arena radius.
    static let arenaRenderWidthFraction: CGFloat = 0.42

    // MARK: Collision categories (bitmask)

    enum Category {
        static let ballHome: UInt32 = 1 << 0
        static let ballAway: UInt32 = 1 << 1
        static let wall: UInt32 = 1 << 2
    }
}
