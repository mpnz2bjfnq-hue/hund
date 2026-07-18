//
//  ShareDogView.swift
//  UppdragHund
//

import SwiftUI

/// Ägarens delningsvy för en hund: välj vän, behörighet och moduler,
/// samt hantera/återkalla befintliga delningar.
struct ShareDogView: View {
    let dog: Dog

    @Environment(\.dismiss) private var dismiss

    @State private var authService = AuthService.shared
    @State private var myProfile: UserProfile?
    @State private var friends: [UserProfile] = []
    @State private var existingShares: [ShareDoc] = []

    @State private var selectedFriendUid: String?
    @State private var permission: SharePermission = .read
    @State private var selectedModules: Set<SharedModule> = Set(SharedModule.allCases)
    @State private var editingShare: ShareDoc?

    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var sharePendingRevoke: ShareDoc?

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isSignedIn {
                    SignInView()
                } else if isLoading {
                    ProgressView("Hämtar vänner…")
                } else {
                    shareForm
                }
            }
            .navigationTitle("Dela \(dog.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
            .task(id: authService.isSignedIn) {
                await loadData()
            }
            .confirmationDialog(
                "Sluta dela med \(displayName(forUid: sharePendingRevoke?.recipientUid))?",
                isPresented: Binding(
                    get: { sharePendingRevoke != nil },
                    set: { if !$0 { sharePendingRevoke = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Sluta dela", role: .destructive) {
                    if let share = sharePendingRevoke {
                        revoke(share)
                    }
                    sharePendingRevoke = nil
                }
                Button("Avbryt", role: .cancel) { sharePendingRevoke = nil }
            } message: {
                Text("Vännen förlorar åtkomst till \(dog.name)s data.")
            }
        }
    }

    private var shareForm: some View {
        Form {
            if !existingShares.isEmpty {
                Section("Delas med") {
                    ForEach(existingShares, id: \.documentID) { share in
                        existingShareRow(share)
                    }
                }
            }

            if editingShare != nil || !availableFriends.isEmpty {
                Section(editingShare == nil ? "Dela med ny vän" : "Ändra delning") {
                    if let editingShare {
                        LabeledContent("Vän", value: displayName(forUid: editingShare.recipientUid))
                    } else {
                        Picker("Vän", selection: $selectedFriendUid) {
                            Text("Välj vän").tag(String?.none)
                            ForEach(availableFriends) { friend in
                                Text(friend.displayName).tag(friend.id)
                            }
                        }
                    }

                    Picker("Behörighet", selection: $permission) {
                        ForEach(SharePermission.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                }

                Section {
                    ForEach(SharedModule.allCases) { module in
                        Toggle(isOn: moduleBinding(module)) {
                            Label(module.displayName, systemImage: module.systemImage)
                        }
                    }
                } header: {
                    Text("Delade moduler")
                } footer: {
                    Text("Hundprofilen (namn, ras, ålder) delas alltid. Foton delas inte.")
                }

                Section {
                    Button(editingShare == nil ? "Dela" : "Spara ändringar") {
                        save()
                    }
                    .disabled(isSaving || (editingShare == nil && selectedFriendUid == nil) || selectedModules.isEmpty)

                    if editingShare != nil {
                        Button("Avbryt ändring", role: .cancel) {
                            resetForm()
                        }
                    }
                }
            } else if existingShares.isEmpty {
                Section {
                    Text("Du har inga vänner att dela med än. Lägg till vänner under Vänner-menyn först.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func existingShareRow(_ share: ShareDoc) -> some View {
        Button {
            beginEditing(share)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName(forUid: share.recipientUid))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(shareSummary(share))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                sharePendingRevoke = share
            } label: {
                Label("Sluta dela", systemImage: "person.badge.minus")
            }
        }
    }

    // MARK: - Derived

    private var availableFriends: [UserProfile] {
        let sharedWith = Set(existingShares.map(\.recipientUid))
        return friends.filter { friend in
            guard let uid = friend.id else { return false }
            return !sharedWith.contains(uid)
        }
    }

    private func displayName(forUid uid: String?) -> String {
        guard let uid else { return "vän" }
        return friends.first { $0.id == uid }?.displayName ?? "Vän"
    }

    private func shareSummary(_ share: ShareDoc) -> String {
        let permissionName = SharePermission(rawValue: share.permission)?.displayName ?? share.permission
        let moduleNames = share.modules
            .compactMap { SharedModule(rawValue: $0)?.displayName }
            .joined(separator: ", ")
        return "\(permissionName) · \(moduleNames)"
    }

    private func moduleBinding(_ module: SharedModule) -> Binding<Bool> {
        Binding(
            get: { selectedModules.contains(module) },
            set: { isOn in
                if isOn {
                    selectedModules.insert(module)
                } else {
                    selectedModules.remove(module)
                }
            }
        )
    }

    // MARK: - Actions

    private func loadData() async {
        guard let uid = authService.currentUserID, let dogRemoteID = dog.remoteID?.uuidString else {
            isLoading = false
            return
        }
        isLoading = true
        do {
            myProfile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            friends = try await FriendsRepository.shared.friends(for: uid)
            existingShares = try await SharingRepository.shared.shares(forDog: dogRemoteID, ownerUid: uid)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func beginEditing(_ share: ShareDoc) {
        editingShare = share
        permission = SharePermission(rawValue: share.permission) ?? .read
        selectedModules = Set(share.modules.compactMap(SharedModule.init(rawValue:)))
    }

    private func resetForm() {
        editingShare = nil
        selectedFriendUid = nil
        permission = .read
        selectedModules = Set(SharedModule.allCases)
    }

    private func save() {
        guard let uid = authService.currentUserID, let myProfile else { return }
        let owner = ShareMapping.Author(uid: uid, name: myProfile.displayName)
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                if let editingShare {
                    try await DogShareService.shared.updateShare(
                        editingShare,
                        dog: dog,
                        newModules: selectedModules,
                        newPermission: permission,
                        owner: owner
                    )
                } else if let selectedFriendUid {
                    try await DogShareService.shared.share(
                        dog: dog,
                        withFriendUid: selectedFriendUid,
                        modules: selectedModules,
                        permission: permission,
                        owner: owner
                    )
                }
                resetForm()
                errorMessage = nil
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func revoke(_ share: ShareDoc) {
        Task {
            do {
                try await DogShareService.shared.revoke(share)
                errorMessage = nil
                await loadData()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ShareDogView(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
}
