//
//  ProfilePublisher.swift
//  UppdragHund
//
//  Håller den publika hundlistan (dogSummaries) på användarens profil-doc
//  uppdaterad, så att vänner kan se vilka hundar man har på ens profil.
//

import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
enum ProfilePublisher {
    /// Speglar användarens egna (icke-delade) hundar till users/{uid}.dogSummaries.
    /// Skriver bara om listan faktiskt ändrats sedan förra publiceringen.
    static func publish(dogs: [Dog], uid: String) async {
        let summaries = dogs
            .filter { !$0.isShared }
            .compactMap { dog -> DogSummary? in
                guard let remoteID = dog.remoteID?.uuidString else { return nil }
                return DogSummary(
                    remoteID: remoteID,
                    name: dog.name,
                    breed: dog.breed,
                    birthDate: dog.birthDate,
                    sex: dog.sex.rawValue
                )
            }
            .sorted { $0.name < $1.name }

        guard summaries != lastPublished[uid] else { return }

        do {
            let data = try Firestore.Encoder().encode(summaries)
            try await Firestore.firestore().collection("users").document(uid)
                .setData(["dogSummaries": data], merge: true)
            lastPublished[uid] = summaries
        } catch {
            // Tyst fel (offline etc.) — försöks igen nästa gång.
        }
    }

    /// Enkel cache så vi inte skriver samma lista upprepat per app-session.
    private static var lastPublished: [String: [DogSummary]] = [:]
}
