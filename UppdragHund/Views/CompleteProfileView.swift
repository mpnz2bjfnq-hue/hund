//
//  CompleteProfileView.swift
//  UppdragHund
//
//  Visas direkt efter inloggning tills användaren valt namn + @användarnamn.
//  Gör att både Apple- och e-postkonton får en riktig profil från start
//  (i stället för platshållaren "Hundägare" och en autogenererad kod).
//

import SwiftUI
import PhotosUI

struct CompleteProfileView: View {
    let profile: UserProfile
    /// Anropas när profilen sparats.
    var onDone: () -> Void

    @State private var authService = AuthService.shared
    @State private var displayName: String
    @State private var username: String
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(profile: UserProfile, onDone: @escaping () -> Void) {
        self.profile = profile
        self.onDone = onDone
        // Förifyll namn om det inte är platshållaren.
        _displayName = State(initialValue: profile.displayName == "Hundägare" ? "" : profile.displayName)
        _username = State(initialValue: profile.needsProfileSetup ? "" : profile.handle)
        _photoData = State(initialValue: profile.photoData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Skapa din profil")
                        .font(.title2.bold())
                        .padding(.top, 8)
                    Text("Välj ett namn och ett användarnamn som dina vänner känner igen dig på.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        ProfileAvatar(photoData: photoData, size: 96)
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(photoData == nil ? "Lägg till profilbild" : "Byt bild")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Ditt namn", text: $displayName)
                            .textContentType(.name)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Text("@").foregroundStyle(.secondary)
                            TextField("användarnamn", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .padding(8)
                        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        Text("a–z, 0–9, punkt och understreck.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Fortsätt").frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isSaving)
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: photoItem) { loadPickedPhoto() }
        }
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
            errorMessage = "Ange ditt namn."
            return
        }
        let normalized = UsernameValidator.normalize(username)
        if let validation = UsernameValidator.validate(normalized) {
            errorMessage = validation.errorDescription
            return
        }

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let available = try await FriendsRepository.shared.isUsernameAvailable(normalized, excludingUid: uid)
                guard available else {
                    errorMessage = "Användarnamnet är upptaget."
                    return
                }
                try await FriendsRepository.shared.updateProfile(
                    uid: uid,
                    displayName: trimmedName,
                    handle: normalized,
                    photoData: photoData != profile.photoData ? .some(photoData) : nil
                )
                CurrentUserStore.shared.apply(displayName: trimmedName, handle: normalized, photoData: .some(photoData))
                onDone()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
