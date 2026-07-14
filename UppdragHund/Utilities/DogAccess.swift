//
//  DogAccess.swift
//  UppdragHund
//
//  Ren behörighetslogik för vad den inloggade användaren får göra med en hund.
//  UI:t använder detta för att dölja knappar; den faktiska enforcementen
//  ligger i Firestore-säkerhetsreglerna.
//

import Foundation

struct DogAccess {
    let dog: Dog
    let currentUid: String?

    /// Syns modulen alls för den här användaren?
    func isModuleVisible(_ module: SharedModule) -> Bool {
        dog.includes(module)
    }

    /// Får användaren skapa nya poster i modulen?
    func canLog(in module: SharedModule) -> Bool {
        guard dog.isShared else { return true }
        return dog.sharePermission == .readWrite
            && dog.sharedModules.contains(module)
            && currentUid != nil
    }

    /// Får användaren ändra/radera en befintlig post?
    /// Egen hund: allt. Delad hund: endast egna poster, och bara med readWrite.
    func canModify(entryCreatedByUid: String?) -> Bool {
        guard dog.isShared else { return true }
        guard dog.sharePermission == .readWrite, let currentUid else { return false }
        return entryCreatedByUid == currentUid
    }
}
