//
//  EmailAuthValidator.swift
//  UppdragHund
//
//  Ren validering av e-post/lösenord innan de skickas till Firebase.
//  Fångar de vanligaste felen lokalt så användaren slipper en nätverksrunda.
//

import Foundation

enum EmailAuthValidator {
    enum ValidationError: LocalizedError, Equatable {
        case emptyName
        case emptyEmail
        case invalidEmail
        case shortPassword

        var errorDescription: String? {
            switch self {
            case .emptyName: "Ange ett namn."
            case .emptyEmail: "Ange en e-postadress."
            case .invalidEmail: "E-postadressen ser inte giltig ut."
            case .shortPassword: "Lösenordet måste vara minst 6 tecken."
            }
        }
    }

    /// Firebase kräver minst 6 tecken.
    static let minPasswordLength = 6

    /// Validerar inloggning (e-post + lösenord).
    static func validateSignIn(email: String, password: String) -> ValidationError? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty { return .emptyEmail }
        if !isValidEmail(trimmedEmail) { return .invalidEmail }
        if password.count < minPasswordLength { return .shortPassword }
        return nil
    }

    /// Validerar kontoskapande (namn + e-post + lösenord).
    static func validateSignUp(name: String, email: String, password: String) -> ValidationError? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyName }
        return validateSignIn(email: email, password: password)
    }

    static func isValidEmail(_ email: String) -> Bool {
        // Enkel men rimlig kontroll: icke-tomt lokalt, @, domän med punkt.
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
