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

    func refresh() async {
        guard let uid = AuthService.shared.currentUserID else {
            profile = nil
            return
        }
        profile = try? await FriendsRepository.shared.fetchMyProfile(uid: uid)
    }

    /// Uppdatera lokalt direkt efter en lyckad redigering (optimistiskt).
    func apply(displayName: String? = nil, handle: String? = nil, photoData: Data?? = nil) {
        guard var updated = profile else { return }
        if let displayName { updated.displayName = displayName }
        if let handle { updated.handle = handle }
        if let photoData { updated.photoData = photoData }
        profile = updated
    }

    func clear() {
        profile = nil
    }
}
