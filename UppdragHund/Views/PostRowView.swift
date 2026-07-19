//
//  PostRowView.swift
//  UppdragHund
//
//  Delad inläggsrad — används av flödet och teamsidan.
//

import SwiftUI

struct PostRowView: View {
    let post: ProfilePost
    var authorPhoto: Data? = nil
    /// Döljs på teamsidan där alla inlägg hör till samma team.
    var showsTeamChip = true
    /// Gilla-/kommentarsantal. Noll visar orden i stället för siffror.
    var counts = PostCounts()
    /// Tryck på fotot — öppnar helskärmsvisning hos föräldern.
    var onPhotoTap: ((UIImage) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProfileAvatar(photoData: authorPhoto, size: 32)
                    .tint(Theme.Colors.brand)
                Text(post.authorName)
                    .font(Theme.Typography.body.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                if showsTeamChip, let teamName = post.teamName {
                    Label(teamName, systemImage: "person.3.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Theme.Colors.brand)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.brand.opacity(0.12), in: Capsule())
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Text(post.text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let photoData = post.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    // Innersta tryckytan vinner över kortets tryck.
                    .onTapGesture { onPhotoTap?(uiImage) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Visa foto i helskärm")
            }
            if let dogName = post.dogName {
                Label(dogName, systemImage: "pawprint.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            if let plan = post.trainingPlan {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundStyle(Theme.Colors.brand)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(plan.title)
                            .font(Theme.Typography.body.weight(.medium))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text(plan.summaryLine)
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.s)
                .background(Theme.Colors.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            HStack(spacing: Theme.Spacing.l) {
                Label(
                    counts.reactions > 0 ? "\(counts.reactions)" : String(localized: "Gilla"),
                    systemImage: counts.reactions > 0 ? "pawprint.fill" : "pawprint"
                )
                .foregroundStyle(counts.reactions > 0 ? Theme.Colors.brand : Theme.Colors.textSecondary)

                Label(
                    counts.comments > 0 ? "\(counts.comments)" : String(localized: "Kommentera"),
                    systemImage: "bubble.right"
                )
            }
            .font(.caption2)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
    }
}
