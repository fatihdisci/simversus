//  WorldBracketGenerationTests.swift
//  SimVersusTests
//
//  Tests for WorldKnockoutBracket shape, R32 pairing, source wiring, and
//  determinism (Commit 4).

import XCTest
@testable import SimVersus

final class WorldBracketGenerationTests: XCTestCase {

    private let catalog = NationalTeamStore()
    private lazy var definition = TournamentDefinition.worldArena2026(catalog: catalog)

    // MARK: - Helpers

    private func makeQualifiers(seed: UInt64) throws -> (
        groups: [GroupAssignment],
        qualifiers: WorldKnockoutQualifiers,
        standings: [GroupStanding]
    ) {
        let stage = try TournamentEngine.generateWorldGroupStage(
            definition: definition, catalog: catalog, tournamentSeed: seed)
        let groups = stage.groups
        var results: [FixtureResult] = []
        for f in stage.fixtures {
            let raw = f.seed
            results.append(FixtureResult(
                fixtureID: f.id,
                homeScore: Int((raw >> 3) % 5),
                awayScore: Int((raw >> 7) % 5),
                winnerTeamID: nil, goals: [], isSimulated: true))
        }
        var standings: [String: [GroupStanding]] = [:]
        var allStandings: [GroupStanding] = []
        for group in groups {
            let s = WorldGroupStageEngine.standings(
                for: group, fixtures: stage.fixtures, results: results,
                tournamentSeed: seed)
            standings[group.id] = s
            allStandings.append(contentsOf: s)
        }
        let bestThirds = try WorldGroupStageEngine.bestThirdPlacedQualifiers(
            groups: groups, fixtures: stage.fixtures, results: results,
            tournamentSeed: seed)
        let qualifiers = try WorldKnockoutQualifiers.make(
            groups: groups, standingsByGroup: standings,
            bestThirdPlacedTeamIDs: bestThirds)
        return (groups, qualifiers, allStandings)
    }

    private func generateBracket(seed: UInt64) throws -> WorldKnockoutBracket {
        let (_, qualifiers, standings) = try makeQualifiers(seed: seed)
        return try WorldBracketResolver.generate(
            definition: definition, qualifiers: qualifiers,
            groupStandings: standings, tournamentSeed: seed)
    }

    // MARK: - Shape tests

    func testThirtyOneFixtures() throws {
        let bracket = try generateBracket(seed: 42)
        XCTAssertEqual(bracket.fixtures.count, 31)
    }

    func testFixtureCountsByRound() throws {
        let bracket = try generateBracket(seed: 42)
        XCTAssertEqual(bracket.r32Fixtures.count, 16)
        XCTAssertEqual(bracket.r16Fixtures.count, 8)
        XCTAssertEqual(bracket.quarterFinals.count, 4)
        XCTAssertEqual(bracket.semiFinals.count, 2)
        XCTAssertNotNil(bracket.final)
    }

    func testAllFixtureIDsUnique() throws {
        let bracket = try generateBracket(seed: 42)
        let ids = bracket.fixtures.map(\.id)
        XCTAssertEqual(Set(ids).count, 31)
    }

    func testAllSeedsNonzero() throws {
        let bracket = try generateBracket(seed: 42)
        for f in bracket.fixtures {
            XCTAssertNotEqual(f.seed, 0, "Fixture \(f.id) has seed 0")
        }
    }

    func testRoundValuesCorrect() throws {
        let bracket = try generateBracket(seed: 42)
        for f in bracket.r32Fixtures { XCTAssertEqual(f.round, 1) }
        for f in bracket.r16Fixtures { XCTAssertEqual(f.round, 2) }
        for f in bracket.quarterFinals { XCTAssertEqual(f.round, 3) }
        for f in bracket.semiFinals { XCTAssertEqual(f.round, 4) }
        XCTAssertEqual(bracket.final?.round, 5)
    }

    func testMatchIndicesContiguous() throws {
        let bracket = try generateBracket(seed: 42)
        let indices = bracket.fixtures.map(\.matchIndex).sorted()
        XCTAssertEqual(indices, Array(0..<31))
    }

    func testR32FixtureIDsFollowConvention() throws {
        let bracket = try generateBracket(seed: 42)
        for f in bracket.r32Fixtures {
            XCTAssertTrue(f.id.hasPrefix("WA-R32-M"), "Bad ID: \(f.id)")
        }
    }

    func testLaterRoundFixtureIDsFollowConvention() throws {
        let bracket = try generateBracket(seed: 42)
        for f in bracket.r16Fixtures {
            XCTAssertTrue(f.id.hasPrefix("WA-R16-M"), "Bad ID: \(f.id)")
        }
        for f in bracket.quarterFinals {
            XCTAssertTrue(f.id.hasPrefix("WA-QF-M"), "Bad ID: \(f.id)")
        }
        for f in bracket.semiFinals {
            XCTAssertTrue(f.id.hasPrefix("WA-SF-M"), "Bad ID: \(f.id)")
        }
        XCTAssertTrue(bracket.final?.id.hasPrefix("WA-F-M") ?? false)
    }

    // MARK: - Qualifier coverage

    func testAll32QualifiersAppearInR32() throws {
        let bracket = try generateBracket(seed: 42)
        let r32Teams = bracket.r32Fixtures.flatMap { [$0.homeTeamID, $0.awayTeamID] }
        XCTAssertEqual(Set(r32Teams), Set(bracket.qualifierTeamIDs))
        XCTAssertEqual(r32Teams.count, 32)
    }

    func testNoTeamAppearsTwiceInR32() throws {
        let bracket = try generateBracket(seed: 42)
        let r32Teams = bracket.r32Fixtures.flatMap { [$0.homeTeamID, $0.awayTeamID] }
        XCTAssertEqual(Set(r32Teams).count, 32)
    }

