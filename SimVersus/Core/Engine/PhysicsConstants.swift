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
    /// Angular width of the single goal gap on the arena ring (rad).
    static let gapWidth: CGFloat = 0.28
    /// Extra distance beyond arenaRadius a ball centre must pass to be "out".
    static let exitMargin: CGFloat = 14

    // MARK: Balls (each is a team's badge — no separate ball asset)

    /// Badge-sized ball radius. Large because "ball" = team identity.
    static let ballRadius: CGFloat = 28
    /// Restitution when two balls collide.
    static let ballToBallRestitution: CGFloat = 0.85
    /// Restitution when a ball bounces off the arena wall.
    static let ballToWallRestitution: CGFloat = 0.9
    /// Linear damping applied each frame.
    static let ballLinearDamping: CGFloat = 0.06
    /// Angular damping (cosmetic spin decay).
    static let ballAngularDamping: CGFloat = 0.25
    /// Fixed mass for all balls (teams are equal strength; power-ups may modify later).
    static let ballMass: CGFloat = 1.0
    /// Random impulse magnitude range applied to each ball at kickoff/reset.
    static let kickoffImpulseRange: ClosedRange<CGFloat> = 85...155

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

    /// Target speed balls are normalized toward each frame (pt/s).
    static let targetBallSpeed: CGFloat = 180
    /// Blend factor for speed normalization per frame (0–1, lower = smoother).
    static let speedNormalizationBlend: CGFloat = 0.035

    // MARK: Rotation direction changes (Mac-oto inspired — chaotic)

    /// Min/max interval between random rotation direction changes (seconds).
    static let rotationChangeIntervalRange: ClosedRange<CGFloat> = 5...9
    /// Range of possible rotation speeds when direction changes (rad/s).
    static let rotationSpeedRange: ClosedRange<CGFloat> = 0.5...1.05

    // MARK: Match flow

    /// Real seconds of play → shown as 90 minutes (1 s = 1 min).
    static let matchDuration: TimeInterval = 90
    /// Pause at half time before the second-half kickoff.
    static let halfTimePause: TimeInterval = 2.0
    /// Pause after a goal (score overlay + celebration).
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
