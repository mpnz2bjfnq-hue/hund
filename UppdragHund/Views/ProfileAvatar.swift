//
//  ProfileAvatar.swift
//  UppdragHund
//
//  Cirkulär profilbild — visar uppladdad bild om den finns, annars en
//  platshållarsymbol.
//

import SwiftUI

struct ProfileAvatar: View {
    let photoData: Data?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
