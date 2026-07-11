//  TeamNameValidator.swift
//  Core/Models
//
//  Pure validation for custom-team names (CONSTITUTION §4.2 brand safety). No
//  profanity filter, but a blocklist of real Turkish club names is rejected —
//  matched case- and diacritic-insensitively so "Fenerbahçe", "fenerbahce" and
//  "FENERBAHÇE" all fail. Kept pure and standalone so it is unit-testable.

import Foundation

enum TeamNameValidator {
    /// Maximum length of a custom team name.
    static let maxLength = 20

    /// Real-club substrings that may not appear in a custom name (normalised).
    static let blockedClubs = [
        "galatasaray", "fenerbahce", "besiktas", "trabzonspor",
        "goztepe", "bursaspor"
    ]

    enum Failure: Equatable {
        case empty
        case tooLong
        case realClub
        /// String-catalog key for the user-facing message.
        var messageKey: String {
            switch self {
            case .empty:    return "creator.error.empty"
            case .tooLong:  return "creator.error.tooLong"
            case .realClub: return "creator.error.realClub"
            }
        }
    }

    /// Returns `nil` when the trimmed name is acceptable, otherwise the failure.
    static func validate(_ raw: String) -> Failure? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maxLength { return .tooLong }
        let normalized = normalize(trimmed)
        if blockedClubs.contains(where: { normalized.contains($0) }) { return .realClub }
        return nil
    }

    /// Lowercases and strips diacritics so "İ", "ç", "ş" etc. compare equal to
    /// their ASCII forms.
    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US"))
            .replacingOccurrences(of: " ", with: "")
    }
}
