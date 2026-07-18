//
//  DogBadges.swift
//  UppdragHund
//
//  Små meritbadges för hundprofilen: HD/ED-resultat, mentaltest,
//  utställningsmerit, vaccination och chipmärkning.
//

import SwiftUI

struct DogBadge: Identifiable, Equatable {
    let id: String
    let text: String
    let icon: String
    let tint: Color

    /// Bygger badge-listan från hundens fält. Chipmärkt härleds från
    /// chipnumret — inget separat fält att glömma bocka i.
    static func badges(
        hdResult: String?,
        edResult: String?,
        mentalTest: Bool,
        showMerit: Bool,
        vaccinated: Bool,
        chipped: Bool
    ) -> [DogBadge] {
        var badges: [DogBadge] = []
        if let hd = hdResult, !hd.isEmpty {
            badges.append(DogBadge(id: "hd", text: "HD \(hd)", icon: "figure.walk", tint: .blue))
        }
        if let ed = edResult, !ed.isEmpty {
            badges.append(DogBadge(id: "ed", text: "ED \(ed)", icon: "pawprint", tint: .teal))
        }
        if mentalTest {
            badges.append(DogBadge(id: "mental", text: String(localized: "Mentaltest"), icon: "brain.head.profile", tint: .purple))
        }
        if showMerit {
            badges.append(DogBadge(id: "show", text: String(localized: "Utställning"), icon: "rosette", tint: .orange))
        }
        if vaccinated {
            badges.append(DogBadge(id: "vaccine", text: String(localized: "Vaccinerad"), icon: "cross.vial", tint: Theme.Colors.brand))
        }
        if chipped {
            badges.append(DogBadge(id: "chip", text: String(localized: "Chipmärkt"), icon: "sensor.tag.radiowaves.forward", tint: .gray))
        }
        return badges
    }

    static func badges(for dog: Dog) -> [DogBadge] {
        badges(
            hdResult: dog.hdResult,
            edResult: dog.edResult,
            mentalTest: dog.mentalTestDone,
            showMerit: dog.showMerit,
            vaccinated: dog.vaccinated,
            chipped: dog.chipNumber?.isEmpty == false
        )
    }
}

/// Radbrytande rad av badges. Tom vy när det inte finns några.
struct DogBadgeRow: View {
    let badges: [DogBadge]

    var body: some View {
        if !badges.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 108), spacing: Theme.Spacing.s, alignment: .leading)],
                alignment: .leading,
                spacing: Theme.Spacing.s
            ) {
                ForEach(badges) { badge in
                    HStack(spacing: 5) {
                        Image(systemName: badge.icon)
                            .font(.caption2.weight(.semibold))
                        Text(badge.text)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(badge.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(badge.tint.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(badge.tint.opacity(0.25), lineWidth: 0.5))
                }
            }
        }
    }
}
