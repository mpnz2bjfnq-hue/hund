//
//  FeedView.swift
//  UppdragHund
//
//  Socialt-fliken: ingång till Team, Träffar och Forumet via stora kort.
//  (Ersatte det tidigare inläggsflödet — inlägg finns kvar på profiler
//  och teamsidor, men appens fokus är hunden, inte ett socialt flöde.)
//
//  Sidan är modulär: användaren väljer själv vilka delar som visas, via
//  reglaget i toppbaren. Valen sparas per enhet (det är en visnings-
//  preferens, inte kontodata) och delas med anpassningsvyn genom samma
//  AppStorage-nycklar.
//

import SwiftUI

/// AppStorage-nycklar för vilka Socialt-sektioner som visas. Delade mellan
/// FeedView och CustomizeFeedView så de hålls i synk automatiskt.
enum SocialSection {
    static let teams = "social.showTeams"
    static let discover = "social.showDiscover"
    static let meetups = "social.showMeetups"
    static let forum = "social.showForum"
}

struct FeedView: View {
    @State private var authService = AuthService.shared
    @State private var myTeams: [Team] = []
    @State private var myCommunities: [Community] = []
    @State private var communityCounts: [String: Int] = [:]
    @State private var pendingTeamInvites = 0
    @State private var upcomingMeetups = 0
    @State private var isLoading = true
    @State private var isPresentingCustomize = false

    @AppStorage(SocialSection.teams) private var showTeams = true
    @AppStorage(SocialSection.discover) private var showDiscover = true
    @AppStorage(SocialSection.meetups) private var showMeetups = true
    @AppStorage(SocialSection.forum) private var showForum = true

    private var hasGroups: Bool { !myTeams.isEmpty || !myCommunities.isEmpty }

    /// Visas någon sektion alls? Om inte, visa en hjälprad i stället för en
    /// tom sida.
    private var hasVisibleContent: Bool {
        (showTeams && hasGroups) || showDiscover || showMeetups || showForum
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {

                // ===== Dina team & grupper =====
                if showTeams {
                    ForEach(myTeams) { team in
                        bigCard(
                            icon: "person.3.fill",
                            title: team.name,
                            subtitle: "\(team.memberCount) medlemmar · \(team.kind.displayName)",
                            photoData: team.photoData
                        ) {
                            TeamPageView(team: team, onChanged: { Task { await load() } })
                        }
                    }
                    ForEach(myCommunities) { community in
                        bigCard(
                            icon: "building.2.fill",
                            title: community.name,
                            subtitle: communitySubtitle(community)
                        ) {
                            CommunityPageView(community: community)
                        }
                    }
                }

                // ===== Gå med i nytt team eller grupp =====
                if showDiscover {
                    if pendingTeamInvites > 0 {
                        bigCard(
                            icon: "envelope.badge",
                            title: "Team-inbjudan",
                            subtitle: pendingTeamInvites == 1
                                ? "Du har 1 väntande inbjudan"
                                : "Du har \(pendingTeamInvites) väntande inbjudningar"
                        ) {
                            JoinOrCreateTeamView()
                        }
                    }
                    bigCard(
                        icon: "plus.circle.fill",
                        title: hasGroups ? "Fler team & grupper" : "Team & grupper",
                        subtitle: "Skapa ett team, gå med med kod, eller gå med i en stadsgrupp"
                    ) {
                        JoinOrCreateTeamView()
                    }
                }

                // ===== Träffar =====
                if showMeetups {
                    bigCard(
                        icon: "calendar",
                        title: "Träffar",
                        subtitle: upcomingMeetups > 0
                            ? (upcomingMeetups == 1
                                ? "1 kommande träff"
                                : "\(upcomingMeetups) kommande träffar")
                            : "Planera hundträffar med vänner och team"
                    ) {
                        MeetupsListView()
                    }
                }

                // ===== Forum =====
                if showForum {
                    bigCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Forum",
                        subtitle: "Ställ frågor och diskutera hundträning med andra"
                    ) {
                        ForumView()
                    }
                }

                if !hasVisibleContent {
                    hiddenEverythingHint
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Socialt")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingCustomize = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Anpassa Socialt")
            }
        }
        .sheet(isPresented: $isPresentingCustomize) {
            CustomizeFeedView()
        }
        .refreshable { await load() }
        .onAppear { Task { await load() } }
    }

    private var hiddenEverythingHint: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "slider.horizontal.3")
                .font(.largeTitle)
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Allt är dolt just nu")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("Välj vad du vill se på Socialt.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
            Button("Anpassa Socialt") { isPresentingCustomize = true }
                .buttonStyle(.borderedProminent)
                .tint(Theme.Colors.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
    }

    // MARK: - Kort

    private func bigCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        photoData: Data? = nil,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: Theme.Spacing.l) {
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(Theme.Colors.brand)
                        .frame(width: 52, height: 52)
                        .background(
                            Theme.Colors.brand.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data

    private func communitySubtitle(_ community: Community) -> String {
        let count = communityCounts[community.id] ?? 0
        return "\(count) \(count == 1 ? "medlem" : "medlemmar") · Öppen stadsgrupp"
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        isLoading = true
        myTeams = await TeamsRepository.shared.myTeams(uid: uid)
        let memberships = await CommunitiesRepository.shared.myMemberships(uid: uid)
        myCommunities = Community.all.filter { memberships.contains($0.id) }
        communityCounts = await CommunitiesRepository.shared.memberCounts()
        pendingTeamInvites = await TeamsRepository.shared.pendingInvites(for: uid).count
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        upcomingMeetups = meetups.filter { $0.date >= Calendar.current.startOfDay(for: .now) }.count
        isLoading = false
    }
}

// MARK: - Anpassa Socialt

/// Låter användaren välja vilka delar av Socialt som visas. Egna AppStorage-
/// bindningar mot samma nycklar som FeedView, så ändringar slår igenom direkt.
struct CustomizeFeedView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SocialSection.teams) private var showTeams = true
    @AppStorage(SocialSection.discover) private var showDiscover = true
    @AppStorage(SocialSection.meetups) private var showMeetups = true
    @AppStorage(SocialSection.forum) private var showForum = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $showTeams) {
                        Label("Dina team & grupper", systemImage: "person.3.fill")
                    }
                    Toggle(isOn: $showDiscover) {
                        Label("Gå med i nytt team", systemImage: "plus.circle.fill")
                    }
                    Toggle(isOn: $showMeetups) {
                        Label("Träffar", systemImage: "calendar")
                    }
                    Toggle(isOn: $showForum) {
                        Label("Forum", systemImage: "bubble.left.and.bubble.right.fill")
                    }
                } header: {
                    Text("Visa på Socialt")
                } footer: {
                    Text("Välj hur mycket du vill se. Det du stänger av försvinner från Socialt-sidan, men allt finns kvar — slå bara på det igen här.")
                }
            }
            .tint(Theme.Colors.brand)
            .navigationTitle("Anpassa Socialt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}
