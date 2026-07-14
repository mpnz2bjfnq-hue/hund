//
//  UsernameValidatorTests.swift
//  UppdragHundTests
//

import Testing
@testable import UppdragHund

struct UsernameValidatorTests {

    @Test func normalizeLowercasesAndStripsLeadingAt() {
        #expect(UsernameValidator.normalize("  @Bella_Dog ") == "bella_dog")
        #expect(UsernameValidator.normalize("ALEX.99") == "alex.99")
    }

    @Test func acceptsValidUsernames() {
        #expect(UsernameValidator.validate("bella") == nil)
        #expect(UsernameValidator.validate("alex.99") == nil)
        #expect(UsernameValidator.validate("dog_owner") == nil)
        #expect(UsernameValidator.validate("@Bella") == nil, "Ledande @ och versaler normaliseras bort")
    }

    @Test func rejectsTooShort() {
        #expect(UsernameValidator.validate("ab") == .tooShort)
    }

    @Test func rejectsTooLong() {
        #expect(UsernameValidator.validate(String(repeating: "a", count: 21)) == .tooLong)
    }

    @Test func rejectsInvalidCharacters() {
        #expect(UsernameValidator.validate("bella dog") == .invalidCharacters)
        #expect(UsernameValidator.validate("bella!") == .invalidCharacters)
        #expect(UsernameValidator.validate("bellaå") == .invalidCharacters)
    }
}
