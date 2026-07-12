//  NationalTeamStoreTests.swift
//  SimVersusTests
//
//  Validation for the World Arena national team catalog (Commit 2.1): the
//  48-team / 4×12-pot invariants, uniqueness, colour/stat validity, flag render
//  coverage, localization-key presence, the Team adapter, and the World Arena
//  2026 tournament definition (12 groups, 32 knockout slots).

import XCTest
@testable import SimVersus

final class NationalTeamStoreTests: XCTestCase {
    private let store = NationalTeamStore()
    private var teams: [NationalTeamDefinition] { store.allTeams }

    // MARK: - Catalog shape

    func testCatalogHasExactly48Teams() {
        XCTAssertEqual(teams.count, 48)
    }

    func testFourPotsOfTwelve() {
        let byPot = store.teamsByPot
        XCTAssertEqual(Set(byPot.keys), [1, 2, 3, 4])
        for pot in 1...4 {
            XCTAssertEqual(byPot[pot]?.count, 12, "pot \(pot) must hold exactly 12 teams")
        }
    }

    func testPotValuesAreOneThroughFour() {
        XCTAssertTrue(teams.allSatisfy { (1...4).contains($0.pot) })
    }

    // MARK: - Uniqueness

    func testUniqueIDs() { assertUnique(teams.map(\.id)) }
    func testUniqueShortCodes() { assertUnique(teams.map(\.shortCode)) }
    func testUniqueFlagAssets() { assertUnique(teams.map(\.flagAsset)) }
    func testUniqueISOCodes() { assertUnique(teams.map(\.isoCode)) }
    func testUniqueNameKeys() { assertUnique(teams.map(\.nameKey)) }

