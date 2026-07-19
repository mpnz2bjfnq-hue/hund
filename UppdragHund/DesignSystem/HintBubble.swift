//
//  HintBubble.swift
//  UppdragHund
//
//  Liten pulserande tips-bubbla som visar var funktioner finns. Visas tills
//  användaren trycker bort den eller använder funktionen (via dismiss(_:)).
//  Tillståndet sparas i UserDefaults per nyckel.
//

import SwiftUI

struct HintBubble: View {
    // LocalizedStringKey så att tipstexterna blir lokaliserbara nycklar.
    let text: LocalizedStringKey
    private let storageKey: String

    @AppStorage private var dismissed: Bool
    @State private var shown = false

    init(_ text: LocalizedStringKey, key: String) {
        self.text = text
        self.storageKey = key
        _dismissed = AppStorage(wrappedValue: false, key)
    }

    var body: some View {
        if !dismissed {
            Button {
                withAnimation(.easeOut(duration: 0.25)) { dismissed = true }
            } label: {
                HStack(spacing: 6) {
                    Text(text)
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .opacity(0.6)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.Colors.brand)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Theme.Colors.brand.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.Colors.brand.opacity(0.25), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            // Lugn intoning en gång — ingen evig puls.
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.92)
            .onAppear {
                withAnimation(.spring(duration: 0.45, bounce: 0.3)) { shown = true }
            }
            .transition(.opacity)
        }
    }

    /// Markera ett tips som upptäckt (t.ex. när funktionen faktiskt används).
    static func dismiss(_ key: String) {
        UserDefaults.standard.set(true, forKey: key)
    }
}
