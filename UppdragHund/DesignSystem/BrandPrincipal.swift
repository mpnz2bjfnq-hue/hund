//
//  BrandPrincipal.swift
//  UppdragHund
//
//  Enhetlig topp-rubrik: "Canine360"-ordmärket med hundloggan bredvid,
//  och sidans namn under. Används som principal-toolbar på huvudflikarna.
//

import SwiftUI

struct BrandPrincipal: View {
    let title: String

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 6) {
                Canine360Wordmark(size: 17)
                Image("Canine360Mark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Canine360, \(title)")
    }
}

#Preview {
    NavigationStack {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    BrandPrincipal(title: "Kalender")
                }
            }
    }
}
