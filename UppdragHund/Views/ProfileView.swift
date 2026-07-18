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
    @State private var selectedDog: DogDisplay?

    private var resolvedUID: String? {
        userID ?? authService.currentUserID
    }

    private var isOwnProfile: Bool {
        userID == nil || userID == authService.currentUserID
    }

    /// Hundar att visa: egna lokala för egen profil, annars vännens summering.
    private var dogRows: [DogDisplay] {
        if isOwnProfile {
            return ownDogs.map { dog in
                DogDisplay(
                    id: dog.remoteID?.uuidString ?? UUID().uuidString,
                    name: dog.name,
                    breed: dog.breed,
                    birthDate: dog.birthDate,
                    sexName: dog.sex.displayName,
                    isAngel: dog.isDeceased,
                    deceasedDate: dog.passedAwayDate,
                    badges: DogBadge.badges(for: dog)
                )
            }
        }
        return (profile?.dogSummaries ?? []).map { summary in
            DogDisplay(
                id: summary.remoteID,
                name: summary.name,
                breed: summary.breed,
                birthDate: summary.birthDate,
                sexName: DogSex(rawValue: summary.sex)?.displayName,
                isAngel: summary.isAngel,
                deceasedDate: summary.deceasedDate,
                badges: summary.badges
            )
        }
    }

    private var activeDogRows: [DogDisplay] { dogRows.filter { !$0.isAngel } }
    private var angelRows: [DogDisplay] { dogRows.filter(\.isAngel) }

    private var dogCount: Int { activeDogRows.count }

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            statsRow
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if let photos = profile?.favoritePhotoDatas, !photos.isEmpty {
                Section("Favoritbilder") {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(photos.indices, id: \.self) { index in
                            if let image = UIImage(data: photos[index]) {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if !activeDogRows.isEmpty {
                Section("Hundar") {
                    dogCarousel(activeDogRows)
                }
            }

            if !angelRows.isEmpty {
                Section("Änglar 🌈") {
                    dogCarousel(angelRows)
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
                            // På raden så bekräftelsen dyker upp intill den.
                            .confirmationDialog(
                                "Ta bort uppdateringen?",
                                isPresented: Binding(
                                    get: { postPendingDelete?.id == post.id },
                                    set: { if !$0 { postPendingDelete = nil } }
                                ),
                                titleVisibility: .visible
                            ) {
                                Button("Ta bort", role: .destructive) {
                                    delete(post)
                                    postPendingDelete = nil
                                }
                                Button("Avbryt", role: .cancel) { postPendingDelete = nil }
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
        .sheet(item: $selectedDog) { dog in
            DogSummarySheet(dog: dog)
        }
        .task(id: resolvedUID) {
            await load()
        }
    }

    // MARK: - Delvyer

    private var header: some View {
        VStack(spacing: 8) {
            // Omslagsbild à la Facebook: kant till kant, raka hörn, avataren
            // överlappar nederkanten.
            if let cover = profile?.coverPhotoData, let image = UIImage(data: cover) {
                ZStack(alignment: .bottom) {
                    Color.clear
                        .frame(height: 190)
                        .overlay(
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        )
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.35)],
                                startPoint: .center, endPoint: .bottom
                            )
                        )
                        .clipped()
                        .padding(.horizontal, -20)
                    ProfileAvatar(photoData: profile?.photoData, size: 92)
                        .overlay(Circle().stroke(Theme.Colors.brand, lineWidth: 2.5))
                        .offset(y: 46)
                }
                .padding(.bottom, 46)
            } else {
                ProfileAvatar(photoData: profile?.photoData, size: 92)
            }
            Text(profile?.displayName ?? (isOwnProfile ? "Din profil" : "Profil"))
                .font(.title2.bold())
            if let handle = profile?.handle {
                Text("@\(handle)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let bio = profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, 2)
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
            if !angelRows.isEmpty {
                Divider()
                statTile(value: "\(angelRows.count)", label: "Änglar 🌈")
            }
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

    private func dogCarousel(_ dogs: [DogDisplay]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(dogs) { dog in
                    dogCard(dog)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }

    private func dogCard(_ dog: DogDisplay) -> some View {
        Button {
            selectedDog = dog
        } label: {
            VStack(spacing: 6) {
                Image(systemName: dog.isAngel ? "rainbow" : "pawprint.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(dog.isAngel ? .multicolor : .monochrome)
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
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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

    struct DogDisplay: Identifiable {
        let id: String
        let name: String
        let breed: String
        var birthDate: Date?
        var sexName: String?
        var isAngel: Bool = false
        var deceasedDate: Date?
        var badges: [DogBadge] = []
    }
}

/// Infoblad för en hund på en profil — visar den publika summeringen.
struct DogSummarySheet: View {
    let dog: ProfileView.DogDisplay

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: dog.isAngel ? "rainbow" : "pawprint.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(dog.isAngel ? .multicolor : .monochrome)
                        Text(dog.name)
                            .font(.title2.bold())
                        if dog.isAngel {
                            Text("Ängel 🌈\(memorialLine.map { " · \($0)" } ?? "")")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Ras", value: dog.breed)
                    if let sexName = dog.sexName {
                        LabeledContent("Kön", value: sexName)
                    }
                    if let birthDate = dog.birthDate {
                        LabeledContent("Född", value: birthDate.formatted(date: .long, time: .omitted))
                        if !dog.isAngel {
                            LabeledContent("Ålder", value: ageText(from: birthDate))
                        }
                    }
                    if let deceasedDate = dog.deceasedDate {
                        LabeledContent("Gick bort", value: deceasedDate.formatted(date: .long, time: .omitted))
                    }
                }

                if !dog.badges.isEmpty {
                    Section("Meriter") {
                        DogBadgeRow(badges: dog.badges)
                            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                }
            }
            .navigationTitle(dog.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// "2015–2024" när båda årtalen finns.
    private var memorialLine: String? {
        guard let birthDate = dog.birthDate, let deceasedDate = dog.deceasedDate else { return nil }
        let born = Calendar.current.component(.year, from: birthDate)
        let passed = Calendar.current.component(.year, from: deceasedDate)
        return "\(born)–\(passed)"
    }

    private func ageText(from birthDate: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month], from: birthDate, to: .now)
        let years = parts.year ?? 0
        let months = parts.month ?? 0
        if years == 0 { return "\(months) mån" }
        return months == 0 ? "\(years) år" : "\(years) år, \(months) mån"
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
