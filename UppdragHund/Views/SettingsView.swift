//
//  SettingsView.swift
//  UppdragHund
//
//  App-inställningar: notis-reglage och radera konto. Reglagen lagras i
//  UserDefaults via @AppStorage och styr schemaläggningen i NotificationService.
//

import SwiftUI
import SwiftData
import LocalAuthentication
#if DEBUG
import FirebaseCore
import FirebaseAppCheck
#endif

struct SettingsView: View {
    @AppStorage("trainingReminderEnabled") private var trainingReminderEnabled = true
    @AppStorage("heatRemindersEnabled") private var heatRemindersEnabled = true
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    @Environment(\.modelContext) private var modelContext
    @State private var authService = AuthService.shared

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        List {
            Section {
                Picker("Färgläge", selection: $appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Utseende")
            } footer: {
                Text("System följer telefonens ljusa eller mörka läge automatiskt.")
            }

            Section {
                Toggle("Träningspåminnelse", isOn: $trainingReminderEnabled)
                Toggle("Löp-påminnelser", isOn: $heatRemindersEnabled)
            } header: {
                Text("Notiser")
            } footer: {
                Text("Träningspåminnelsen kommer varje dag kl. 12. Löp-påminnelser meddelar 7 dagar före förväntat löp och dagligen under ett pågående löp.")
            }

            Section {
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("Blockerade användare", systemImage: "hand.raised")
                }
            } header: {
                Text("Socialt")
            }

            #if DEBUG
            // Endast utvecklingsbyggen: token som ska godkännas i Firebase-
            // konsolen (App Check → Debug tokens) innan enforcement slås på.
            Section {
                if let app = FirebaseApp.app() {
                    let token = AppCheckDebugProvider(app: app)?.currentDebugToken() ?? "–"
                    Button {
                        UIPasteboard.general.string = token
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("App Check debug-token (tryck för att kopiera)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(token)
                                .font(.caption2.monospaced())
                        }
                    }
                }
            } header: {
                Text("Utveckling")
            }
            #endif

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        if isDeleting {
                            ProgressView()
                            Text("Raderar…")
                        } else {
                            Text("Radera konto")
                        }
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("Konto")
            } footer: {
                Text("Raderar ditt konto och all din information permanent. Detta går inte att ångra.")
            }
        }
        .navigationTitle("Inställningar")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.Colors.brand)
        .onChange(of: trainingReminderEnabled) { _, enabled in
            Task {
                if enabled {
                    guard await NotificationService.requestAuthorizationIfNeeded() else { return }
                    await NotificationService.scheduleDailyTrainingReminder()
                } else {
                    NotificationService.cancelDailyTrainingReminder()
                }
            }
        }
        .onChange(of: heatRemindersEnabled) { _, enabled in
            if !enabled {
                Task { await NotificationService.cancelAllHeatNotifications() }
            }
        }
        .confirmationDialog(
            "Radera kontot permanent?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Radera allt", role: .destructive) { authenticateThenDelete() }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Din profil, dina inlägg, dina hundar och all data tas bort permanent. Detta går inte att ångra.")
        }
        .alert(
            "Kunde inte radera kontot",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    /// Kräver Face ID / Touch ID / lösenkod innan raderingen körs.
    private func authenticateThenDelete() {
        let context = LAContext()
        context.localizedFallbackTitle = "Använd lösenkod"
        var authError: NSError?
        let reason = "Bekräfta att du vill radera ditt konto."

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            // Ingen biometri/lösenkod aktiverad på enheten – bekräftelsedialogen får räcka.
            deleteAccount()
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            Task { @MainActor in
                if success { deleteAccount() }
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await AccountDeletionService.shared.deleteAccount()
                await MainActor.run {
                    wipeLocalData()
                    try? authService.signOut()
                }
            } catch {
                await MainActor.run {
                    deleteError = "Försök igen. (\(error.localizedDescription))"
                    isDeleting = false
                }
            }
        }
    }

    /// Rensar all lokal data efter att kontot raderats i molnet.
    @MainActor
    private func wipeLocalData() {
        do {
            for dog in try modelContext.fetch(FetchDescriptor<Dog>()) {
                modelContext.delete(dog)
            }
            for tombstone in try modelContext.fetch(FetchDescriptor<SyncTombstone>()) {
                modelContext.delete(tombstone)
            }
            try modelContext.save()
        } catch {
            // Bäst-försök; ContentView städar vidare vid utloggning.
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
