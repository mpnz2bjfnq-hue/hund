//
//  TrainingPlanBackupService.swift
//  UppdragHund
//
//  Molnbackup av träningspass-biblioteket. Passen är inte bundna till en hund
//  utan hör till användaren, så de speglas privat under
//  userBackups/{uid}/trainingPlans/{planId}. Reglerna låter bara ägaren läsa
//  och skriva. Backupen är additiv: återställning skapar bara pass som saknas
//  lokalt (raderar aldrig), och en lokal radering tas bort ur molnet direkt.
//

import Foundation
import SwiftData
import FirebaseFirestore

@MainActor
enum TrainingPlanBackupService {

    private static func plansCollection(_ uid: String) -> CollectionReference {
        Firestore.firestore()
            .collection("userBackups").document(uid)
            .collection("trainingPlans")
    }

    // MARK: - Backup

    /// Speglar mina egna pass till molnet. Körs vid inloggning. Pass som hör
    /// till ett annat konto (annan authorUid) rörs inte — biblioteket är
    /// enhetsglobalt men backupen är per användare.
    static func backupAll(context: ModelContext, uid: String) async {
        let plans = ((try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? [])
            .filter { $0.authorUid == uid || $0.authorUid == nil }
        for plan in plans {
            await backup(plan, uid: uid)
        }
    }

    /// Speglar ett enskilt pass (skapa/redigera).
    static func backup(_ plan: TrainingPlan, uid: String) async {
        guard let remoteID = plan.remoteID else { return }
        let dto = ShareMapping.dto(from: plan)
        try? plansCollection(uid).document(remoteID.uuidString).setData(from: dto)
    }

    /// Tar bort ett pass ur molnet (efter lokal radering).
    static func deleteBackup(planRemoteID: UUID, uid: String) async {
        try? await plansCollection(uid).document(planRemoteID.uuidString).delete()
    }

    // MARK: - Restore

    /// Hämtar molnets pass och återskapar de som saknas lokalt. Matchar på
    /// remoteID så inget dubbleras. Körs vid inloggning, tyst vid fel.
    @discardableResult
    static func restore(context: ModelContext, uid: String) async -> Int {
        guard let snapshot = try? await plansCollection(uid).getDocuments() else { return 0 }

        let existing = (try? context.fetch(FetchDescriptor<TrainingPlan>())) ?? []
        let existingIDs = Set(existing.compactMap { $0.remoteID?.uuidString })

        var created = 0
        for document in snapshot.documents where !existingIDs.contains(document.documentID) {
            guard let remoteID = UUID(uuidString: document.documentID),
                  let dto = try? document.data(as: TrainingPlanDTO.self) else { continue }
            let plan = ShareMapping.makePlan(from: dto, remoteID: remoteID)
            context.insert(plan)
            for exercise in plan.exercises { context.insert(exercise) }
            created += 1
        }
        if created > 0 { try? context.save() }
        return created
    }
}
