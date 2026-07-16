//
//  MainTabView.swift
//  UppdragHund
//

import SwiftUI

private enum MainTab: Hashable {
    case hem, flode, kalender, profil
}

struct MainTabView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @State private var selectedTab: MainTab = .hem

    var body: some View {
        if let activeDog = activeDogStore.activeDog {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    HemView(dog: activeDog)
                }
                .tabItem {
                    Label("Hem", systemImage: "house.fill")
                }
                .tag(MainTab.hem)

                NavigationStack {
                    FeedView()
                }
                .tabItem {
                    Label("Flöde", systemImage: "text.bubble")
                }
                .tag(MainTab.flode)

                VStack(spacing: 0) {
                    DogContextHeader(dog: activeDog)
                    NavigationStack {
                        KalenderView(dog: activeDog)
                    }
                }
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }
                .tag(MainTab.kalender)

                NavigationStack {
                    MinProfilView()
                }
                .tabItem {
                    Label("Min profil", systemImage: "person.crop.circle")
                }
                .tag(MainTab.profil)
            }
        }
    }
}
