//
//  EditProfileView.swift
//  UppdragHund
//

import SwiftUI
import PhotosUI

/// Redigera visningsnamn, användarnamn (@handle) och profilbild.
struct EditProfileView: View {
    let currentProfile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared

    @State private var displayName: String
    @State private var username: String
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?

    @State private var errorMessage: String?
    @State private var isSaving = false

    init(currentProfile: UserProfile) {
        self.currentProfile = currentProfile
        _displayName = State(initialValue: currentProfile.displayName)
        _username = State(initialValue: currentProfile.handle)
        _photoData = State(initialValue: currentProfile.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            avatar
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                Text(photoData == nil ? "Lägg till bild" : "Byt bild")
                            }
                            if photoData != nil {
                                Button("Ta bort bild", role: .destructive) {
                                    photoData = nil
                                    photoItem = nil
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("Namn") {
                    TextField("Visningsnamn", text: $displayName)
                        .textContentType(.name)
                }

                Section {
                    HStack {
                        Text("@")
                            .foregroundStyle(.secondary)
                        TextField("användarnamn", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Användarnamn")
                } footer: {
                    Text("Vänner lägger till dig via ditt användarnamn. a–z, 0–9, punkt och understreck.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Redigera profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Spara") { save() }
                        .disabled(isSaving)
                }
            }
            .onChange(of: photoItem) {
                loadPickedPhoto()
            }
        }
    }

    private var avatar: some View {
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
        .frame(width: 96, height: 96)
        .clipShape(Circle())
    }

    private func loadPickedPhoto() {
        guard let photoItem else { return }
        Task {
            if let data = try? await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let thumb = AvatarImage.makeThumbnailData(from: image) {
                photoData = thumb
            }
        }
    }

    private func save() {
        guard let uid = authService.currentUserID else { return }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Ange ett visningsnamn."
            return
        }
        let normalizedUsername = UsernameValidator.normalize(username)
        if let validation = UsernameValidator.validate(normalizedUsername) {
            errorMessage = validation.errorDescription
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let usernameChanged = normalizedUsername != currentProfile.handle
                if usernameChanged {
                    let available = try await FriendsRepository.shared.isUsernameAvailable(normalizedUsername, excludingUid: uid)
                    guard available else {
                        errorMessage = "Användarnamnet är upptaget."
                        return
                    }
                }

                let photoChanged = photoData != currentProfile.photoData
                try await FriendsRepository.shared.updateProfile(
                    uid: uid,
                    displayName: trimmedName == currentProfile.displayName ? nil : trimmedName,
                    handle: usernameChanged ? normalizedUsername : nil,
                    photoData: photoChanged ? .some(photoData) : nil
                )
                CurrentUserStore.shared.apply(
                    displayName: trimmedName,
                    handle: normalizedUsername,
                    photoData: .some(photoData)
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
