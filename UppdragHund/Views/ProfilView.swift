//
//  ProfilView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

struct ProfilView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var dogs: [Dog]

    @State private var authService = AuthService.shared
    @State private var myProfile: UserProfile?
    @State private var friendCount: Int?

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)
                    Text(myProfile?.displayName ?? "Din profil")
                        .font(.title3.bold())
                    if let handle = myProfile?.handle {
                        Text(handle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            Section {
                LabeledContent("Hundar", value: "\(dogs.count)")
                LabeledContent("Vänner", value: authService.isSignedIn ? "\(friendCount ?? 0)" : "Logga in för att se")
                LabeledContent("Kullar", value: "Kommer snart")
                LabeledContent("Promenader", value: "Kommer snart")
            }

            if !authService.isSignedIn {
                Section {
                    SignInView()
                }
                .listRowInsets(EdgeInsets())
            } else {
                Section {
                    Button("Logga ut", role: .destructive) {
                        try? authService.signOut()
                    }
                }
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Stäng") { dismiss() }
            }
        }
        .task(id: authService.isSignedIn) {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        guard let uid = authService.currentUserID else {
            myProfile = nil
            friendCount = nil
            return
        }
        do {
            myProfile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
            friendCount = try await FriendsRepository.shared.friends(for: uid).count
        } catch {
            myProfile = nil
        }
    }
}

#Preview {
    NavigationStack {
        ProfilView()
    }
    .modelContainer(for: Dog.self, inMemory: true)
}
