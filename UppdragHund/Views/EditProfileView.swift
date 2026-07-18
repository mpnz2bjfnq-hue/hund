//
//  EditProfileView.swift
//  UppdragHund
//

import SwiftUI
import PhotosUI

/// Redigera visningsnamn, användarnamn (@handle), profilbild, omslag,
/// presentation och favoritbilder.
struct EditProfileView: View {
    let currentProfile: UserProfile

    /// Max antal favoritbilder på profilen.
    static let favoriteSlotCount = 4
    /// Bio hålls kort — det är en presentationsrad, inte en blogg.
    static let bioMaxLength = 160

    @Environment(\.dismiss) private var dismiss
    @State private var authService = AuthService.shared

    @State private var displayName: String
    @State private var username: String
    @State private var bio: String
    @State private var photoData: Data?
    @State private var coverPhotoData: Data?
    @State private var favoritePhotos: [Data]

    @State private var photoItem: PhotosPickerItem?
    @State private var coverItem: PhotosPickerItem?
    @State private var favoriteItem: PhotosPickerItem?

    /// Vart nästa beskuren bild ska ta vägen.
    private enum CropTarget {
        case avatar
        case cover
        case favorite
    }

    @State private var cropCandidate: CropCandidate?
    @State private var cropTarget: CropTarget = .avatar

    @State private var errorMessage: String?
    @State private var isSaving = false

    init(currentProfile: UserProfile) {
        self.currentProfile = currentProfile
        _displayName = State(initialValue: currentProfile.displayName)
        _username = State(initialValue: currentProfile.handle)
        _bio = State(initialValue: currentProfile.bio ?? "")
        _photoData = State(initialValue: currentProfile.photoData)
        _coverPhotoData = State(initialValue: currentProfile.coverPhotoData)
        _favoritePhotos = State(initialValue: currentProfile.favoritePhotoDatas ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                coverSection
                avatarSection

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

                bioSection
                favoritesSection

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
            .onChange(of: photoItem) { loadPicked(photoItem, as: .avatar) }
            .onChange(of: coverItem) { loadPicked(coverItem, as: .cover) }
            .onChange(of: favoriteItem) { loadPicked(favoriteItem, as: .favorite) }
            .sheet(item: $cropCandidate) { candidate in
                switch cropTarget {
                case .avatar:
                    ImageCropView(image: candidate.image, outputWidth: 512) { data in
                        photoData = data
                    }
                case .cover:
                    ImageCropView(image: candidate.image, outputWidth: 900, aspect: 16 / 9, quality: 0.55) { data in
                        coverPhotoData = data
                    }
                case .favorite:
                    ImageCropView(image: candidate.image, outputWidth: 480, quality: 0.55) { data in
                        if favoritePhotos.count < Self.favoriteSlotCount {
                            favoritePhotos.append(data)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Omslag

    private var coverSection: some View {
        Section {
            VStack(spacing: 12) {
                if let coverPhotoData, let image = UIImage(data: coverPhotoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Theme.Colors.brand.opacity(0.3), Theme.Colors.cardBackground],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(height: 110)
                        .overlay {
                            Label("Omslagsbild", systemImage: "photo.on.rectangle.angled")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                }
                HStack(spacing: Theme.Spacing.l) {
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Text(coverPhotoData == nil ? "Lägg till omslag" : "Byt omslag")
                            .font(.caption)
                    }
                    if coverPhotoData != nil {
                        Button("Ta bort", role: .destructive) {
                            coverPhotoData = nil
                            coverItem = nil
                        }
                        .font(.caption)
                    }
                }
            }
        } footer: {
            Text("Omslaget visas överst på din profil, som på andra sociala appar.")
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Profilbild

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    avatar
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(photoData == nil ? "Lägg till bild" : "Byt bild")
                    }
                    if photoData != nil {
                        Button("Justera bild") {
                            if let data = photoData, let image = UIImage(data: data) {
                                cropTarget = .avatar
                                cropCandidate = CropCandidate(image: image)
                            }
                        }
                        .font(.caption)
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
    }

    // MARK: - Presentation

    private var bioSection: some View {
        Section {
            TextField("Kort presentation…", text: $bio, axis: .vertical)
                .lineLimit(2...4)
                .onChange(of: bio) { _, newValue in
                    if newValue.count > Self.bioMaxLength {
                        bio = String(newValue.prefix(Self.bioMaxLength))
                    }
                }
        } header: {
            Text("Presentation")
        } footer: {
            Text("T.ex. ”🐾 Schäferägare från Örebro. Tränar IPO och lydnad.” Max \(Self.bioMaxLength) tecken.")
        }
    }

    // MARK: - Favoritbilder

    private var favoritesSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 4), spacing: Theme.Spacing.s) {
                ForEach(favoritePhotos.indices, id: \.self) { index in
                    if let image = UIImage(data: favoritePhotos[index]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                            .contextMenu {
                                Button("Ta bort", systemImage: "trash", role: .destructive) {
                                    favoritePhotos.remove(at: index)
                                }
                            }
                    }
                }
                if favoritePhotos.count < Self.favoriteSlotCount {
                    PhotosPicker(selection: $favoriteItem, matching: .images) {
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .fill(Theme.Colors.brand.opacity(0.10))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.Colors.brand)
                            }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Favoritbilder")
        } footer: {
            Text("Upp till fyra bilder som visas på din profil. Håll in en bild för att ta bort den.")
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

    // MARK: - Laddning & spar

    private func loadPicked(_ item: PhotosPickerItem?, as target: CropTarget) {
        guard let item else { return }
        Task {
            // Öppna beskärningen med originalet — användaren väljer själv
            // utsnitt och zoom innan bilden komprimeras.
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                cropTarget = target
                cropCandidate = CropCandidate(image: image)
            }
            switch target {
            case .avatar: photoItem = nil
            case .cover: coverItem = nil
            case .favorite: favoriteItem = nil
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

                let trimmedBio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
                let photoChanged = photoData != currentProfile.photoData
                let coverChanged = coverPhotoData != currentProfile.coverPhotoData
                let bioChanged = trimmedBio != (currentProfile.bio ?? "")
                let favoritesChanged = favoritePhotos != (currentProfile.favoritePhotoDatas ?? [])

                try await FriendsRepository.shared.updateProfile(
                    uid: uid,
                    displayName: trimmedName == currentProfile.displayName ? nil : trimmedName,
                    handle: usernameChanged ? normalizedUsername : nil,
                    photoData: photoChanged ? .some(photoData) : nil,
                    coverPhotoData: coverChanged ? .some(coverPhotoData) : nil,
                    bio: bioChanged ? .some(trimmedBio.isEmpty ? nil : trimmedBio) : nil,
                    favoritePhotoDatas: favoritesChanged ? .some(favoritePhotos.isEmpty ? nil : favoritePhotos) : nil
                )
                CurrentUserStore.shared.apply(
                    displayName: trimmedName,
                    handle: normalizedUsername,
                    photoData: .some(photoData),
                    coverPhotoData: .some(coverPhotoData),
                    bio: .some(trimmedBio.isEmpty ? nil : trimmedBio),
                    favoritePhotoDatas: .some(favoritePhotos.isEmpty ? nil : favoritePhotos)
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
