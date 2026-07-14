//
//  MinProfilView.swift
//  UppdragHund
//
//  Profil-flik (f.d. "Mer"). Samlar användarprofil, "Mina hundar"
//  (snabbväxling av aktiv hund + hantering), genvägar och app-inställningar.
//  Visuellt utformad efter Canine360-mockupen.
//

import SwiftUI
import SwiftData

struct MinProfilView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var ownDogs: [Dog]
    @Query(filter: #Predicate<Dog> { $0.isShared }, sort: \Dog.name) private var sharedDogs: [Dog]

    @State private var currentUser = CurrentUserStore.shared
    @State private var authService = AuthService.shared
    @State private var isPresentingAddDog = false
    @State private var isEditingProfile = false

    // Socialt (laddas från Firestore).
    @State private var posts: [ProfilePost] = []
    @State private var friendCount: Int?
    @State private var isPresentingFriends = false
    @State private var isPresentingNewPost = false
    @State private var postPendingDelete: ProfilePost?

    private var allDogs: [Dog] { ownDogs + sharedDogs }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                profileHeader
                statsRow
                dogsCard
                shortcutsCard
                updatesCard
                settingsCard
                logoutButton
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Canine360Wordmark(size: 20)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PlaceholderComingSoonView(title: "Notiser", systemImage: "bell")
                } label: {
                    Image(systemName: "bell")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddDog) {
            AddDogView()
        }
        .sheet(isPresented: $isEditingProfile) {
            if let profile = currentUser.profile {
                EditProfileView(currentProfile: profile)
            }
        }
        .sheet(isPresented: $isPresentingFriends) {
            FriendsView()
        }
        .sheet(isPresented: $isPresentingNewPost) {
            NewPostView(onPosted: { Task { await loadSocial() } })
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
                if let post = postPendingDelete { deletePost(post) }
                postPendingDelete = nil
            }
            Button("Avbryt", role: .cancel) { postPendingDelete = nil }
        }
        .task {
            if currentUser.profile == nil {
                await currentUser.refresh()
            }
            await loadSocial()
        }
    }

    // MARK: - Statistik (Hundar / Vänner / Inlägg)

    private var statsRow: some View {
        HStack(spacing: 0) {
            statTile(value: "\(ownDogs.count)", label: "Hundar")
            statDivider
            Button {
                isPresentingFriends = true
            } label: {
                statTile(value: friendCount.map(String.init) ?? "–", label: "Vänner")
            }
            .buttonStyle(.plain)
            statDivider
            statTile(value: "\(posts.count)", label: "Inlägg")
        }
        .cardStyle()
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Theme.Colors.textSecondary.opacity(0.2))
            .frame(width: 1, height: 28)
    }

    // MARK: - Uppdateringar (inlägg)

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Uppdateringar")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Spacer()
                Button {
                    isPresentingNewPost = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                }
                .accessibilityLabel("Ny uppdatering")
            }

            if posts.isEmpty {
                Text("Du har inte delat något än. Tryck på pennan för att skriva din första uppdatering.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    postRow(post)
                        .contextMenu {
                            Button(role: .destructive) {
                                postPendingDelete = post
                            } label: {
                                Label("Ta bort", systemImage: "trash")
                            }
                        }
                    if index < posts.count - 1 {
                        Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                    }
                }
            }
        }
        .cardStyle()
    }

    private func postRow(_ post: ProfilePost) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(post.text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            HStack(spacing: 6) {
                if let dogName = post.dogName {
                    Label(dogName, systemImage: "pawprint.fill")
                }
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private func loadSocial() async {
        guard let uid = authService.currentUserID else { return }
        posts = (try? await PostsRepository.shared.posts(forUid: uid)) ?? []
        if let friends = try? await FriendsRepository.shared.friends(for: uid) {
            friendCount = friends.count
        }
    }

    private func deletePost(_ post: ProfilePost) {
        guard let uid = authService.currentUserID, let postID = post.id else { return }
        Task {
            try? await PostsRepository.shared.deletePost(authorUid: uid, postID: postID)
            await loadSocial()
        }
    }

    // MARK: - Profilhuvud

    private var profileHeader: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button {
                isEditingProfile = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatar(photoData: currentUser.profile?.photoData, size: 92)
                        .overlay(Circle().stroke(Theme.Colors.brand, lineWidth: 2.5))
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .padding(7)
                        .background(Circle().fill(Theme.Colors.brand))
                        .overlay(Circle().stroke(Theme.Colors.screenBackground, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .disabled(currentUser.profile == nil)

            VStack(spacing: 4) {
                Text(currentUser.profile?.displayName ?? "Din profil")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                if let handle = currentUser.profile?.handle {
                    Text("@\(handle)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Mina hundar

    private var dogsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            cardHeader(title: "Mina hundar", action: "Visa alla") {
                DogListView()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.l) {
                    ForEach(allDogs) { dog in
                        dogAvatarTile(dog)
                    }
                    addDogButton
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .cardStyle()
    }

    private func dogAvatarTile(_ dog: Dog) -> some View {
        let isActive = dog.persistentModelID == activeDogStore.activeDog?.persistentModelID
        return Button {
            activeDogStore.activeDog = dog
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    DogAvatar(photoData: dog.photoData, size: 60, isActive: isActive)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.verified)
                            .background(Circle().fill(Theme.Colors.cardBackground))
                    }
                }
                Text(dog.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text(dog.breed)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var addDogButton: some View {
        Button {
            isPresentingAddDog = true
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.Colors.brand)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(Theme.Colors.brand.opacity(0.12)))
                Text("Lägg till")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text("ny hund")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Genvägar

    private var shortcutsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Mina genvägar")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible()), count: 4),
                spacing: Theme.Spacing.l
            ) {
                shortcut(title: "Hälsa", icon: "stethoscope") { dog in
                    HealthLogView(dog: dog)
                }
                shortcut(title: "Statistik", icon: "chart.bar.fill") { dog in
                    StatistikView(dog: dog)
                }
                shortcut(title: "Träning", icon: "figure.run") { dog in
                    HundtraningView(dog: dog)
                }
                shortcut(title: "Foder", icon: "fork.knife") { dog in
                    FoderdagbokView(dog: dog)
                }
            }
        }
        .cardStyle()
    }

    private func shortcut<Destination: View>(
        title: String,
        icon: String,
        @ViewBuilder destination: @escaping (Dog) -> Destination
    ) -> some View {
        NavigationLink {
            if let dog = activeDogStore.activeDog {
                destination(dog)
            }
        } label: {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.Colors.brand)
                    .frame(height: 28)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inställningar

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingsRow(icon: "gearshape", title: "Inställningar") {
                PlaceholderComingSoonView(title: "Inställningar", systemImage: "gearshape")
            }
            rowDivider
            ShareLink(item: "Kolla in Canine360 – appen för allt om din hund! 🐾") {
                settingsRowLabel(icon: "square.and.arrow.up", title: "Dela appen")
            }
            .buttonStyle(.plain)
            rowDivider
            settingsRow(icon: "arrow.triangle.2.circlepath", title: "Backup & Synk") {
                PlaceholderComingSoonView(title: "Backup & Synk", systemImage: "arrow.triangle.2.circlepath")
            }
            rowDivider
            settingsRow(icon: "lock.shield", title: "Integritetsinställningar") {
                PlaceholderComingSoonView(title: "Integritetsinställningar", systemImage: "lock.shield")
            }
            rowDivider
            settingsRow(icon: "questionmark.circle", title: "Hjälp & Support") {
                PlaceholderComingSoonView(title: "Hjälp & Support", systemImage: "questionmark.circle")
            }
            rowDivider
            settingsRow(icon: "info.circle", title: "Om Canine360") {
                OmOssView()
            }
        }
        .cardStyle(padding: 0)
    }

    private func settingsRow<Destination: View>(
        icon: String,
        title: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            settingsRowLabel(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowLabel(icon: String, title: String) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.Colors.brand)
                .frame(width: 26)
            Text(title)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .contentShape(Rectangle())
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Theme.Colors.textSecondary.opacity(0.2))
            .padding(.leading, 52)
    }

    // MARK: - Delade byggstenar

    private func cardHeader<Destination: View>(
        title: String,
        action: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        HStack {
            Text(title)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Spacer()
            NavigationLink {
                destination()
            } label: {
                Text(action)
                    .font(Theme.Typography.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
            }
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            try? authService.signOut()
        } label: {
            Text("Logga ut")
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.m)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }
}

#Preview {
    NavigationStack {
        MinProfilView()
    }
    .environment(ActiveDogStore())
    .modelContainer(for: Dog.self, inMemory: true)
}
