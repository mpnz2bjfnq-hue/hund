//
//  CommunitiesView.swift
//  UppdragHund
//
//  Öppna stadsgrupper som alla kan gå med i — visas under "Fler team".
//  Till skillnad från team krävs ingen inbjudan; man går med direkt.
//  Raderna leder till stadens sida (CommunityPageView) med träffarna.
//

import SwiftUI

/// Sektion med de öppna stadsgrupperna. Tänkt att bäddas in i en List
/// (JoinOrCreateTeamView), inte visas fristående.
struct CommunitiesSection: View {
    @State private var authService = AuthService.shared

    @State private var counts: [String: Int] = [:]
    @State private var joined: Set<String> = []
    @State private var isLoading = true

    var body: some View {
        Section {
            ForEach(Community.all) { community in
                NavigationLink {
                    CommunityPageView(community: community)
                } label: {
                    CommunityRow(
                        community: community,
                        // En stad utan räknardokument (ingen medlem än) saknas i
                        // counts — visa 0 när laddningen är klar, inte "Laddar…".
                        memberCount: isLoading ? nil : (counts[community.id] ?? 0),
                        isMember: joined.contains(community.id)
                    )
                }
            }
        } header: {
            Text("Öppna grupper")
        } footer: {
            Text("Stora grupper för hundägare i din stad — gå med direkt, ingen inbjudan behövs.")
        }
        .task { await load() }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        async let loadedCounts = CommunitiesRepository.shared.memberCounts()
        async let loadedJoined = CommunitiesRepository.shared.myMemberships(uid: uid)
        counts = await loadedCounts
        joined = await loadedJoined
        isLoading = false
    }
}

private struct CommunityRow: View {
    let community: Community
    let memberCount: Int?
    let isMember: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "building.2.fill")
                .foregroundStyle(Theme.Colors.brand)
                .frame(width: 34, height: 34)
                .background(Theme.Colors.brand.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(community.name)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(memberCountText)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer(minLength: Theme.Spacing.s)

            if isMember {
                Label("Med", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.brand)
            }
        }
        .padding(.vertical, 2)
    }

    private var memberCountText: String {
        guard let memberCount else { return "Laddar…" }
        return memberCount == 1 ? "1 medlem" : "\(memberCount) medlemmar"
    }
}
