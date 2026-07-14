//
//  SyncIdentityService.swift
//  UppdragHund
//

import Foundation
import SwiftData

/// Ger alla lokala poster ett stabilt, portabelt ID (`remoteID`) som kan användas
/// som Firestore-dokument-ID vid delning. Körs vid appstart och är idempotent —
/// rader som redan har ett ID lämnas orörda.
enum SyncIdentityService {
    @MainActor
    static func backfillRemoteIDs(context: ModelContext) throws {
        try backfill(Dog.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try backfill(HealthEvent.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try backfill(HeatCycle.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try backfill(DiaryEntry.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try backfill(MealEntry.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try backfill(TrainingSession.self, in: context) { $0.remoteID == nil }
            .forEach { $0.remoteID = UUID() }
        try context.save()
    }

    @MainActor
    private static func backfill<T: PersistentModel>(
        _ type: T.Type,
        in context: ModelContext,
        where predicate: @escaping (T) -> Bool
    ) throws -> [T] {
        // #Predicate stödjer inte generics; hämta allt och filtrera i minnet.
        // Datamängderna är små (en användares egna loggar).
        try context.fetch(FetchDescriptor<T>()).filter(predicate)
    }
}
