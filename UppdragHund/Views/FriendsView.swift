//
//  FriendsView.swift
//  UppdragHund
//

import SwiftUI

struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var authService = AuthService.shared
    @State private var friends: [UserProfile] = []
    @State private var pendingRequests: [FriendRequest] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                List {
                        if !pendingRequests.isEmpty {
                            Section("Förfrågningar") {
                                ForEach(pendingRequests) { request in
                                    VStack(alignment: .leading, spacing: 6) {
                                        VStack(alignment: .leading) {
                                            Text(request.fromDisplayName)
                                                .font(.headline)
                                            Text("@\(request.fromHandle)")
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
                                Text("Inga vänner än. Lägg till vänner via Lägg till vän på din profil.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(friends) { friend in
                                    NavigationLink {
                                        ProfileView(userID: friend.id)
                                    } label: {
                                        HStack(spacing: Theme.Spacing.m) {
                                            ProfileAvatar(photoData: friend.photoData, size: 36)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(friend.displayName)
                                                Text("@\(friend.handle)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
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
            friends = []
            pendingRequests = []
            return
        }
        do {
            friends = try await FriendsRepository.shared.friends(for: uid)
            pendingRequests = try await FriendsRepository.shared.pendingRequests(for: uid)
        } catch {
            errorMessage = error.localizedDescription
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
