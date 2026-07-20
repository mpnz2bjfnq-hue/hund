//
//  SaveAlert.swift
//  UppdragHund
//
//  Delad hantering av misslyckade SwiftData-sparningar. Tidigare gjorde varje
//  spara-flöde `try? modelContext.save()` och stängde direkt — misslyckades
//  sparandet försvann posten utan att användaren fick veta något.
//

import SwiftData
import SwiftUI

extension ModelContext {
    /// Sparar och returnerar ett felmeddelande om det misslyckas (annars nil).
    ///
    /// Vid fel rullas de väntande ändringarna tillbaka, så att ett nytt
    /// spara-försök inte lägger in dubbletter av samma post.
    func saveOrMessage() -> String? {
        do {
            try save()
            return nil
        } catch {
            rollback()
            return String(localized: "Posten kunde inte sparas. Försök igen.")
        }
    }
}

extension View {
    /// Visar en standardiserad felruta när en sparning misslyckats.
    func saveErrorAlert(_ message: Binding<String?>) -> some View {
        alert(
            "Kunde inte spara",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
