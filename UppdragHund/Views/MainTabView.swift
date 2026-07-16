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
        TabView(selection: $selectedTab) {
            NavigationStack {
                if let activeDog = activeDogStore.activeDog {
                    HemView(dog: activeDog)
                } else {
                    NoDogYetView()
                }
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

            Group {
                if let activeDog = activeDogStore.activeDog {
                    VStack(spacing: 0) {
                        DogContextHeader(dog: activeDog)
                        NavigationStack {
                            KalenderView(dog: activeDog)
                        }
                    }
                } else {
                    NavigationStack {
                        NoDogYetView()
                    }
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
        .onAppear {
            // Utan hund är profilen den naturliga startsidan (nytt konto).
            if activeDogStore.activeDog == nil {
                selectedTab = .profil
            }
        }
    }
}

/// Visas på Hem/Kalender när kontot ännu inte har någon hund.
private struct NoDogYetView: View {
    @State private var isPresentingAddDog = false

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image("Canine360Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 140)
            Text("Ingen hund inlagd än")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Du kan använda flödet, team och träffar utan hund. Lägg till en hund när du vill för att logga hälsa, löp och träning — eller be en vän dela sin hund med dig.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Button {
                isPresentingAddDog = true
            } label: {
                Label("Lägg till hund", systemImage: "plus")
                    .frame(minHeight: 44)
                    .padding(.horizontal, Theme.Spacing.l)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.Colors.brand)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.screenBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Canine360")
            }
        }
        .sheet(isPresented: $isPresentingAddDog) {
            AddDogView()
        }
    }
}
