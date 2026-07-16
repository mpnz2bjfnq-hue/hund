//
//  FeedView.swift
//  UppdragHund
//
//  Sociala flödet som egen flik: dina, vänners och teamens inlägg med
//  filter, foto, delade pass, reaktioner och kommentarer.
//

import SwiftUI

struct FeedView: View {
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared
    @State private var feedPosts: [ProfilePost] = []
    @State private var authorPhotos: [String: Data] = [:]
    @State private var isLoadingFeed = false
    @State private var isPresentingNewPost = false
    @State private var postPendingDelete: ProfilePost?
    @State private var selectedPost: ProfilePost?
    @State private var feedFilter: FeedFilter = .all
    @State private var moderationMessage: String?
    @State private var myTeams: [Team] = []
    @State private var pendingTeamInvites = 0

    private enum FeedFilter: String, CaseIterable, Identifiable {
        case all, mine, team
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all:  "Alla"
            case .mine: "Mina"
            case .team: "Team"
            }
        }
        var icon: String {
            switch self {
            case .all:  "globe"
            case .mine: "person"
            case .team: "person.3"
            }
        }
    }

    private var displayedPosts: [ProfilePost] {
        switch feedFilter {
        case .all:  feedPosts
        case .mine: feedPosts.filter { $0.authorUid == authService.currentUserID }
        case .team: feedPosts.filter { $0.teamId != nil }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        Menu {
                            Picker("Visa", selection: $feedFilter) {
                                ForEach(FeedFilter.allCases) { filter in
                                    Label(filter.title, systemImage: filter.icon).tag(filter)
                                }
                            }
                        } label: {
                            smallPill(icon: "line.3.horizontal.decrease.circle", text: feedFilter.title)
                        }

                        // Team-knappen: rakt in på teamsidan om man är med i team,
                        // annars till sidan för att skapa/gå med.
                        if myTeams.isEmpty {
                            NavigationLink {
                                JoinOrCreateTeamView()
                            } label: {
                                smallPill(icon: "person.3.fill", text: "Team")
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(myTeams) { team in
                                NavigationLink {
                                    TeamPageView(team: team, onChanged: { Task { await loadFeed() } })
                                } label: {
                                    smallPill(icon: "person.3.fill", text: team.name)
                                }
                                .buttonStyle(.plain)
                            }
                            if pendingTeamInvites > 0 {
                                NavigationLink {
                                    JoinOrCreateTeamView()
                                } label: {
                                    smallPill(icon: "envelope.badge", text: "Inbjudan (\(pendingTeamInvites))")
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Träffar-knappen: alltid, och bara träffar.
                        NavigationLink {
                            MeetupsListView()
                        } label: {
                            smallPill(icon: "calendar", text: "Träffar")
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    HintBubble("Filtrera på Alla, Mina eller Team 👆", key: "hint.feedFilter")
                    Spacer()
                }
                .padding(.bottom, -Theme.Spacing.s)

                let posts = displayedPosts
                if posts.isEmpty {
                    Text(feedEmptyMessage)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardStyle()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                            Button {
                                selectedPost = post
                            } label: {
                                PostRowView(post: post, authorPhoto: authorPhotos[post.authorUid])
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if post.authorUid == authService.currentUserID {
                                    Button(role: .destructive) {
                                        postPendingDelete = post
                                    } label: {
                                        Label("Ta bort", systemImage: "trash")
                                    }
                                } else {
                                    Button {
                                        report(post)
                                    } label: {
                                        Label("Rapportera inlägg", systemImage: "flag")
                                    }
                                    Button(role: .destructive) {
                                        block(post)
                                    } label: {
                                        Label("Blockera \(post.authorName)", systemImage: "hand.raised")
                                    }
                                }
                            }
                            if index < posts.count - 1 {
                                Divider().overlay(Theme.Colors.textSecondary.opacity(0.2))
                            }
                        }
                    }
                    .cardStyle()
                }
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                BrandPrincipal(title: "Flöde")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isPresentingNewPost = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Skriv nytt inlägg")
            }
        }
        .refreshable { await loadFeed() }
        .onAppear { Task { await loadFeed() } }
        .onChange(of: feedFilter) { HintBubble.dismiss("hint.feedFilter") }
        .alert(
            "Tack för din anmälan",
            isPresented: Binding(
                get: { moderationMessage != nil },
                set: { if !$0 { moderationMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moderationMessage ?? "")
        }
        .sheet(isPresented: $isPresentingNewPost) {
            NewPostView(onPosted: { Task { await loadFeed() } })
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post, authorPhoto: authorPhotos[post.authorUid])
        }
        .confirmationDialog(
            "Ta bort inlägget?",
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
    }

    private func smallPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(Theme.Colors.brand)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.brand.opacity(0.12), in: Capsule())
    }

    private var feedEmptyMessage: String {
        if isLoadingFeed { return "Laddar flöde…" }
        switch feedFilter {
        case .mine: return "Du har inte delat något än. Tryck på pennan för att skriva ditt första inlägg."
        case .team: return "Inga team-inlägg än. Skriv ett inlägg och välj ett team som mottagare."
        case .all:  return "Inga inlägg än. Dela något själv eller lägg till vänner för att fylla flödet."
        }
    }

    private func loadFeed() async {
        guard let uid = authService.currentUserID else { return }
        isLoadingFeed = true
        var uids = [uid]
        var photos: [String: Data] = [:]
        if let myPhoto = currentUser.profile?.photoData {
            photos[uid] = myPhoto
        }
        if let friends = try? await FriendsRepository.shared.friends(for: uid) {
            for friend in friends {
                guard let friendUid = friend.id else { continue }
                uids.append(friendUid)
                if let photo = friend.photoData {
                    photos[friendUid] = photo
                }
            }
        }
        authorPhotos = photos
        let teams = await TeamsRepository.shared.myTeams(uid: uid)
        myTeams = teams
        pendingTeamInvites = await TeamsRepository.shared.pendingInvites(for: uid).count
        let blocked = await ModerationService.shared.refreshBlocked(for: uid)
        feedPosts = await PostsRepository.shared.feed(forUids: uids, teams: teams)
            .filter { !blocked.contains($0.authorUid) }
        isLoadingFeed = false
    }

    private func deletePost(_ post: ProfilePost) {
        Task {
            try? await PostsRepository.shared.delete(post: post)
            await loadFeed()
        }
    }

    private func report(_ post: ProfilePost) {
        guard let uid = authService.currentUserID, let postID = post.id else { return }
        Task {
            try? await ModerationService.shared.report(
                contentType: "post",
                contentID: postID,
                contentText: post.text,
                authorUid: post.authorUid,
                teamId: post.teamId,
                postID: postID,
                postAuthorUid: post.authorUid,
                reporterUid: uid
            )
            moderationMessage = "Vi har tagit emot din anmälan och granskar innehållet."
        }
    }

    private func block(_ post: ProfilePost) {
        guard let uid = authService.currentUserID else { return }
        Task {
            try? await ModerationService.shared.block(uid: post.authorUid, name: post.authorName, by: uid)
            moderationMessage = "\(post.authorName) är blockerad. Du ser inte längre hens inlägg eller kommentarer. Du kan ångra det under Inställningar → Blockerade användare."
            await loadFeed()
        }
    }
}
