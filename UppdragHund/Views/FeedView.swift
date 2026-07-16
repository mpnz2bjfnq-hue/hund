//
//  FeedView.swift
//  UppdragHund
//
//  Socialt-fliken: ingång till Team, Träffar och Forumet via stora kort.
//  (Ersatte det tidigare inläggsflödet — inlägg finns kvar på profiler
//  och teamsidor, men appens fokus är hunden, inte ett socialt flöde.)
//

import SwiftUI

struct FeedView: View {
    @State private var authService = AuthService.shared
    @State private var myTeams: [Team] = []
    @State private var pendingTeamInvites = 0
    @State private var upcomingMeetups = 0
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {

                // ===== Team =====
                if myTeams.isEmpty {
                    bigCard(
                        icon: "person.3.fill",
                        title: "Team",
                        subtitle: "Skapa eller gå med i ett team och träna tillsammans"
                    ) {
                        JoinOrCreateTeamView()
                    }
                } else {
                    ForEach(myTeams) { team in
                        bigCard(
                            icon: "person.3.fill",
                            title: team.name,
                            subtitle: "\(team.memberCount) medlemmar · uppgifter, inlägg och träffar",
                            photoData: team.photoData
                        ) {
                            TeamPageView(team: team, onChanged: { Task { await load() } })
                        }
                    }
                }

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

                // ===== Träffar =====
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

                // ===== Forum =====
                bigCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Forum",
                    subtitle: "Ställ frågor och diskutera hundträning med andra"
                ) {
                    ForumView()
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
        }
        .refreshable { await load() }
        .onAppear { Task { await load() } }
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

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        isLoading = true
        myTeams = await TeamsRepository.shared.myTeams(uid: uid)
        pendingTeamInvites = await TeamsRepository.shared.pendingInvites(for: uid).count
        let meetups = await TeamsRepository.shared.upcomingMeetups(uid: uid)
        upcomingMeetups = meetups.filter { $0.date >= Calendar.current.startOfDay(for: .now) }.count
        isLoading = false
    }
}
