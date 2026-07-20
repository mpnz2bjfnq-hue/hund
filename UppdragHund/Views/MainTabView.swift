//
//  MainTabView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

private enum MainTab: Hashable {
    case hem, flode, kalender, profil
}

/// Snapplogga-flöden som widgetens djuplänkar (canine360://logga/…) öppnar.
private enum QuickLogRoute: String, Identifiable {
    case halsa, foder, traning, dagbok, promenad

    var id: String { rawValue }

    var module: SharedModule {
        switch self {
        case .halsa: .health
        case .foder: .meals
        case .traning, .promenad: .training
        case .dagbok: .diary
        }
    }
}

/// En snapplogga-begäran: flöde + vilken hund det gäller (widgeten kan vara
/// inställd på en annan hund än den aktiva).
private struct QuickLogRequest: Identifiable {
    let id = UUID()
    let route: QuickLogRoute
    let dog: Dog
}

/// Vart ett notistryck leder. Innehållet hämtas asynkront ur Firestore innan
/// bladet visas, så länken funkar även när vyn inte redan har datat.
private enum PushDestination: Identifiable {
    case team(Team)
    case meetup(Meetup)
    case friends

    var id: String {
        switch self {
        case .team(let team): "team-\(team.id ?? "")"
        case .meetup(let meetup): "meetup-\(meetup.id ?? "")"
        case .friends: "friends"
        }
    }
}

struct MainTabView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @Environment(DeepLinkStore.self) private var deepLinks
    @Query private var dogs: [Dog]
    @State private var selectedTab: MainTab = .hem
    @State private var quickLog: QuickLogRequest?
    @State private var pushDestination: PushDestination?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                if let activeDog = activeDogStore.activeDog {
                    HemView(dog: activeDog)
                } else {
                    NoDogYetView()
                }
            }
            .tabTransition()
            .tabItem {
                Label("Hem", systemImage: "house.fill")
            }
            .tag(MainTab.hem)

            NavigationStack {
                FeedView()
            }
            .tabTransition()
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
            .tabTransition()
            .tabItem {
                Label("Kalender", systemImage: "calendar")
            }
            .tag(MainTab.kalender)

            NavigationStack {
                MinProfilView()
            }
            .tabTransition()
            .tabItem {
                Label("Min profil", systemImage: "person.crop.circle")
            }
            .tag(MainTab.profil)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .onAppear {
            // Utan hund är profilen den naturliga startsidan (nytt konto).
            if activeDogStore.activeDog == nil {
                selectedTab = .profil
            }
        }
        // Djuplänkar buffras i ContentView (kallstart) och konsumeras här.
        .task { consumePendingDeepLink() }
        .onChange(of: deepLinks.pending) { _, _ in
            consumePendingDeepLink()
        }
        .sheet(item: $quickLog) { request in
            switch request.route {
            case .halsa: NewHealthEventView(dog: request.dog)
            case .foder: NewMealEntryView(dog: request.dog)
            case .traning: NewTrainingSessionView(dog: request.dog)
            case .dagbok: NewDiaryEntryView(dog: request.dog)
            case .promenad: WalkTrackerView(dog: request.dog, autoStart: true)
            }
        }
        .sheet(item: $pushDestination) { destination in
            switch destination {
            case .team(let team):
                // TeamPageView pushas normalt in i en stack — som blad behöver
                // den en egen, plus ett sätt att stänga.
                NavigationStack {
                    TeamPageView(team: team)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Klar") { pushDestination = nil }
                            }
                        }
                }
            case .meetup(let meetup):
                MeetupDetailView(meetup: meetup)
            case .friends:
                FriendsView()
            }
        }
    }

    private func consumePendingDeepLink() {
        guard let url = deepLinks.pending else { return }
        deepLinks.pending = nil
        handleDeepLink(url)
    }

    /// Widget-djuplänkar: canine360://hem och
    /// canine360://logga/{halsa|foder|traning|dagbok}?dog={remoteID}.
    /// Notisdjuplänkar (via PushRoute): canine360://team?id=…, ://meetup?id=…,
    /// ://vanner och ://socialt.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == WidgetDeepLink.scheme else { return }
        switch url.host() {
        case "hem":
            selectedTab = .hem
        case "socialt":
            selectedTab = .flode
        case "vanner":
            selectedTab = .profil
            pushDestination = .friends
        case "team":
            selectedTab = .flode
            guard let id = queryValue(url, name: "id") else { return }
            Task {
                if let team = await TeamsRepository.shared.team(id: id) {
                    pushDestination = .team(team)
                }
            }
        case "meetup":
            selectedTab = .flode
            guard let id = queryValue(url, name: "id") else { return }
            Task {
                if let meetup = await TeamsRepository.shared.meetup(id: id) {
                    pushDestination = .meetup(meetup)
                }
            }
        case "logga":
            guard let dog = resolveDog(from: url),
                  let route = QuickLogRoute(rawValue: url.lastPathComponent),
                  DogAccess(dog: dog, currentUid: AuthService.shared.currentUserID)
                      .canLog(in: route.module) else {
                selectedTab = .hem
                return
            }
            selectedTab = .hem
            quickLog = QuickLogRequest(route: route, dog: dog)
        default:
            break
        }
    }

    private func queryValue(_ url: URL, name: String) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == name }?.value
    }

    /// Hunden ur länkens ?dog=-parameter (kontots hundar), annars den aktiva.
    private func resolveDog(from url: URL) -> Dog? {
        guard let id = queryValue(url, name: "dog") else {
            return activeDogStore.activeDog
        }
        return AccountScope.dogs(for: AuthService.shared.currentUserID, in: dogs)
            .first { $0.remoteID?.uuidString == id }
            ?? activeDogStore.activeDog
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
        .background(Theme.screenSurface)
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
