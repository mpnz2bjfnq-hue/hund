//
//  ContentView.swift
//  UppdragHund
//
//  Created by Alex  on 2026-07-13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @State private var activeDogStore = ActiveDogStore()
    @State private var authService = AuthService.shared

    var body: some View {
        Group {
            if !authService.isSignedIn {
                AuthGateView()
            } else if dogs.isEmpty {
                NavigationStack {
                    DogListView()
                }
            } else {
                MainTabView()
            }
        }
        .environment(activeDogStore)
        .onAppear { ensureActiveDogSelected() }
        .onChange(of: dogs.count) {
            ensureActiveDogSelected()
            if let uid = authService.currentUserID {
                Task { await ProfilePublisher.publish(dogs: dogs, uid: uid) }
            }
        }
        .task {
            try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
            await BreedDataService.shared.refreshFromRemote()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
                    // Push före pull så egna ändringar inte hinner skrivas över.
                    await SyncCoordinator.shared.pushDirtyDogs()
                    await SharedDogPuller.shared.pull(context: modelContext)
                    if let uid = authService.currentUserID {
                        await ProfilePublisher.publish(dogs: dogs, uid: uid)
                    }
                }
            case .background:
                // Bästa försök — Firestore köar offline-skrivningar ändå.
                Task { await SyncCoordinator.shared.pushDirtyDogs() }
            default:
                break
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if !isSignedIn {
                SessionCleanupService.handleSignOut(context: modelContext, activeDogStore: activeDogStore)
                ensureActiveDogSelected()
            }
        }
    }

    private func ensureActiveDogSelected() {
        guard !dogs.isEmpty else {
            activeDogStore.activeDog = nil
            return
        }
        if activeDogStore.activeDog == nil ||
            !dogs.contains(where: { $0.persistentModelID == activeDogStore.activeDog?.persistentModelID }) {
            activeDogStore.activeDog = dogs.first
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Dog.self, inMemory: true)
}
