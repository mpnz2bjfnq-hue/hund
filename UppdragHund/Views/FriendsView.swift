//
//  FriendsView.swift
//  UppdragHund
//

import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var authService = AuthService.shared
    @State private var myProfile: UserProfile?
    @State private var friends: [UserProfile] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var handleInput = ""
    @State private var errorMessage: String?
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Group {
                List {
                        if let myProfile {
                            Section("Din kod") {
                                LabeledContent("Kod", value: myProfile.handle)
                                Text("Dela den här koden med en vän så de kan lägga till dig.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section("Lägg till vän") {
                            HStack {
                                TextField("Väns kod, t.ex. DOG-1234", text: $handleInput)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                Button("Skicka") {
                                    sendRequest()
                                }
                                .disabled(handleInput.trimmingCharacters(in: .whitespaces).isEmpty || isSending)
                            }
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }

                        if !pendingRequests.isEmpty {
                            Section("Förfrågningar") {
                                ForEach(pendingRequests) { request in
                                    VStack(alignment: .leading, spacing: 6) {
                                        VStack(alignment: .leading) {
                                            Text(request.fromDisplayName)
                                                .font(.headline)
                                            Text(request.fromHandle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        HStack {
                                            Button("Acceptera") {
                                                respond(request, accept: true)
                                            }
                                            .buttonStyle(.borderedProminent)
                                            Button("Neka") {
                                                respond(request, accept: false)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        Section("Mina vänner (\(friends.count))") {
                            if friends.isEmpty {
                                Text("Inga vänner än.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(friends) { friend in
                                    Text(friend.displayName)
                                }
                            }
                        }

                        Section {
                            Button("Logga ut", role: .destructive) {
                                try? authService.signOut()
                            }
                        }
                    }
                .refreshable {
                    await loadData()
                }
            }
            .navigationTitle("Vänner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
            }
            .task(id: authService.isSignedIn) {
                await loadData()
            }
        }
    }

    private func loadData() async {
        guard let uid = authService.currentUserID else {
            myProfile = nil
            friends = []
            pendingRequests = []
            return
        }
        do {
            myProfile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            friends = try await FriendsRepository.shared.friends(for: uid)
            pendingRequests = try await FriendsRepository.shared.pendingRequests(for: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendRequest() {
        guard let uid = authService.currentUserID, let myProfile else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await FriendsRepository.shared.sendFriendRequest(
                    from: uid,
                    myDisplayName: myProfile.displayName,
                    myHandle: myProfile.handle,
                    toHandle: handleInput.trimmingCharacters(in: .whitespaces).uppercased()
                )
                handleInput = ""
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func respond(_ request: FriendRequest, accept: Bool) {
        Task {
            try? await FriendsRepository.shared.respondToRequest(request, accept: accept)
            await loadData()
        }
    }
}

#Preview {
    FriendsView()
}
