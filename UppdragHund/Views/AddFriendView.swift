//
//  AddFriendView.swift
//  UppdragHund
//
//  Dedikerat flöde för att lägga till vänner: sök på @användarnamn eller
//  namn och få live-förslag på konton som matchar.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var query = ""
    @State private var results: [UserProfile] = []
    @State private var friends: Set<String> = []
    @State private var requestedHandles: Set<String> = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Theme.Colors.textSecondary)
                        TextField("Sök @användarnamn eller namn", text: $query)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } footer: {
                    if query.trimmingCharacters(in: .whitespaces).count < 2 {
                        Text("Skriv minst två tecken så föreslår vi konton som matchar.")
                    }
                }

                if !results.isEmpty {
                    Section("Förslag") {
                        ForEach(results) { profile in
                            resultRow(profile)
                        }
                    }
                } else if isSearching {
                    Section { HStack { Spacer(); ProgressView(); Spacer() } }
                } else if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                    Section {
                        Text("Inga konton matchar \u{201C}\(query)\u{201D} än.")
                            .foregroundStyle(Theme.Colors.textSecondary)
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
            .navigationTitle("Lägg till vän")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.Colors.brand)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
            .onChange(of: query) { search() }
            .task { await loadFriends() }
        }
    }

    @ViewBuilder
    private func resultRow(_ profile: UserProfile) -> some View {
        let isFriend = profile.id.map { friends.contains($0) } ?? false
        let isRequested = requestedHandles.contains(profile.handle)

        HStack(spacing: Theme.Spacing.m) {
            ProfileAvatar(photoData: profile.photoData, size: 38)
                .tint(Theme.Colors.brand)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.displayName)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("@\(profile.handle)")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer()
            if isFriend {
                Label("Vänner", systemImage: "checkmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
            } else if isRequested {
                Label("Skickad", systemImage: "paperplane.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                Button {
                    sendRequest(to: profile)
                } label: {
                    Label("Lägg till", systemImage: "person.badge.plus")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(Theme.Colors.brand)
            }
        }
    }

    private func search() {
        errorMessage = nil
        searchTask?.cancel()
        let text = query
        guard text.trimmingCharacters(in: .whitespaces).count >= 2,
              let uid = authService.currentUserID else {
            results = []
            return
        }
        isSearching = true
        searchTask = Task {
            // Debounce så vi inte frågar Firestore på varje tangenttryck.
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let found = await FriendsRepository.shared.searchUsers(matching: text, excludingUid: uid)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    private func loadFriends() async {
        guard let uid = authService.currentUserID else { return }
        let list = (try? await FriendsRepository.shared.friends(for: uid)) ?? []
        friends = Set(list.compactMap(\.id))
    }

    private func sendRequest(to profile: UserProfile) {
        guard let uid = authService.currentUserID,
              let myProfile = currentUser.profile else { return }
        Task {
            do {
                try await FriendsRepository.shared.sendFriendRequest(
                    from: uid,
                    myDisplayName: myProfile.displayName,
                    myHandle: myProfile.handle,
                    toHandle: profile.handle
                )
                requestedHandles.insert(profile.handle)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
