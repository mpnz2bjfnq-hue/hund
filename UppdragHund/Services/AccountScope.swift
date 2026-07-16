//
//  AccountScope.swift
//  UppdragHund
//
//  Knyter lokal data till det inloggade kontot så att kontobyte på samma
//  enhet inte läcker hundar mellan konton. Egna hundar taggas med skaparens
//  uid i `Dog.ownerUid` (samma fält som delade hundar använder för ägaren).
//
//  Äldre hundar (skapade före denna ändring) saknar tagg och "claimas" av
//  det första kontot som loggar in — men bara om det är samma konto som
//  senast var inloggat, eller (första gången) ett konto äldre än ett dygn,
//  så att ett nyskapat test-/granskarkonto inte tar över hundarna.
//

import Foundation
import SwiftData
import FirebaseAuth

enum AccountScope {
    static let lastAccountKey = "lastAccountUid"

    /// Körs vid inloggning: taggar otaggade egna hundar och uppdaterar
    /// senast inloggade konto.
    @MainActor
    static func claimUntaggedData(context: ModelContext, uid: String) {
        defer { UserDefaults.standard.set(uid, forKey: lastAccountKey) }

        let lastUid = UserDefaults.standard.string(forKey: lastAccountKey)
        let accountCreated = Auth.auth().currentUser?.metadata.creationDate ?? .now
        let accountIsEstablished = accountCreated < Calendar.current.date(byAdding: .day, value: -1, to: .now)!

        // Etablerade konton (äldre än ett dygn) får alltid claima otaggat —
        // nyskapade test-/granskarkonton får det aldrig. Efter första claimen
        // finns inga otaggade hundar kvar, så detta är en engångsmigrering.
        guard lastUid == uid || accountIsEstablished else { return }

        let untagged = (try? context.fetch(
            FetchDescriptor<Dog>(predicate: #Predicate { !$0.isShared && $0.ownerUid == nil })
        )) ?? []
        guard !untagged.isEmpty else { return }
        for dog in untagged {
            dog.ownerUid = uid
        }
        try? context.save()
    }

    /// Hundarna som hör till det inloggade kontot: egna taggade + delade
    /// (delade rensas redan vid utloggning och hämtas per konto).
    static func dogs(for uid: String?, in all: [Dog]) -> [Dog] {
        all.filter { $0.isShared || $0.ownerUid == uid }
    }

    static func ownDogs(for uid: String?, in all: [Dog]) -> [Dog] {
        all.filter { !$0.isShared && $0.ownerUid == uid }
    }
}
