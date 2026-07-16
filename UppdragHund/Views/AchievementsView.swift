//
//  AchievementsView.swift
//  UppdragHund
//
//  Visar hundens träningsstreak och utmärkelser (upplåsta + på gång).
//

import SwiftUI

struct AchievementsView: View {
    let dog: Dog

    private var stats: DogStats { DogStats(dog: dog) }
    private var unlockedCount: Int {
        Achievement.allCases.filter { $0.isUnlocked(for: stats) }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                streakCard
                grid
            }
            .padding(Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.screenBackground)
        .navigationTitle("Utmärkelser")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var streakCard: some View {
        HStack(spacing: Theme.Spacing.l) {
            Image(systemName: "flame.fill")
                .font(.system(size: 40))
                .foregroundStyle(stats.trainingStreak > 0 ? .orange : Theme.Colors.textSecondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(stats.trainingStreak) \(stats.trainingStreak == 1 ? "dag" : "dagar") i rad")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(stats.trainingStreak > 0
                     ? "Fortsätt logga träning för att hålla streaken vid liv!"
                     : "Logga träning idag för att starta en streak.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .cardStyle()
    }

    private var grid: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("\(unlockedCount) av \(Achievement.allCases.count) utmärkelser")
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: Theme.Spacing.m
            ) {
                ForEach(Achievement.allCases) { achievement in
                    tile(achievement)
                }
            }
        }
    }

    private func tile(_ achievement: Achievement) -> some View {
        let unlocked = achievement.isUnlocked(for: stats)
        let current = min(achievement.current(for: stats), achievement.target)
        return VStack(spacing: Theme.Spacing.s) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: achievement.icon)
                    .font(.title)
                    .foregroundStyle(unlocked ? Theme.Colors.brand : Theme.Colors.textSecondary.opacity(0.6))
                    .frame(width: 56, height: 56)
                    .background(
                        Circle().fill(unlocked
                                      ? Theme.Colors.brand.opacity(0.15)
                                      : Theme.Colors.textSecondary.opacity(0.1))
                    )
                if unlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.brand)
                        .background(Circle().fill(Theme.Colors.cardBackground))
                }
            }
            Text(achievement.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(unlocked ? "Klar" : "\(current)/\(achievement.target)")
                .font(.caption2)
                .foregroundStyle(unlocked ? Theme.Colors.brand : Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.m)
        .cardStyle()
    }
}
