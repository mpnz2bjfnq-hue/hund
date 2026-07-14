//
//  DogAvatar.swift
//  UppdragHund
//
//  Cirkulär hundbild — visar lokalt foto om det finns, annars en tass-symbol.
//  Valfri grön ring markerar t.ex. aktiv hund.
//

import SwiftUI

struct DogAvatar: View {
    let photoData: Data?
    var size: CGFloat = 60
    var isActive: Bool = false

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isActive ? Theme.Colors.brand : Theme.Colors.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Theme.Colors.brand, lineWidth: isActive ? 2.5 : 0)
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        DogAvatar(photoData: nil, size: 60, isActive: true)
        DogAvatar(photoData: nil, size: 60, isActive: false)
    }
    .padding()
    .background(Theme.Colors.screenBackground)
}
