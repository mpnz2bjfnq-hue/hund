//
//  Canine360Wordmark.swift
//  UppdragHund
//
//  Text-ordmärke: vit "Canine" + grön "360". Används i topp-baren.
//

import SwiftUI

struct Canine360Wordmark: View {
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 0) {
            Text("Canine")
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("360")
                .foregroundStyle(Theme.Colors.brand)
        }
        .font(.system(size: size, weight: .bold))
        .accessibilityElement()
        .accessibilityLabel("Canine360")
    }
}

#Preview {
    Canine360Wordmark()
        .padding()
        .background(Theme.Colors.screenBackground)
}
