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
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Dog.self, HealthEvent.self, HeatCycle.self, DiaryEntry.self, MealEntry.self, TrainingSession.self])
    }
}
