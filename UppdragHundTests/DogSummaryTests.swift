//
//  DogSummaryTests.swift
//  UppdragHundTests
//

import Testing
import Foundation
import FirebaseFirestore
@testable import UppdragHund

struct DogSummaryTests {

    @Test func roundTripsThroughFirestoreCoders() throws {
        let summary = DogSummary(
            remoteID: UUID().uuidString,
            name: "Bella",
            breed: "Schäfer",
            birthDate: Date(timeIntervalSince1970: 1_700_000_000),
            sex: DogSex.female.rawValue
        )
        let encoded = try Firestore.Encoder().encode(summary)
        let decoded = try Firestore.Decoder().decode(DogSummary.self, from: encoded)
        #expect(decoded == summary)
    }

    @Test func idIsRemoteID() {
        let id = UUID().uuidString
        let summary = DogSummary(remoteID: id, name: "Rex", breed: "Malinois", birthDate: .now, sex: "male")
        #expect(summary.id == id)
    }

    // Wrappern speglar hur ProfilePublisher skriver dogSummaries: Firestore-
    // codecs kräver en struct/dictionary på toppnivån, inte en naken array.
    private struct SummaryWrapper: Codable, Equatable {
        let dogSummaries: [DogSummary]
    }

    @Test func dogSummariesRoundTripInsideDocumentWrapper() throws {
        // Fasta heltalssekund-datum: Firestore-Timestamp trunkerar bråkdelar,
        // så .now skulle göra likhetskontrollen flakig.
        let birth = Date(timeIntervalSince1970: 1_600_000_000)
        let wrapper = SummaryWrapper(dogSummaries: [
            DogSummary(remoteID: UUID().uuidString, name: "Bella", breed: "Schäfer", birthDate: birth, sex: "female"),
            DogSummary(remoteID: UUID().uuidString, name: "Rex", breed: "Malinois", birthDate: birth, sex: "male")
        ])
        let encoded = try Firestore.Encoder().encode(wrapper)
        let decoded = try Firestore.Decoder().decode(SummaryWrapper.self, from: encoded)
        #expect(decoded == wrapper)
    }
}
