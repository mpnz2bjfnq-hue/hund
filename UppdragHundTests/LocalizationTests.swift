//
//  LocalizationTests.swift
//  UppdragHundTests
//
//  Verifierar att den engelska lokaliseringen faktiskt kompileras in i
//  appbundlen och att nycklar med formatspecifierare slås upp korrekt.
//

import Foundation
import Testing

struct LocalizationTests {
    private func englishBundle() throws -> Bundle {
        let path = try #require(
            Bundle.main.path(forResource: "en", ofType: "lproj"),
            "en.lproj saknas i appbundlen — kompilerades språkkatalogen?"
        )
        return try #require(Bundle(path: path))
    }

    @Test func englishLookupsResolve() throws {
        let bundle = try englishBundle()
        #expect(bundle.localizedString(forKey: "Hem", value: "MISSING", table: nil) == "Home")
        #expect(bundle.localizedString(forKey: "Översikt", value: "MISSING", table: nil) == "Overview")
        #expect(bundle.localizedString(forKey: "Tik", value: "MISSING", table: nil) == "Female")
        #expect(bundle.localizedString(forKey: "Veterinärbesök", value: "MISSING", table: nil) == "Vet visit")
        #expect(bundle.localizedString(forKey: "Förlöp", value: "MISSING", table: nil) == "Early heat")
        // Etapp 2: inloggning, fel och notiser.
        #expect(bundle.localizedString(forKey: "Logga in", value: "MISSING", table: nil) == "Sign in")
        #expect(bundle.localizedString(forKey: "Skapa konto", value: "MISSING", table: nil) == "Create account")
        #expect(bundle.localizedString(forKey: "Fel e-post eller lösenord.", value: "MISSING", table: nil) == "Wrong email or password.")
        #expect(bundle.localizedString(forKey: "Löp närmar sig", value: "MISSING", table: nil) == "Heat approaching")
    }

    @Test func englishFormatKeysResolve() throws {
        let bundle = try englishBundle()
        let format = bundle.localizedString(forKey: "Dag %lld", value: "MISSING", table: nil)
        #expect(String(format: format, 5) == "Day 5")

        let birthday = bundle.localizedString(forKey: "🎂 %@ fyller %lld år om %lld dagar", value: "MISSING", table: nil)
        #expect(String(format: birthday, "Ronja", 3, 12) == "🎂 Ronja turns 3 in 12 days")
    }

    @Test func swedishStaysAsSource() {
        // Källspråket är svenska — utan en-uppslag ska literalen användas rakt av.
        let value = Bundle.main.localizedString(forKey: "Nyckel som inte finns", value: nil, table: nil)
        #expect(value == "Nyckel som inte finns")
    }
}
