//
//  ContentView.swift
//  UppdragHund
//
//  Created by Alex  on 2026-07-13.
//

import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @State private var activeDogStore = ActiveDogStore()
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var isLoadingProfile = false
    @AppStorage("trainingReminderEnabled") private var trainingReminderEnabled = true

    /// Hundar som hör till det inloggade kontot (kontobyte får inte läcka data).
    private var accountDogs: [Dog] {
        AccountScope.dogs(for: authService.currentUserID, in: dogs)
    }

    /// Aktiverbara hundar: änglar (avlidna) kan minnas men inte väljas som aktiv.
    private var activatableDogs: [Dog] {
        accountDogs.filter { !$0.isDeceased }
    }

    var body: some View {
        Group {
            if !authService.isSignedIn {
                AuthGateView()
            } else if currentUser.profile == nil {
                loadingSplash
            } else if let profile = currentUser.profile, profile.needsProfileSetup {
                CompleteProfileView(profile: profile) {
                    Task { await currentUser.refresh() }
                }
            } else {
                // Ingen hund krävs efter kontoskapandet — utan hund landar man
                // på Min profil och kan gå med i team, lägga till hund senare.
                MainTabView()
            }
        }
        .environment(activeDogStore)
        .onAppear { ensureActiveDogSelected() }
        .task(id: authService.isSignedIn) {
            if authService.isSignedIn {
                if let uid = authService.currentUserID {
                    AccountScope.claimUntaggedData(context: modelContext, uid: uid)
                }
                ensureActiveDogSelected()
                await loadProfile()
                // Hämta delade hundar direkt efter inloggning (scenePhase .active
                // hinner köras före inloggning på första sign-in, annars missas de).
                await SharedDogPuller.shared.pull(context: modelContext)
                await PushNotificationService.shared.registerForPushNotifications()
                await PushNotificationService.shared.syncTokenAfterSignIn()
                if trainingReminderEnabled {
                    await NotificationService.scheduleDailyTrainingReminder()
                } else {
                    NotificationService.cancelDailyTrainingReminder()
                }
                if let uid = authService.currentUserID {
                    await NotificationService.syncMeetupReminders(for: uid)
                }
                await WidgetDataService.refresh(
                    dogs: activatableDogs,
                    activeDog: activeDogStore.activeDog,
                    uid: authService.currentUserID
                )
            }
        }
        .onChange(of: dogs.count) {
            ensureActiveDogSelected()
            if let uid = authService.currentUserID {
                let owned = AccountScope.ownDogs(for: uid, in: dogs)
                Task { await ProfilePublisher.publish(dogs: owned, uid: uid) }
            }
        }
        .task {
            try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
            await BreedDataService.shared.refreshFromRemote()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // Nollställ notisbubblan på appikonen (pusharna sätter badge 1).
                Task { try? await UNUserNotificationCenter.current().setBadgeCount(0) }
                Task {
                    try? SyncIdentityService.backfillRemoteIDs(context: modelContext)
                    // Push före pull så egna ändringar inte hinner skrivas över.
                    await SyncCoordinator.shared.pushDirtyDogs()
                    await SharedDogPuller.shared.pull(context: modelContext)
                    if let uid = authService.currentUserID {
                        await ProfilePublisher.publish(dogs: AccountScope.ownDogs(for: uid, in: dogs), uid: uid)
                        await NotificationService.syncMeetupReminders(for: uid)
                    }
                    await WidgetDataService.refresh(
                        dogs: activatableDogs,
                        activeDog: activeDogStore.activeDog,
                        uid: authService.currentUserID
                    )
                }
            case .background:
                // Bästa försök — Firestore köar offline-skrivningar ändå.
                Task {
                    await SyncCoordinator.shared.pushDirtyDogs()
                    // Widgeten ska spegla det som loggades under sessionen.
                    await WidgetDataService.refresh(
                        dogs: activatableDogs,
                        activeDog: activeDogStore.activeDog,
                        uid: authService.currentUserID
                    )
                }
            default:
                break
            }
        }
        .onChange(of: authService.isSignedIn) { _, isSignedIn in
            if !isSignedIn {
                // Push-token avregistreras FÖRE signOut (i utloggningsknapparna) —
                // här är auth redan borta och skrivningar nekas av reglerna.
                SessionCleanupService.handleSignOut(context: modelContext, activeDogStore: activeDogStore)
                ensureActiveDogSelected()
                Task { await WidgetDataService.refresh(dogs: [], activeDog: nil, uid: nil) }
            }
        }
    }

    private var loadingSplash: some View {
        VStack(spacing: 16) {
            Image("Canine360Logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 160)
            if isLoadingProfile {
                ProgressView()
            } else {
                Text("Kunde inte ladda din profil. Kontrollera din anslutning.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Försök igen") { Task { await loadProfile() } }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadProfile() async {
        isLoadingProfile = true
        await currentUser.refresh()
        isLoadingProfile = false
    }

    private func ensureActiveDogSelected() {
        let available = activatableDogs
        guard !available.isEmpty else {
            activeDogStore.activeDog = nil
            return
        }
        if activeDogStore.activeDog == nil ||
            !available.contains(where: { $0.persistentModelID == activeDogStore.activeDog?.persistentModelID }) {
            activeDogStore.activeDog = available.first
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Dog.self, inMemory: true)
}
