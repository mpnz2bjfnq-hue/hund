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
    let text: String
    private let storageKey: String

    @AppStorage private var dismissed: Bool
    @State private var pulse = false

    init(_ text: String, key: String) {
        self.text = text
        self.storageKey = key
        _dismissed = AppStorage(wrappedValue: false, key)
    }

    var body: some View {
        if !dismissed {
            Button {
                withAnimation(.spring(duration: 0.3)) { dismissed = true }
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
            }
            .buttonStyle(.plain)
            .scaleEffect(pulse ? 1.06 : 1)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }

    /// Markera ett tips som upptäckt (t.ex. när funktionen faktiskt används).
    static func dismiss(_ key: String) {
        UserDefaults.standard.set(true, forKey: key)
    }
}
