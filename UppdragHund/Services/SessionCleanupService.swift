//
//  SessionCleanupService.swift
//  UppdragHund
//

import Foundation
import SwiftData

/// Städar bort delningsrelaterad lokal data när användaren loggar ut.
/// Egna hundar och deras fjärrkopior lämnas orörda — de synkar tillbaka
/// vid nästa inloggning.
enum SessionCleanupService {
    @MainActor
    static func handleSignOut(context: ModelContext, activeDogStore: ActiveDogStore) {
        CurrentUserStore.shared.clear()
        // Blockeringslistan är per konto — nästa inloggade konto ska inte
        // filtrera innehåll mot förra kontots blockeringar.
        ModerationService.shared.clearCache()
        do {
            // Delade hundar (ägda av någon annan) tas bort — cascade städar posterna.
            let sharedDogs = try context.fetch(
                FetchDescriptor<Dog>(predicate: #Predicate { $0.isShared })
            )
            if activeDogStore.activeDog?.isShared == true {
                activeDogStore.activeDog = nil
            }
            for dog in sharedDogs {
                context.delete(dog)
            }

            // Tombstones och pending-flaggor hör till den utloggade sessionen.
            for tombstone in try context.fetch(FetchDescriptor<SyncTombstone>()) {
                context.delete(tombstone)
            }
            for dog in try context.fetch(FetchDescriptor<Dog>()) {
                dog.needsUpload = false
                dog.lastSyncedAt = nil
            }
            clearPendingUploads(context: context)

            try context.save()
        } catch {
            // Bäst-försök-städning; misslyckas den städas det vid nästa tillfälle.
        }
    }

    @MainActor
    private static func clearPendingUploads(context: ModelContext) {
        (try? context.fetch(FetchDescriptor<HealthEvent>()))?.forEach { $0.pendingUpload = false }
        (try? context.fetch(FetchDescriptor<HeatCycle>()))?.forEach { $0.pendingUpload = false }
        (try? context.fetch(FetchDescriptor<DiaryEntry>()))?.forEach { $0.pendingUpload = false }
        (try? context.fetch(FetchDescriptor<MealEntry>()))?.forEach { $0.pendingUpload = false }
        (try? context.fetch(FetchDescriptor<TrainingSession>()))?.forEach { $0.pendingUpload = false }
    }
}
