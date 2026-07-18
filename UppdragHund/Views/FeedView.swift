//
//  FeedView.swift
//  UppdragHund
//
//  Socialt-fliken: ingång till Team, Träffar och Forumet via stora kort.
//  (Ersatte det tidigare inläggsflödet — inlägg finns kvar på profiler
//  och teamsidor, men appens fokus är hunden, inte ett socialt flöde.)
//
//  Sidan är modulär på samma sätt som Hem: användaren väljer ordning och
//  vilka block som visas via ⊞ i toppbaren (EditSocialView). Valen sparas
//  per enhet som en ordnad lista (SocialBlockStore).
//

import SwiftUI

struct FeedView: View {
    @State private var authService = AuthService.shared
    @State private var myTeams: [Team] = []
    @State private var myCommunities: [Community] = []
    @State private var communityCounts: [String: Int] = [:]
    @State private var pendingTeamInvites = 0
    @State private var upcomingMeetups = 0
    @State private var isLoading = true
    @State private var isEditingSocial = false

    @AppStorage(SocialBlockStore.storageKey) private var blocksRaw = SocialBlockStore.defaultRaw
    @State private var blocksAppeared = false

    private var blocks: [SocialBlock] { SocialBlockStore.decode(blocksRaw) }
    private var hasGroups: Bool { !myTeams.isEmpty || !myCommunities.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                if blocks.isEmpty {
                    Button {
                        isEditingSocial = true
                    } label: {
                        Text("Alla block är dolda. Tryck här för att anpassa Socialt.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .cardStyle()
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack {
                        Spacer()
                        HintBubble("Anpassa Socialt med ⊞ där uppe 👆", key: "hint.editSocial")
                    }
                    .padding(.bottom, -Theme.Spacing.m)

                    ForEach(Array(blocks.enumerated()), id: \.element) { index, block in
                        Group {
                            switch block {
                            case .teams:    teamsBlock
                            case .discover: discoverBlock
                            case .meetups:  meetupsBlock
                            case .forum:    forumBlock
                            }
                        }
                        .riseIn(index, shown: blocksAppeared)
                    }
                }
            }
            .padding(Theme.Spacing.l)
            .animation(.spring(duration: 0.4), value: blocks)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.screenSurface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Socialt")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    HintBubble.dismiss("hint.editSocial")
                    isEditingSocial = true
                } label: {
                    Image(systemName: "square.grid.2x2")
                }
                .accessibilityLabel("Anpassa Socialt")
            }
        }
        .sheet(isPresented: $isEditingSocial) {
            EditSocialView()
        }
        .refreshable { await load() }
        .onAppear {
            blocksAppeared = true
            Task { await load() }
        }
    }

    // MARK: - Block

    @ViewBuilder
    private var teamsBlock: some View {
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
                subtitle: communitySubtitle(community),
                tint: .teal
            ) {
                CommunityPageView(community: community)
            }
        }
    }

    @ViewBuilder
    private var discoverBlock: some View {
        if pendingTeamInvites > 0 {
            bigCard(
                icon: "envelope.badge",
                title: "Team-inbjudan",
                subtitle: pendingTeamInvites == 1
                    ? "Du har 1 väntande inbjudan"
                    : "Du har \(pendingTeamInvites) väntande inbjudningar",
                tint: .blue
            ) {
                JoinOrCreateTeamView()
            }
        }
        bigCard(
            icon: "plus.circle.fill",
            title: hasGroups ? "Fler team & grupper" : "Team & grupper",
            subtitle: "Skapa ett team, gå med med kod, eller gå med i en stadsgrupp",
            tint: .blue
        ) {
            JoinOrCreateTeamView()
        }
    }

    private var meetupsBlock: some View {
        bigCard(
            icon: "calendar",
            title: "Träffar",
            subtitle: upcomingMeetups > 0
                ? (upcomingMeetups == 1
                    ? "1 kommande träff"
                    : "\(upcomingMeetups) kommande träffar")
                : "Planera hundträffar med vänner och team",
            tint: .orange
        ) {
            MeetupsListView()
        }
    }

    private var forumBlock: some View {
        bigCard(
            icon: "bubble.left.and.bubble.right.fill",
            title: "Forum",
            subtitle: "Ställ frågor och diskutera hundträning med andra",
            tint: .purple
        ) {
            ForumView()
        }
    }

    // MARK: - Kort

    private func bigCard<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        photoData: Data? = nil,
        tint: Color = Theme.Colors.brand,
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
                        .foregroundStyle(tint)
                        .frame(width: 52, height: 52)
                        .background(
                            tint.opacity(0.14),
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
            .tintedCardStyle(tint)
        }
        .buttonStyle(CardPressStyle())
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
