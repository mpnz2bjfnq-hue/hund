//
//  SharingComponents.swift
//  UppdragHund
//
//  Små återanvändbara delningskomponenter.
//

import SwiftUI

/// Visas när en modul inte ingår i delningen av en delad hund.
struct ModuleNotSharedView: View {
    var body: some View {
        ContentUnavailableView(
            "Delas inte",
            systemImage: "eye.slash",
            description: Text("Ägaren delar inte den här delen.")
        )
    }
}

/// "Loggad av X" — visas på poster skapade av någon annan än hundens ägare
/// på egna enheten (createdByName sätts av synken).
struct LoggedByLine: View {
    let name: String?

    var body: some View {
        if let name {
            Label("Loggad av \(name)", systemImage: "person")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
