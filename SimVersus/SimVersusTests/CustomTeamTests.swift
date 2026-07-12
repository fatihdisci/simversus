//  CustomTeamTests.swift
//  SimVersusTests
//
//  Covers the custom-team building blocks: name validation (incl. the
//  diacritic-insensitive real-club blocklist), the CustomTeam→Team adapter,
//  and the kit-pattern region paths.

import XCTest
@testable import SimVersus

final class CustomTeamTests: XCTestCase {

    // MARK: Name validation

    func testBlocklistMatchesAcrossCaseAndDiacritics() {
        for name in ["Fenerbahçe", "fenerbahce", "FENERBAHÇE", "Beşiktaş", "besiktas",
                     "Galatasaray", "Trabzonspor", "Göztepe"] {
            XCTAssertEqual(TeamNameValidator.validate(name), .realClub, "\(name) should be blocked")
        }
    }

    func testCleanNamesPass() {
        let longestAllowedName = "Kuzey Yıldızlar 1907"
        XCTAssertEqual(longestAllowedName.count, TeamNameValidator.maxLength)

        for name in ["Ankara Yıldızları", "Mavi Şimşekler", longestAllowedName] {
            XCTAssertNil(TeamNameValidator.validate(name), "\(name) should be allowed")
        }
    }

    func testEmptyAndTooLongRejected() {
        XCTAssertEqual(TeamNameValidator.validate("   "), .empty)
        XCTAssertEqual(TeamNameValidator.validate(String(repeating: "a", count: 21)), .tooLong)
    }

    // MARK: Adapter

    func testAsTeamCarriesStatsPatternAndShort() {
        let custom = CustomTeam(name: "Mor Ejderler",
                                primaryHex: "#5B2E7E", secondaryHex: "#E8C33A",
                                badgeShape: .diamond, pattern: .checkered,
                                stats: TeamStats(weight: 5, speed: 2, size: 2))
        let team = custom.asTeam
        XCTAssertEqual(team.badgeShape, .diamond)
        XCTAssertEqual(team.pattern, .checkered)
        XCTAssertEqual(team.stats, TeamStats(weight: 5, speed: 2, size: 2))
        XCTAssertEqual(team.short, "MOR")
        XCTAssertEqual(team.primary, "#5B2E7E")
    }

    func testShortCodeFallsBackWhenNoLetters() {
        XCTAssertEqual(CustomTeam.shortCode(from: "!!!"), "CUS")
    }

    // MARK: Patterns

    func testSolidPatternHasNoSecondaryRegions() {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        XCTAssertTrue(KitPattern.solid.secondaryRegions(in: rect).isEmpty)
    }

    func testNonSolidPatternsDrawSomething() {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40)
        for pattern in KitPattern.allCases where pattern != .solid {
            XCTAssertFalse(pattern.secondaryRegions(in: rect).isEmpty, "\(pattern) should draw regions")
        }
    }
}
