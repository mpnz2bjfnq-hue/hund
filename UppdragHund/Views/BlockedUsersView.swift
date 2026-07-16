//
//  BlockedUsersView.swift
//  UppdragHund
//
//  Lista över blockerade användare med möjlighet att avblockera.
//

import SwiftUI

struct BlockedUsersView: View {
    @State private var authService = AuthService.shared
    @State private var blocked: [(uid: String, name: String)] = []
    @State private var isLoading = true

    var body: some View {
        List {
            if blocked.isEmpty {
                Text(isLoading ? "Laddar…" : "Du har inte blockerat någon.")
                    .foregroundStyle(Theme.Colors.textSecondary)
            } else {
                ForEach(blocked, id: \.uid) { user in
                    HStack {
                        Text(user.name)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Spacer()
                        Button("Avblockera") {
                            unblock(user.uid)
                        }
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                        .tint(Theme.Colors.brand)
                    }
                }
            }
        }
        .navigationTitle("Blockerade användare")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let uid = authService.currentUserID else { return }
        blocked = await ModerationService.shared.blockedUsers(for: uid)
        isLoading = false
    }

    private func unblock(_ targetUid: String) {
        guard let uid = authService.currentUserID else { return }
        Task {
            try? await ModerationService.shared.unblock(uid: targetUid, by: uid)
            await load()
        }
    }
}
