//
//  ProfileView.swift
//  UppdragHund
//
//  Instagram-lik profilsida. Samma vy för egen profil (userID == nil) och
//  en väns profil (userID satt). Visar header, statistik, hundar och inlägg.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    /// nil = den inloggade användarens egen profil.
    var userID: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var ownDogs: [Dog]

    @State private var authService = AuthService.shared
    @State private var profile: UserProfile?
    @State private var posts: [ProfilePost] = []
    @State private var friendCount: Int?
    @State private var isLoading = true
    @State private var isPresentingNewPost = false
    @State private var postPendingDelete: ProfilePost?

    private var resolvedUID: String? {
        userID ?? authService.currentUserID
    }

    private var isOwnProfile: Bool {
        userID == nil || userID == authService.currentUserID
    }

    /// Hundar att visa: egna lokala för egen profil, annars vännens summering.
    private var dogRows: [DogDisplay] {
        if isOwnProfile {
            return ownDogs.map { DogDisplay(id: $0.remoteID?.uuidString ?? UUID().uuidString, name: $0.name, breed: $0.breed) }
        }
        return (profile?.dogSummaries ?? []).map { DogDisplay(id: $0.remoteID, name: $0.name, breed: $0.breed) }
    }

    private var dogCount: Int {
        isOwnProfile ? ownDogs.count : (profile?.dogSummaries?.count ?? 0)
    }

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            statsRow
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if !dogRows.isEmpty {
                Section("Hundar") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(dogRows) { dog in
                                dogCard(dog)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            Section("Uppdateringar") {
                if isLoading && posts.isEmpty {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if posts.isEmpty {
                    Text(isOwnProfile
                         ? "Du har inte delat något än. Tryck på + för att skriva din första uppdatering."
                         : "Inga uppdateringar än.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(posts) { post in
                        PostRow(post: post)
                            .swipeActions(edge: .trailing) {
                                if isOwnProfile {
                                    Button(role: .destructive) {
                                        postPendingDelete = post
                                    } label: {
                                        Label("Ta bort", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(isOwnProfile ? "Min profil" : (profile?.displayName ?? "Profil"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Stäng") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewPost = true
                    } label: {
                        Label("Ny uppdatering", systemImage: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Logga ut", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingNewPost) {
            NewPostView(onPosted: { Task { await load() } })
        }
        .confirmationDialog(
            "Ta bort uppdateringen?",
            isPresented: Binding(
                get: { postPendingDelete != nil },
                set: { if !$0 { postPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Ta bort", role: .destructive) {
                if let post = postPendingDelete { delete(post) }
                postPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) { postPendingDelete = nil }
        }
        .task(id: resolvedUID) {
            await load()
        }
    }

    // MARK: - Delvyer

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.tint)
            Text(profile?.displayName ?? (isOwnProfile ? "Din profil" : "Profil"))
                .font(.title2.bold())
            if let handle = profile?.handle {
                Text(handle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var statsRow: some View {
        HStack {
            statTile(value: "\(dogCount)", label: "Hundar")
            Divider()
            statTile(value: friendCount.map(String.init) ?? "–", label: "Vänner")
            Divider()
            statTile(value: "\(posts.count)", label: "Inlägg")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func dogCard(_ dog: DogDisplay) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(dog.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
            Text(dog.breed)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 96)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data

    private func load() async {
        guard let uid = resolvedUID else { isLoading = false; return }
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            posts = try await PostsRepository.shared.posts(forUid: uid)
            // Vänners vänlista är privat per reglerna — bara läsbar för egen profil.
            friendCount = isOwnProfile ? try await FriendsRepository.shared.friends(for: uid).count : nil
        } catch {
            // Behåll det som redan laddats; tyst fel (offline etc.)
        }
    }

    private func delete(_ post: ProfilePost) {
        guard let uid = authService.currentUserID, let postID = post.id else { return }
        Task {
            try? await PostsRepository.shared.deletePost(authorUid: uid, postID: postID)
            await load()
        }
    }

    private struct DogDisplay: Identifiable {
        let id: String
        let name: String
        let breed: String
    }
}

private struct PostRow: View {
    let post: ProfilePost

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.text)
                .font(.body)
            HStack(spacing: 6) {
                if let dogName = post.dogName {
                    Label(dogName, systemImage: "pawprint.fill")
                }
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
