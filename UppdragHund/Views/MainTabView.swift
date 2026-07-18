//
//  MainTabView.swift
//  UppdragHund
//

import SwiftUI

private enum MainTab: Hashable {
    case hem, flode, kalender, profil
}

/// Snapplogga-flöden som widgetens djuplänkar (canine360://logga/…) öppnar.
private enum QuickLogRoute: String, Identifiable {
    case halsa, foder, traning, dagbok

    var id: String { rawValue }

    var module: SharedModule {
        switch self {
        case .halsa: .health
        case .foder: .meals
        case .traning: .training
        case .dagbok: .diary
        }
    }
}

struct MainTabView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @State private var selectedTab: MainTab = .hem
    @State private var quickLogRoute: QuickLogRoute?

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
                Label("Socialt", systemImage: "person.2.fill")
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
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(item: $quickLogRoute) { route in
            if let dog = activeDogStore.activeDog {
                switch route {
                case .halsa: NewHealthEventView(dog: dog)
                case .foder: NewMealEntryView(dog: dog)
                case .traning: NewTrainingSessionView(dog: dog)
                case .dagbok: NewDiaryEntryView(dog: dog)
                }
            }
        }
    }

    /// Widget-djuplänkar: canine360://hem och canine360://logga/{halsa|foder|traning|dagbok}.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetDeepLink.scheme else { return }
        switch url.host() {
        case "hem":
            selectedTab = .hem
        case "logga":
            guard let dog = activeDogStore.activeDog,
                  let route = QuickLogRoute(rawValue: url.lastPathComponent),
                  DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
                      .canLog(in: route.module) else {
                selectedTab = .hem
                return
            }
            selectedTab = .hem
            quickLogRoute = route
        default:
            break
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
