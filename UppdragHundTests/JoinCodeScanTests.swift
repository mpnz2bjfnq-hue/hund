//
//  JoinCodeScanTests.swift
//  UppdragHundTests
//
//  QR-skanningen ska förstå både djuplänken och äldre QR-koder med rå kod.
//

import Testing
@testable import UppdragHund

struct JoinCodeScanTests {
    @Test func extractsCodeFromDeepLink() {
        #expect(JoinTeamByCodeView.extractCode(from: "canine360://team/join?code=ABCD2345") == "ABCD2345")
    }

    @Test func rawCodePassesThroughUnchanged() {
        #expect(JoinTeamByCodeView.extractCode(from: "ABCD-2345") == "ABCD-2345")
    }

    @Test func foreignURLIsNotTreatedAsDeepLink() {
        // En QR med någon annans URL ska inte ge en tom kod — join-anropet
        // avvisar den i stället (servern validerar koden).
        #expect(JoinTeamByCodeView.extractCode(from: "https://example.com?code=X") == "https://example.com?code=X")
    }
}
