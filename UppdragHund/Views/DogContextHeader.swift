//
//  DogContextHeader.swift
//  UppdragHund
//

import SwiftUI

struct DogContextHeader: View {
    let dog: Dog

    @State private var showingShare = false
    @State private var showingProfile = false
    @State private var currentUser = CurrentUserStore.shared

    var body: some View {
        HStack(spacing: 12) {
            Image("Canine360Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .accessibilityLabel("Canine360")

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint.fill")
                        .font(.caption)
                    Text(dog.name)
                        .font(.headline)
                        .lineLimit(1)
                }
                .foregroundStyle(.tint)
                Text(dog.isShared ? "Delas av \(dog.ownerDisplayName ?? "vän")" : dog.breed)
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

            Button {
                showingProfile = true
            } label: {
                ProfileAvatar(photoData: currentUser.profile?.photoData, size: 34)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Min profil")
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
                ProfileView()
            }
        }
        .task {
            if currentUser.profile == nil {
                await currentUser.refresh()
            }
        }
    }
}

#Preview {
    DogContextHeader(dog: Dog(name: "Bella", breed: "Schäfer", birthDate: .now, sex: .female))
}
