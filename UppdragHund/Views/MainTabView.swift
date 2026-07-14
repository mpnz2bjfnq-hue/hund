//
//  MainTabView.swift
//  UppdragHund
//

import SwiftUI

private enum MainTab: Hashable {
    case kalender, dagbok, hundar, mer
}

struct MainTabView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @State private var selectedTab: MainTab = .kalender
    @State private var showingMerSheet = false

    var body: some View {
        if let activeDog = activeDogStore.activeDog {
            VStack(spacing: 0) {
                DogContextHeader(dog: activeDog)

                TabView(selection: $selectedTab) {
                    NavigationStack {
                        KalenderView(dog: activeDog)
                    }
                    .tabItem {
                        Label("Kalender", systemImage: "calendar")
                    }
                    .tag(MainTab.kalender)

                    NavigationStack {
                        DagbokView(dog: activeDog)
                    }
                    .tabItem {
                        Label("Dagbok", systemImage: "list.clipboard")
                    }
                    .tag(MainTab.dagbok)

                    NavigationStack {
                        DogListView()
                    }
                    .tabItem {
                        Label("Hundar", systemImage: "pawprint")
                    }
                    .tag(MainTab.hundar)

                    Color.clear
                        .tabItem {
                            Label("Mer", systemImage: "ellipsis")
                        }
                        .tag(MainTab.mer)
                }
            }
            .onChange(of: selectedTab) { oldValue, newValue in
                if newValue == .mer {
                    showingMerSheet = true
                    selectedTab = oldValue
                }
            }
            .sheet(isPresented: $showingMerSheet) {
                MerSheetView()
            }
        }
    }
}
