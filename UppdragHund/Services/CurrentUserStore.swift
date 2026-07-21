//
//  CurrentUserStore.swift
//  UppdragHund
//
//  Cachar den inloggade användarens profil (namn, användarnamn, profilbild)
//  så headern och profilsidan kan visa samma data och uppdateras direkt
//  efter en redigering.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class CurrentUserStore {
    static let shared = CurrentUserStore()

    private(set) var profile: UserProfile?

    private init() {}

    /// Profilbilden som UIImage, om någon är uppladdad.
    var avatarImage: UIImage? {
        profile?.photoData.flatMap(UIImage.init(data:))
    }

    /// Hämtar profilen och själv-läker ett saknat/ofullständigt dokument
    /// (t.ex. bara dogSummaries → avkodningsfel) så gaten inte fastnar.
    /// Innan läkningen verifieras att kontot fortfarande finns — annars skulle
    /// en enhet med kvarvarande session återskapa ett raderat kontos profil.
    func refresh() async {
        guard let uid = AuthService.shared.currentUserID else {
            profile = nil
            return
        }
        var fetched = try? await FriendsRepository.shared.fetchMyProfile(uid: uid)
        if fetched == nil {
            guard await AuthService.shared.accountStillExists() else {
                profile = nil
                try? AuthService.shared.signOut()
                return
            }
            let name = AuthService.shared.currentDisplayName ?? String(localized: "Hundägare")
            try? await FriendsRepository.shared.ensureProfile(uid: uid, displayName: name, email: nil)
            fetched = try? await FriendsRepository.shared.fetchMyProfile(uid: uid)
        }
        // Kontobyte medan hämtningen pågick? Skriv då inte in det GAMLA
        // kontots profil som "min" — nästa refresh för rätt konto gäller.
        guard AuthService.shared.currentUserID == uid else { return }
        profile = fetched
    }

    /// Sätt profilen direkt (t.ex. när en vy redan hämtat den).
    func setProfile(_ profile: UserProfile) {
        self.profile = profile
    }

    /// Uppdatera lokalt direkt efter en lyckad redigering (optimistiskt).
    func apply(
        displayName: String? = nil,
        handle: String? = nil,
        photoData: Data?? = nil,
        coverPhotoData: Data?? = nil,
        bio: String?? = nil,
        favoritePhotoDatas: [Data]?? = nil
    ) {
        guard var updated = profile else { return }
        if let displayName { updated.displayName = displayName }
        if let handle { updated.handle = handle }
        if let photoData { updated.photoData = photoData }
        if let coverPhotoData { updated.coverPhotoData = coverPhotoData }
        if let bio { updated.bio = bio }
        if let favoritePhotoDatas { updated.favoritePhotoDatas = favoritePhotoDatas }
        profile = updated
    }

    func clear() {
        profile = nil
    }
}
