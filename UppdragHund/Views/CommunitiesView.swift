//
//  CommunitiesView.swift
//  UppdragHund
//
//  Öppna stadsgrupper som alla kan gå med i — visas under "Fler team".
//  Till skillnad från team krävs ingen inbjudan; man går med direkt.
//

import SwiftUI

/// Sektion med de öppna stadsgrupperna. Tänkt att bäddas in i en List
/// (JoinOrCreateTeamView), inte visas fristående.
struct CommunitiesSection: View {
    @State private var authService = AuthService.shared
    @State private var currentUser = CurrentUserStore.shared

    @State private var counts: [String: Int] = [:]
    @State private var joined: Set<String> = []
    @State private var busy: Set<String> = []
    @State private var isLoading = true

    var body: some View {
        Section {
            ForEach(Community.all) { community in
                CommunityRow(
                    community: community,
                    memberCount: counts[community.id],
                    isMember: joined.contains(community.id),
                    isBusy: busy.contains(community.id),
                    onToggle: { toggle(community) }
                )
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

    private func toggle(_ community: Community) {
        guard let uid = authService.currentUserID, !busy.contains(community.id) else { return }
        let wasMember = joined.contains(community.id)

        busy.insert(community.id)
        // Optimistisk uppdatering — raden svarar direkt, rullas tillbaka vid fel.
        if wasMember {
            joined.remove(community.id)
            counts[community.id] = max(0, (counts[community.id] ?? 1) - 1)
        } else {
            joined.insert(community.id)
            counts[community.id] = (counts[community.id] ?? 0) + 1
        }

        Task {
            do {
                if wasMember {
                    try await CommunitiesRepository.shared.leave(communityID: community.id, uid: uid)
                } else {
                    try await CommunitiesRepository.shared.join(
                        communityID: community.id,
                        uid: uid,
                        displayName: currentUser.profile?.displayName ?? "Hundägare"
                    )
                }
            } catch {
                // Rulla tillbaka den optimistiska ändringen.
                if wasMember {
                    joined.insert(community.id)
                    counts[community.id] = (counts[community.id] ?? 0) + 1
                } else {
                    joined.remove(community.id)
                    counts[community.id] = max(0, (counts[community.id] ?? 1) - 1)
                }
            }
            busy.remove(community.id)
        }
    }
}

private struct CommunityRow: View {
    let community: Community
    let memberCount: Int?
    let isMember: Bool
    let isBusy: Bool
    let onToggle: () -> Void

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

            Button(action: onToggle) {
                if isBusy {
                    ProgressView()
                } else if isMember {
                    Label("Med", systemImage: "checkmark")
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.medium))
                } else {
                    Text("Gå med")
                        .font(.caption.weight(.medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(isMember ? Theme.Colors.textSecondary : Theme.Colors.brand)
            .disabled(isBusy)
        }
        .padding(.vertical, 2)
    }

    private var memberCountText: String {
        guard let memberCount else { return "Laddar…" }
        return memberCount == 1 ? "1 medlem" : "\(memberCount) medlemmar"
    }
}
