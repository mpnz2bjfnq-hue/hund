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
        ZStack {
            Theme.screenSurface

            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    VStack(spacing: Theme.Spacing.s) {
                        Text("Skapa din profil")
                            .font(Theme.Typography.screenTitle)
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("Välj ett namn och ett användarnamn som dina vänner känner igen dig på.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, Theme.Spacing.xl)

                    // Avatar med kamerabricka, som på profilsidan.
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            ProfileAvatar(photoData: photoData, size: 104)
                                .overlay(Circle().stroke(Theme.Colors.brand, lineWidth: 2.5))
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(Circle().fill(Theme.Colors.brand))
                                .overlay(Circle().stroke(Theme.Colors.screenBackground, lineWidth: 2))
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: Theme.Spacing.m) {
                        profileField(icon: "person", placeholder: "Ditt namn", text: $displayName)
                            .textContentType(.name)
                        profileField(icon: "at", placeholder: "användarnamn", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Text("a–z, 0–9, punkt och understreck.")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let errorMessage {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(errorMessage)
                                Spacer(minLength: 0)
                            }
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.warning)
                        }

                        Button {
                            save()
                        } label: {
                            Group {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Fortsätt").font(.body.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(Theme.Colors.brand)
                        .disabled(isSaving)
                        .padding(.top, 2)
                    }
                    .cardStyle()
                }
                .padding(Theme.Spacing.l)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: photoItem) { loadPickedPhoto() }
        }
        .preferredColorScheme(.dark)
    }

    /// Tonat inmatningsfält med ikon — samma som inloggningsskärmen.
    private func profileField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .fill(.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
        )
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
