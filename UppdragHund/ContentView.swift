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

    var body: some View {
        Group {
            if dogs.isEmpty {
                NavigationStack {
                    DogListView()
                }
            } else {
                MainTabView()
            }
        }
        .environment(activeDogStore)
        .onAppear { ensureActiveDogSelected() }
        .onChange(of: dogs.count) { ensureActiveDogSelected() }
        .task {
            try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
            await BreedDataService.shared.refreshFromRemote()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
                await SharedDogPuller.shared.pull(context: modelContext)
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
