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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer

    init() {
        Canine360AppCheckFactory.activate()
        FirebaseApp.configure()
        do {
            container = try ModelContainer(
                for: Dog.self, HealthEvent.self, HeatCycle.self,
                DiaryEntry.self, MealEntry.self, TrainingSession.self,
                TrainingPlan.self, TrainingPlanExercise.self,
                TrainingSkill.self,
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
                // Appen är låst till mörkt läge. Ljust läge är byggt (adaptiva
                // färger, .adaptiveShadow, kortens ljusvarianter) men väljaren
                // är borttagen inför App Store-inlämningen: snabb växling fram
                // och tillbaka kunde låsa huvudtråden tills watchdogen dödade
                // appen. Låst läge betyder ingen övergång alls, alltså ingen
                // risk. Slås på igen i 1.1 när växlingen är verifierad.
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
