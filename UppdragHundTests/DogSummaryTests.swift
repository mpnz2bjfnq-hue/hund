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

    @Test func userProfileDecodesWithoutDogSummaries() throws {
        // Äldre profiler saknar fältet — måste fortfarande kunna läsas.
        let data: [String: Any] = [
            "displayName": "Alex",
            "handle": "DOG-ABCDE",
            "createdAt": Timestamp(date: .now)
        ]
        let profile = try Firestore.Decoder().decode(UserProfile.self, from: data)
        #expect(profile.displayName == "Alex")
        #expect(profile.dogSummaries == nil)
    }
}
