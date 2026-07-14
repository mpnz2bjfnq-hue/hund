//
//  ContentView.swift
//  UppdragHund
//
//  Created by Alex  on 2026-07-13.
//

import SwiftUI
import SwiftData

struct ContentView: View {
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
            await BreedDataService.shared.refreshFromRemote()
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