    func testIDFormatIsNationXX() {
        for team in teams {
            XCTAssertNotNil(team.id.range(of: #"^nation-[a-z]{2}$"#, options: .regularExpression),
                            "\(team.id) must match nation-xx")
        }
    }

    func testISOCodesAreTwoUppercaseLetters() {
        for team in teams {
            XCTAssertNotNil(team.isoCode.range(of: #"^[A-Z]{2}$"#, options: .regularExpression),
                            "\(team.isoCode) is not a valid ISO alpha-2 code")
        }
    }

    func testNoCollisionWithClubTeamIDs() {
        let clubIDs = Set(TeamStore().mvpTeams.map(\.id))
        XCTAssertTrue(teams.allSatisfy { !clubIDs.contains($0.id) })
    }

    // MARK: - Colours

    func testAllColoursAreValidHex() {
        for team in teams {
            XCTAssertTrue(Self.isHex(team.primary), "\(team.id) primary \(team.primary) invalid")
            XCTAssertTrue(Self.isHex(team.secondary), "\(team.id) secondary \(team.secondary) invalid")
            if let t = team.tertiary {
                XCTAssertTrue(Self.isHex(t), "\(team.id) tertiary \(t) invalid")
            }
        }
    }

    // MARK: - Stats

    func testStatsSumToNineAndAreValid() {
        for team in teams {
            let sum = team.stats.weight + team.stats.speed + team.stats.size
            XCTAssertEqual(sum, 9, "\(team.id) stats must sum to 9")
            XCTAssertTrue(team.stats.isValid, "\(team.id) stats out of range")
        }
    }

    // MARK: - Localization keys

    func testEveryTeamHasALocalizedNameInBothLanguages() {
        // A missing key returns the sentinel; a present key returns a real value.
        let sentinel = "__MISSING_LOCALIZATION__"
        for team in teams {
            let resolved = Bundle.main.localizedString(forKey: team.nameKey, value: sentinel, table: nil)
            XCTAssertNotEqual(resolved, sentinel, "missing localization for \(team.nameKey)")
        }
    }

    func testNameKeyFollowsConvention() {
        for team in teams {
            XCTAssertEqual(team.nameKey, "nation.\(team.isoCode.lowercased()).name", "\(team.id) nameKey mismatch")
            XCTAssertFalse(team.nameTR.isEmpty)
            XCTAssertFalse(team.nameEN.isEmpty)
        }
    }

    // MARK: - Flag render coverage

    func testEveryTeamHasAnExplicitFlagDesign() {
        for team in teams {
            XCTAssertTrue(FlagCatalog.explicitFlagAssets.contains(team.flagAsset),
                          "\(team.flagAsset) has no explicit flag design")
            let design = FlagCatalog.design(for: team)
            XCTAssertFalse(design.isFallback, "\(team.id) fell back to a generic flag")
        }
    }

    func testEnglandResolvesStGeorgeCrossViaFlagAsset() {
        // England carries ISO "GB" but must show the football flag (St George
        // upright cross), resolved through flagAsset — never the Union Jack.
        guard let england = store.find("nation-gb") else { return XCTFail("England missing") }
        XCTAssertEqual(england.isoCode, "GB")
        XCTAssertEqual(england.flagAsset, "flag_gb")
        if case .uprightCross = FlagCatalog.design(for: england).arrangement {
            // expected
        } else {
            XCTFail("flag_gb must resolve to an upright cross")
        }
    }

    // MARK: - Team adapter

    func testEveryTeamAdaptsToTeamWithoutLoss() {
        for team in teams {
            let adapted = team.asTeam
            XCTAssertEqual(adapted.id, team.id)
            XCTAssertEqual(adapted.short, team.shortCode)
            XCTAssertEqual(adapted.nameKey, team.nameKey)
            XCTAssertEqual(adapted.stats, team.stats)
            XCTAssertEqual(adapted.badgeShape, team.badgeShape)
            XCTAssertEqual(adapted.baseStrength, 75, "national teams start equal (CONSTITUTION §4.6)")
        }
    }

    func testCatalogRoundTripsThroughCodable() throws {
        // No adapted team should crash encoding/decoding.
        for team in teams {
            let data = try JSONEncoder().encode(team)
            let decoded = try JSONDecoder().decode(NationalTeamDefinition.self, from: data)
            XCTAssertEqual(decoded, team)
        }
    }

    // MARK: - World Arena 2026 definition

    func testWorldArenaHasTwelveGroups() {
        XCTAssertEqual(TournamentDefinition.worldArena2026(catalog: store).groups.count, 12)
    }

    func testWorldArenaHas32KnockoutSlots() {
        XCTAssertEqual(TournamentDefinition.worldArena2026(catalog: store).knockout.slotCount, 32)
    }

    func testWorldArenaPotsAreFourByTwelve() {
        let def = TournamentDefinition.worldArena2026(catalog: store)
        XCTAssertEqual(def.pots.count, 4)
        XCTAssertTrue(def.pots.allSatisfy { $0.count == 12 })
        XCTAssertEqual(def.teamCount, 48)
    }

    func testWorldArenaRoundNameKeysAreLocalizationKeys() {
        let def = TournamentDefinition.worldArena2026(catalog: store)
        XCTAssertEqual(def.knockout.roundNameKeys,
                       [TournamentRoundKey.r32, TournamentRoundKey.r16,
                        TournamentRoundKey.quarterFinal, TournamentRoundKey.semiFinal,
                        TournamentRoundKey.final])
        // Every entry is a key, never a pre-localized display string.
        XCTAssertTrue(def.knockout.roundNameKeys.allSatisfy { $0.hasPrefix("tournament.round.") })
    }

    func testWorldArenaGroupsAdvanceTopTwo() {
        let def = TournamentDefinition.worldArena2026(catalog: store)
        XCTAssertTrue(def.groups.allSatisfy { $0.advanceDirectCount == 2 })
        XCTAssertEqual(def.groups.map(\.id), Array("ABCDEFGHIJKL").map(String.init))
    }

    func testWorldArenaBrandingCarriesLocalizationKeys() {
        let def = TournamentDefinition.worldArena2026(catalog: store)
        XCTAssertEqual(def.kind, .nations2026)
        XCTAssertEqual(def.displayNameKey, "tournament.worldArena.name")
        XCTAssertEqual(def.branding.subtitleKey, "tournament.worldArena.subtitle")
        XCTAssertEqual(def.branding.disclaimerKey, "tournament.worldArena.disclaimer")
        XCTAssertFalse(def.knockout.hasThirdPlaceMatch)
    }

    // MARK: - Helpers

    private func assertUnique(_ values: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(Set(values).count, values.count, "values are not unique", file: file, line: line)
    }

    private static func isHex(_ s: String) -> Bool {
        s.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil
    }
}
