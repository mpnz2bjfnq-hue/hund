//
//  UsernameValidator.swift
//  UppdragHund
//
//  Ren validering + normalisering av användarnamn (@handle). Användarnamnet
//  är samma fält som vänner söker på för att lägga till dig.
//

import Foundation

enum UsernameValidator {
    static let minLength = 3
    static let maxLength = 20

    enum ValidationError: LocalizedError, Equatable {
        case tooShort
        case tooLong
        case invalidCharacters

        var errorDescription: String? {
            switch self {
            case .tooShort: "Användarnamnet måste vara minst \(minLength) tecken."
            case .tooLong: "Användarnamnet får vara högst \(maxLength) tecken."
            case .invalidCharacters: "Använd bara a–z, 0–9, punkt och understreck."
            }
        }
    }

    /// Normaliserar till gemener och trimmar ett inledande @.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    /// Validerar ett redan normaliserat användarnamn.
    static func validate(_ raw: String) -> ValidationError? {
        let value = normalize(raw)
        if value.count < minLength { return .tooShort }
        if value.count > maxLength { return .tooLong }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")
        if value.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return .invalidCharacters
        }
        return nil
    }
}
