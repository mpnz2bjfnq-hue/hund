//
//  NewPostView.swift
//  UppdragHund
//

import SwiftUI
import SwiftData

/// Skriv en ny uppdatering till din profil. Textbaserad i v1, med valfri
/// koppling till en av dina hundar.
struct NewPostView: View {
    /// Anropas efter lyckad publicering så profilen kan uppdatera sig.
    var onPosted: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Dog> { !$0.isShared }, sort: \Dog.name) private var dogs: [Dog]

    @State private var authService = AuthService.shared
    @State private var text = ""
    @State private var selectedDogID: PersistentIdentifier?
    @State private var errorMessage: String?
    @State private var isPosting = false

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
                    dogName: selectedDog?.name
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
