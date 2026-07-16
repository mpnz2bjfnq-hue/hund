//
//  MinProfilView.swift
//  UppdragHund
//
//  Profil-flik (f.d. "Mer"). Samlar användarprofil, "Mina hundar"
//  (snabbväxling av aktiv hund + hantering) och app-inställningar.
//  Visuellt utformad efter Canine360-mockupen.
//

import SwiftUI
import SwiftData

struct MinProfilView: View {
    @Environment(ActiveDogStore.self) private var activeDogStore
    @Environment(\.modelContext) private var modelContext
    @State private var isSyncingShared = false
    @State private var settingsExpanded = false
    @State private var isAdmin = false
    @State private var ticketKind: TicketKind?
    @State private var isPresentingAddFriend = false
    @AppStorage("hasDiscoveredSettings") private var hasDiscoveredSettings = false
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var allOwnDogs: [Dog]
    @Query(filter: #Predicate<Dog> { $0.isShared }, sort: \Dog.name) private var sharedDogs: [Dog]

    /// Bara det inloggade kontots egna hundar.
    private var ownDogs: [Dog] {
        allOwnDogs.filter { $0.ownerUid == authService.currentUserID }
    }

    @State private var currentUser = CurrentUserStore.shared
    @State private var authService = AuthService.shared
    @State private var isPresentingAddDog = false
    @State private var isEditingProfile = false

    // Socialt (laddas från Firestore).
    @State private var friendCount: Int?
    @State private var myTeams: [Team] = []
    @State private var isPresentingFriends = false

    private var allDogs: [Dog] { ownDogs.filter { !$0.isDeceased } + sharedDogs }

    /// Änglar: avlidna hundar som hedras med en egen räknare.
    private var angelCount: Int { ownDogs.filter(\.isDeceased).count }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                profileHeader
                statsRow
                dogsCard
                if isAdmin {
                    adminCard
                }
                if !hasDiscoveredSettings && !settingsExpanded {
                    settingsHint
                }
                settingsCard
                logoutButton
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .overlay(alignment: .bottomTrailing) {
            feedbackBubble
        }
        .sheet(item: $ticketKind) { kind in
            NewTicketView(kind: kind)
        }
        .sheet(isPresented: $isPresentingAddFriend, onDismiss: { Task { await loadSocial() } }) {
            AddFriendView()
        }
        .refreshable {
            await SharedDogPuller.shared.pull(context: modelContext)
            await loadSocial()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Min profil")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    NotificationsCenterView(dog: activeDogStore.activeDog)
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
            statTile(value: "\(ownDogs.count - angelCount)", label: "Hundar")
            if angelCount > 0 {
                statDivider
                statTile(value: "\(angelCount)", label: "Änglar 🌈")
            }
            statDivider
            Button {
                isPresentingFriends = true
            } label: {
                statTile(value: friendCount.map(String.init) ?? "–", label: "Vänner")
            }
            .buttonStyle(.plain)
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

    private func syncSharedDogs() {
        isSyncingShared = true
        Task {
            await SharedDogPuller.shared.pull(context: modelContext)
            isSyncingShared = false
        }
    }

    // MARK: - Socialt (räknare)

    private func loadSocial() async {
        guard let uid = authService.currentUserID else { return }
        if let friends = try? await FriendsRepository.shared.friends(for: uid) {
            friendCount = friends.count
        }
        myTeams = await TeamsRepository.shared.myTeams(uid: uid)
        isAdmin = await AdminService.shared.checkIsAdmin(uid: uid)
    }

    // MARK: - Feedback-bubbla

    private var feedbackBubble: some View {
        Menu {
            Button {
                ticketKind = .feedback
            } label: {
                Label("Skicka feedback", systemImage: "heart.text.square")
            }
            Button {
                ticketKind = .support
            } label: {
                Label("Skapa supportärende", systemImage: "ticket")
            }
        } label: {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.Colors.brand))
                .shadow(color: .black.opacity(0.3), radius: 5, y: 2)
        }
        .accessibilityLabel("Feedback och support")
        .padding(.trailing, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - Admin

    private var adminCard: some View {
        NavigationLink {
            AdminPanelView()
        } label: {
            HStack(spacing: Theme.Spacing.l) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.brand)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adminpanel")
                        .font(Theme.Typography.body.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("Anmälningar, användare och broadcast")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .cardStyle()
        }
        .buttonStyle(.plain)
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
                .overlay(alignment: .topTrailing) {
                    if isAdmin {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(5)
                            .background(Circle().fill(Theme.Colors.brand))
                            .overlay(Circle().stroke(Theme.Colors.screenBackground, lineWidth: 2))
                            .accessibilityLabel("Admin")
                    }
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
                if !myTeams.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(myTeams.prefix(3)) { team in
                            Label(team.name, systemImage: "person.3.fill")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Theme.Colors.brand)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.brand.opacity(0.12), in: Capsule())
                                .lineLimit(1)
                        }
                        if myTeams.count > 3 {
                            Text("+\(myTeams.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.top, 2)
                }
                Button {
                    isPresentingAddFriend = true
                } label: {
                    Label("Lägg till vän", systemImage: "person.badge.plus")
                        .font(.footnote.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Theme.Colors.brand)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.s)
    }

    // MARK: - Mina hundar

    private var dogsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.m) {
                Text("Mina hundar")
                    .font(Theme.Typography.sectionTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Button {
                    syncSharedDogs()
                } label: {
                    if isSyncingShared {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.brand)
                    }
                }
                .accessibilityLabel("Uppdatera delade hundar")
                .disabled(isSyncingShared)
                Spacer()
                NavigationLink {
                    DogListView()
                } label: {
                    Text("Visa alla")
                        .font(Theme.Typography.caption.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                }
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

    // MARK: - Inställningar (hopfällda)

    private var settingsCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.35)) {
                    settingsExpanded.toggle()
                }
                hasDiscoveredSettings = true
            } label: {
                HStack(spacing: Theme.Spacing.m) {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(Theme.Colors.brand)
                        .frame(width: 26)
                    Text("Inställningar & mer")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .rotationEffect(.degrees(settingsExpanded ? 90 : 0))
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.m)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if settingsExpanded {
                rowDivider
                settingsRow(icon: "slider.horizontal.3", title: "Inställningar") {
                    SettingsView()
                }
                rowDivider
                ShareLink(item: "Kolla in Canine360 – appen för allt om din hund! 🐾") {
                    settingsRowLabel(icon: "square.and.arrow.up", title: "Dela appen")
                }
                .buttonStyle(.plain)
                rowDivider
                settingsRow(icon: "arrow.triangle.2.circlepath", title: "Backup & Synk") {
                    SyncInfoView()
                }
                rowDivider
                settingsRow(icon: "lock.shield", title: "Integritet & data") {
                    PrivacyInfoView()
                }
                rowDivider
                settingsRow(icon: "questionmark.circle", title: "Hjälp & Support") {
                    HelpSupportView()
                }
                rowDivider
                settingsRow(icon: "info.circle", title: "Om Canine360") {
                    OmOssView()
                }
            }
        }
        .cardStyle(padding: 0)
    }

    private var settingsHint: some View {
        HStack {
            Spacer()
            HintBubble("Psst – mer finns här 👇", key: "hasDiscoveredSettings")
        }
        .padding(.bottom, -Theme.Spacing.m)
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
            Task {
                // Avregistrera push-token FÖRE utloggning (kräver aktiv inloggning).
                await PushNotificationService.shared.removeToken()
                try? authService.signOut()
            }
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
