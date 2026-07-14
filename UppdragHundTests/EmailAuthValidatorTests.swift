//
//  EmailAuthValidatorTests.swift
//  UppdragHundTests
//

import Testing
@testable import UppdragHund

struct EmailAuthValidatorTests {

    // MARK: isValidEmail

    @Test func acceptsWellFormedEmails() {
        #expect(EmailAuthValidator.isValidEmail("alex@example.com"))
        #expect(EmailAuthValidator.isValidEmail("a.b+tag@sub.domain.se"))
    }

    @Test func rejectsMalformedEmails() {
        #expect(!EmailAuthValidator.isValidEmail(""))
        #expect(!EmailAuthValidator.isValidEmail("alex"))
        #expect(!EmailAuthValidator.isValidEmail("alex@"))
        #expect(!EmailAuthValidator.isValidEmail("alex@example"))
        #expect(!EmailAuthValidator.isValidEmail("alex example.com"))
        #expect(!EmailAuthValidator.isValidEmail("@example.com"))
    }

    // MARK: validateSignIn

    @Test func signInFlagsEmptyEmailFirst() {
        #expect(EmailAuthValidator.validateSignIn(email: "  ", password: "secret123") == .emptyEmail)
    }

    @Test func signInFlagsInvalidEmail() {
        #expect(EmailAuthValidator.validateSignIn(email: "nope", password: "secret123") == .invalidEmail)
    }

    @Test func signInFlagsShortPassword() {
        #expect(EmailAuthValidator.validateSignIn(email: "a@b.com", password: "12345") == .shortPassword)
    }

    @Test func signInAcceptsValidInput() {
        #expect(EmailAuthValidator.validateSignIn(email: "a@b.com", password: "123456") == nil)
    }

    // MARK: validateSignUp

    @Test func signUpRequiresName() {
        #expect(EmailAuthValidator.validateSignUp(name: "  ", email: "a@b.com", password: "123456") == .emptyName)
    }

    @Test func signUpFallsThroughToEmailAndPasswordChecks() {
        #expect(EmailAuthValidator.validateSignUp(name: "Alex", email: "bad", password: "123456") == .invalidEmail)
        #expect(EmailAuthValidator.validateSignUp(name: "Alex", email: "a@b.com", password: "x") == .shortPassword)
        #expect(EmailAuthValidator.validateSignUp(name: "Alex", email: "a@b.com", password: "123456") == nil)
    }
}
