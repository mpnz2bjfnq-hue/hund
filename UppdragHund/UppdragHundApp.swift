//
//  UppdragHundApp.swift
//  UppdragHund
//
//  Created by Alex  on 2026-07-13.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct UppdragHundApp: App {
    private let container: ModelContainer

    init() {
        FirebaseApp.configure()
        do {
            container = try ModelContainer(
                for: Dog.self, HealthEvent.self, HeatCycle.self,
                DiaryEntry.self, MealEntry.self, TrainingSession.self,
                SyncTombstone.self
            )
        } catch {
            fatalError("Kunde inte skapa ModelContainer: \(error)")
        }
        SyncCoordinator.shared.configure(container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