    func testNoSelfMatchInR32() throws {
        let bracket = try generateBracket(seed: 42)
        for f in bracket.r32Fixtures {
            XCTAssertNotEqual(f.homeTeamID, f.awayTeamID,
                              "Fixture \(f.id) has same home and away")
        }
    }

    // MARK: - Determinism

    func testSameSeedSameBracket() throws {
        let a = try generateBracket(seed: 99)
        let b = try generateBracket(seed: 99)
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedChangesAtLeastOnePairing() throws {
        // Run 20 seed pairs; at least one should produce a different R32 pairing.
        var foundDifferent = false
        for seed in stride(from: 1, through: 40, by: 2) {
            let a = try generateBracket(seed: UInt64(seed))
            let b = try generateBracket(seed: UInt64(seed + 1))
            let aIDs = Set(a.r32Fixtures.flatMap { [$0.homeTeamID, $0.awayTeamID] })
            let bIDs = Set(b.r32Fixtures.flatMap { [$0.homeTeamID, $0.awayTeamID] })
            // Same qualifier set, but the PAIRINGS differ.
            if a != b { foundDifferent = true; break }
        }
        XCTAssertTrue(foundDifferent, "At least one seed pair should produce a different bracket")
    }

    // MARK: - Source wiring

    func testR16SourcesReferenceR32Winners() throws {
        let bracket = try generateBracket(seed: 42)
        let r32IDs = Set(bracket.r32Fixtures.map(\.id))
        for f in bracket.r16Fixtures {
            if case .winner(let refID) = f.homeSource {
                XCTAssertTrue(r32IDs.contains(refID),
                              "R16 home source \(refID) not in R32 fixture IDs")
            } else {
                XCTFail("R16 home source should be .winner(of:)")
            }
            if case .winner(let refID) = f.awaySource {
                XCTAssertTrue(r32IDs.contains(refID),
                              "R16 away source \(refID) not in R32 fixture IDs")
            } else {
                XCTFail("R16 away source should be .winner(of:)")
            }
        }
    }

    func testQFSourceReferencesR16Winners() throws {
        let bracket = try generateBracket(seed: 42)
        let r16IDs = Set(bracket.r16Fixtures.map(\.id))
        for f in bracket.quarterFinals {
            if case .winner(let refID) = f.homeSource {
                XCTAssertTrue(r16IDs.contains(refID))
            } else { XCTFail("QF source should be .winner(of:)") }
            if case .winner(let refID) = f.awaySource {
                XCTAssertTrue(r16IDs.contains(refID))
            } else { XCTFail("QF source should be .winner(of:)") }
        }
    }

    func testSFSourceReferencesQFWinners() throws {
        let bracket = try generateBracket(seed: 42)
        let qfIDs = Set(bracket.quarterFinals.map(\.id))
        for f in bracket.semiFinals {
            if case .winner(let refID) = f.homeSource {
                XCTAssertTrue(qfIDs.contains(refID))
            } else { XCTFail("SF source should be .winner(of:)") }
        }
    }

    func testFinalSourceReferencesSFWinners() throws {
        let bracket = try generateBracket(seed: 42)
        let sfIDs = Set(bracket.semiFinals.map(\.id))
        guard let final = bracket.final else { XCTFail("No final"); return }
        if case .winner(let refID) = final.homeSource {
            XCTAssertTrue(sfIDs.contains(refID))
        } else { XCTFail("Final source should be .winner(of:)") }
        if case .winner(let refID) = final.awaySource {
            XCTAssertTrue(sfIDs.contains(refID))
        } else { XCTFail("Final source should be .winner(of:)") }
    }

    func testNoCircularSources() throws {
        let bracket = try generateBracket(seed: 42)
        // Every .winner(of:) reference must point to an earlier round.
        let fixtureByID = Dictionary(uniqueKeysWithValues: bracket.fixtures.map { ($0.id, $0) })
        for f in bracket.fixtures where f.round > 1 {
            if case .winner(let refID) = f.homeSource {
                guard let refFixture = fixtureByID[refID] else {
                    XCTFail("Source \(refID) not found"); continue
                }
                XCTAssertLessThan(refFixture.round, f.round,
                                  "\(f.id) references \(refID) from same or later round")
            }
        }
    }

    // MARK: - Has valid shape

    func testHasValidShape() throws {
        let bracket = try generateBracket(seed: 42)
        XCTAssertTrue(bracket.hasValidShape)
    }

    func testHasValidQualifierCoverage() throws {
        let bracket = try generateBracket(seed: 42)
        XCTAssertTrue(bracket.hasValidQualifierCoverage)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let bracket = try generateBracket(seed: 42)
        let data = try JSONEncoder().encode(bracket)
        let decoded = try JSONDecoder().decode(WorldKnockoutBracket.self, from: data)
        XCTAssertEqual(bracket.fixtures.count, decoded.fixtures.count)
        XCTAssertEqual(bracket.createdFromTournamentSeed, decoded.createdFromTournamentSeed)
        XCTAssertEqual(bracket.qualifierTeamIDs, decoded.qualifierTeamIDs)
    }

    // MARK: - Many seeds

    func testTwentyBracketsCompleteSuccessfully() throws {
        for seed in 1...20 {
            let bracket = try generateBracket(seed: UInt64(seed))
            XCTAssertTrue(bracket.hasValidShape, "Seed \(seed) produced invalid shape")
            XCTAssertTrue(bracket.hasValidQualifierCoverage,
                          "Seed \(seed) has qualifier coverage issue")
        }
    }
}
