//
//  NewPostView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData
import PhotosUI

/// Skriv en ny uppdatering till din profil. Textbaserad i v1, med valfri
/// koppling till en av dina hundar.
struct NewPostView: View {
    /// Anropas efter lyckad publicering så profilen kan uppdatera sig.
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var allOwnDogs: [Dog]

    /// Bara det inloggade kontots egna hundar.
    private var dogs: [Dog] {
        allOwnDogs.filter { $0.ownerUid == authService.currentUserID }
    }

    @State private var authService = AuthService.shared
    @State private var text = ""
    @State private var selectedDogID: PersistentIdentifier?
    @State private var errorMessage: String?
    @State private var isPosting = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var teams: [Team] = []
    @State private var selectedTeamID: String?

    private var selectedTeam: Team? {
        teams.first { $0.id == selectedTeamID }
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Vad vill du dela?", text: $text, axis: .vertical)
                        .lineLimit(4...10)
                }

                Section {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .frame(maxWidth: .infinity)
                        Button("Ta bort bilden", role: .destructive) {
                            self.photoData = nil
                            photoItem = nil
                        }
                    } else {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Lägg till foto", systemImage: "photo")
                        }
                    }
                }
                .onChange(of: photoItem) {
                    Task {
                        if let item = photoItem,
                           let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            photoData = PostImage.makeData(from: image)
                        }
                    }
                }

                if !teams.isEmpty {
                    Section {
                        Picker("Vem ser inlägget?", selection: $selectedTeamID) {
                            Text("Alla vänner").tag(String?.none)
                            ForEach(teams) { team in
                                Label(team.name, systemImage: "person.3.fill").tag(team.id)
                            }
                        }
                    } footer: {
                        Text(selectedTeam != nil
                             ? "Bara medlemmarna i \(selectedTeam!.name) ser inlägget."
                             : "Alla dina vänner ser inlägget i sitt flöde.")
                    }
                }

                if !dogs.isEmpty {
                    Section("Koppla till hund (valfritt)") {
                        Picker("Hund", selection: $selectedDogID) {
                            Text("Ingen").tag(PersistentIdentifier?.none)
                            ForEach(dogs) { dog in
                                Text(dog.name).tag(Optional(dog.persistentModelID))
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ny uppdatering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publicera") { publish() }
                        .disabled(trimmedText.isEmpty || isPosting)
                }
            }
            .task {
                if let uid = authService.currentUserID {
                    teams = await TeamsRepository.shared.myTeams(uid: uid)
                }
            }
        }
    }

    private func publish() {
        guard let uid = authService.currentUserID else {
            errorMessage = "Du måste vara inloggad."
            return
        }
        let selectedDog = dogs.first { $0.persistentModelID == selectedDogID }
        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                let profile = try await FriendsRepository.shared.fetchMyProfile(uid: uid)
                try await PostsRepository.shared.createPost(
                    authorUid: uid,
                    authorName: profile?.displayName ?? "Hundägare",
                    text: trimmedText,
                    dogRemoteID: selectedDog?.remoteID?.uuidString,
                    dogName: selectedDog?.name,
                    photoData: photoData,
                    team: selectedTeam
                )
                onPosted()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NewPostView()
        .modelContainer(for: Dog.self, inMemory: true)
}
