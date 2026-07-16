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
    @State private var editingProfile: UserProfile?
    @State private var isPresentingFriends = false
    @State private var postPendingDelete: ProfilePost?
    @State private var loadError: String?

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
                         ? "Du har inte delat något än. Tryck på pennan för att skriva din första uppdatering."
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

            if isOwnProfile {
                Section {
                    Button("Logga ut", role: .destructive) {
                        Task {
                            await PushNotificationService.shared.removeToken()
                            try? authService.signOut()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(isOwnProfile ? "Min profil" : (profile?.displayName ?? "Profil"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingNewPost = true
                    } label: {
                        Label("Ny uppdatering", systemImage: "square.and.pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingNewPost) {
            NewPostView(onPosted: { Task { await load() } })
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileView(currentProfile: profile)
                .onDisappear { Task { await load() } }
        }
        .sheet(isPresented: $isPresentingFriends) {
            FriendsView()
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
            ProfileAvatar(photoData: profile?.photoData, size: 92)
            Text(profile?.displayName ?? (isOwnProfile ? "Din profil" : "Profil"))
                .font(.title2.bold())
            if let handle = profile?.handle {
                Text("@\(handle)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if isOwnProfile {
                Button {
                    editingProfile = profile
                } label: {
                    Label("Redigera profil", systemImage: "pencil")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
                .disabled(profile == nil)
            }
            if let loadError {
                VStack(spacing: 6) {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Försök igen") { Task { await load() } }
                        .font(.caption.weight(.medium))
                }
                .padding(.top, 4)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var statsRow: some View {
        HStack {
            statTile(value: "\(dogCount)", label: "Hundar")
            Divider()
            if isOwnProfile {
                Button {
                    isPresentingFriends = true
                } label: {
                    statTile(value: friendCount.map(String.init) ?? "–", label: "Vänner")
                }
                .buttonStyle(.plain)
            } else {
                statTile(value: friendCount.map(String.init) ?? "–", label: "Vänner")
            }
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
        .contentShape(Rectangle())
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
        loadError = nil
        defer { isLoading = false }
        do {
            // Fånga avkodningsfel separat: ett halvt profil-dokument (t.ex. bara
            // dogSummaries) ska repareras, inte behandlas som ett hårt fel.
            var fetched: UserProfile?
            do {
                fetched = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            } catch {
                fetched = nil
            }
            // Själv-läkning: saknas/trasig egen profil → skapa/reparera och hämta igen.
            if fetched == nil, isOwnProfile {
                let name = AuthService.shared.currentDisplayName ?? "Hundägare"
                try await FriendsRepository.shared.ensureProfile(uid: uid, displayName: name, email: nil)
                fetched = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            }
            profile = fetched
            posts = try await PostsRepository.shared.posts(forUid: uid)
            // Vänners vänlista är privat per reglerna — för andra läses det
            // denormaliserade friendCount från profilen i stället.
            friendCount = isOwnProfile
                ? try await FriendsRepository.shared.syncFriendCount(uid: uid)
                : fetched?.friendCount
            if isOwnProfile, let profile {
                CurrentUserStore.shared.setProfile(profile)
            }
            if isOwnProfile && profile == nil {
                loadError = "Kunde inte ladda din profil. Kontrollera att Firestore-reglerna är publicerade."
            }
        } catch {
            if isOwnProfile {
                loadError = "Kunde inte ladda din profil: \(error.localizedDescription)"
            }
        }
    }

    private func delete(_ post: ProfilePost) {
        Task {
            try? await PostsRepository.shared.delete(post: post)
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
            if let photoData = post.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            if let plan = post.trainingPlan {
                Label("\(plan.title) · \(plan.summaryLine)", systemImage: "list.bullet.rectangle.portrait")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.brand)
            }
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
