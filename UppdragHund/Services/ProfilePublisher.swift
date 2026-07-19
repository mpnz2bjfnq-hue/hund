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
import UIKit

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
                    sex: dog.sex.rawValue,
                    isDeceased: dog.isDeceased,
                    deceasedDate: dog.passedAwayDate,
                    photoData: dog.photoData
                        .flatMap(UIImage.init(data:))
                        .flatMap { AvatarImage.makeThumbnailData(from: $0, side: 128) },
                    hdResult: dog.hdResult,
                    edResult: dog.edResult,
                    mentalTest: dog.mentalTestDone,
                    showMerit: dog.showMerit,
                    vaccinated: dog.vaccinated,
                    chipped: dog.chipNumber?.isEmpty == false
                )
            }
            .sorted { $0.name < $1.name }

        // SKYDD: publicera ALDRIG en tom lista. Tomt betyder nästan alltid att
        // den lokala storen inte hunnit laddas (t.ex. direkt efter inloggning
        // eller ominstallation) — inte att användaren raderat alla hundar. Att
        // skriva tomt skulle radera molnbackupen. Riktig radering av sista
        // hunden hanteras separat vid själva raderingen.
        guard !summaries.isEmpty else { return }

        guard summaries != lastPublished[uid] else { return }

        do {
            // setData(from:) kräver att toppnivån är en struct/dictionary — därför
            // en wrapper snarare än att encoda arrayen direkt.
            try Firestore.firestore().collection("users").document(uid)
                .setData(from: SummaryUpdate(dogSummaries: summaries), merge: true)
            lastPublished[uid] = summaries
        } catch {
            // Tyst fel (offline etc.) — försöks igen nästa gång.
        }
    }

    private struct SummaryUpdate: Codable {
        let dogSummaries: [DogSummary]
    }

    /// Enkel cache så vi inte skriver samma lista upprepat per app-session.
    private static var lastPublished: [String: [DogSummary]] = [:]
}
