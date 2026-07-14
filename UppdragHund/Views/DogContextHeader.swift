//
//  DogContextHeader.swift
//  UppdragHund
//

import SwiftUI

struct DogContextHeader: View {
    let dog: Dog

    @State private var showingShare = false
    @State private var showingFriends = false
    @State private var showingProfile = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                    Text(dog.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                .foregroundStyle(.tint)
                Text(dog.breed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !dog.isShared {
                Button {
                    showingShare = true
                } label: {
                    Image(systemName: "person.badge.plus")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dela hund")
            }

            Menu {
                Button("Profil", systemImage: "person.crop.circle") {
                    showingProfile = true
                }
                Button("Vänner", systemImage: "person.2") {
                    showingFriends = true
                }
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Profilmeny")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sheet(isPresented: $showingShare) {
            ShareDogView(dog: dog)
        }
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                ProfilView()
            }
        }
        .sheet(isPresented: $showingFriends) {
            FriendsView()
        }
    }
}

#Preview {
    DogContextHeader(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
}
