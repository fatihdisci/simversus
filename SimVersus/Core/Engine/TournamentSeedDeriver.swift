//  TournamentSeedDeriver.swift
//  Core/Engine
//
//  Deterministic seed derivation using FNV-1a 64-bit. Unlike Swift's Hasher
//  (which randomises per-process), FNV-1a produces identical output across
//  launches — same tournamentSeed + same fixtureID always yields the same
//  UInt64. CONSTITUTION §11 requires deterministic reproducibility.

import Foundation

enum TournamentSeedDeriver {

    /// FNV-1a 64-bit offset basis.
    private static let fnvOffsetBasis: UInt64 = 14_695_981_039_346_656_037
    /// FNV-1a 64-bit prime.
    private static let fnvPrime: UInt64 = 1_099_511_628_211

    /// Produces a stable UInt64 from a tournament seed and fixture identifier.
    /// Never returns 0 (0 is reserved for "unset" in MatchConfig).
    static func derive(tournamentSeed: UInt64, fixtureID: String) -> UInt64 {
        var hash = fnvOffsetBasis

        // Hash the tournament seed as 8 bytes (little-endian).
        var seed = tournamentSeed.littleEndian
        withUnsafeBytes(of: &seed) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* fnvPrime
            }
        }

        // Hash the fixture ID string (UTF-8 bytes).
        for byte in fixtureID.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* fnvPrime
        }

        // 0 is reserved — map it to 1 (astronomically unlikely but safe).
        return hash == 0 ? 1 : hash
    }
}
