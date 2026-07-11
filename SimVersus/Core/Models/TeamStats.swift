//  TeamStats.swift
//  Core/Models
//
//  A team's mechanical identity: three stats (weight / speed / size) on a 1...5
//  scale sharing a FIXED point budget, so every team spends the same total and
//  differs only in profile — no team is globally stronger (CONSTITUTION §4.6:
//  teams start equal; stats only tilt the feel). The physical values each level
//  maps to live in `PhysicsConstants` (no magic numbers here).
//
//  Effects are deliberately small (±7–15%) so seed/luck stays dominant; stats
//  give a lean, not a guarantee. With the current goal rule (a ball that exits
//  the rotating gap scores for its OWN team) the strategic read is "get your
//  ball to the goal": speed helps reach it, weight resists being shoved off it,
//  size adds presence but also makes the ball a bigger target.

import CoreGraphics

struct TeamStats: Codable, Hashable {
    /// Mass level → `Disc.mass`. Heavier wins collisions but boosts sluggishly.
    let weight: Int
    /// Target-speed level → `targetBallSpeed`. Faster reaches the goal sooner.
    let speed: Int
    /// Radius level → `Disc.radius`. Bigger = more presence, bigger target.
    let size: Int

    /// The neutral 3/3/3 profile — identical to the baseline constants.
    static let balanced = TeamStats(weight: 3, speed: 3, size: 3)

    /// True when every stat is in range and the three sum to the fixed budget.
    var isValid: Bool {
        [weight, speed, size].allSatisfy { PhysicsConstants.statLevelRange.contains($0) }
            && (weight + speed + size) == PhysicsConstants.statBudget
    }

    // MARK: Level → physical value (via PhysicsConstants bands)

    var mass: CGFloat { PhysicsConstants.massByLevel[Self.index(weight)] }
    var targetSpeed: CGFloat { PhysicsConstants.targetSpeedByLevel[Self.index(speed)] }
    var radius: CGFloat { PhysicsConstants.ballRadiusByLevel[Self.index(size)] }

    /// Clamps a 1...5 level to a valid 0-based array index, so malformed data
    /// degrades gracefully to the nearest band edge instead of crashing.
    private static func index(_ level: Int) -> Int {
        min(max(level, PhysicsConstants.statLevelRange.lowerBound),
            PhysicsConstants.statLevelRange.upperBound) - 1
    }
}
