//
//  SyncPlanner.swift
//  UppdragHund
//
//  Ren synk-planering — inga Firestore- eller SwiftData-beroenden.
//  All merge-/pushlogik som går att enhetstesta bor här.
//

import Foundation

struct MergePlan: Equatable {
    var insert: Set<UUID> = []
    var update: Set<UUID> = []
    var deleteLocal: Set<UUID> = []
}

enum SyncPlanner {

    /// Planerar hur en lokal spegel ska uppdateras mot fjärrläget.
    /// Last-write-wins: `update` endast där fjärrposten är strikt nyare.
    /// `protectedLocal` (t.ex. vännens egna opushade poster) raderas aldrig.
    static func mergePlan(
        remoteIDs: [UUID: Date],
        localIDs: [UUID: Date?],
        protectedLocal: Set<UUID> = []
    ) -> MergePlan {
        var plan = MergePlan()

        for (id, remoteUpdatedAt) in remoteIDs {
            guard let localUpdatedAt = localIDs[id] else {
                plan.insert.insert(id)
                continue
            }
            // Lokal post utan tidsstämpel betraktas som äldre än fjärrposten.
            if localUpdatedAt == nil || localUpdatedAt! < remoteUpdatedAt {
                plan.update.insert(id)
            }
        }

        for id in localIDs.keys where remoteIDs[id] == nil && !protectedLocal.contains(id) {
            plan.deleteLocal.insert(id)
        }

        return plan
    }
}
