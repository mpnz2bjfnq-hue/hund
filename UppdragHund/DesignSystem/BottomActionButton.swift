//
//  BottomActionButton.swift
//  UppdragHund
//
//  Primärknapp förankrad i botten av skapa-/spara-flöden, nära tummen,
//  i stället för uppe i navigationsfältet. Läggs på med .bottomActionButton().
//

import SwiftUI
import UIKit

extension View {
    /// Fäster en stor primärknapp längst ner på skärmen (ovanför hemindikatorn).
    /// - Parameters:
    ///   - title: Knapptext, t.ex. "Spara".
    ///   - disabled: Grå och otryckbar, t.ex. tills formuläret är giltigt.
    ///   - isBusy: Visar en spinner och blockerar dubbeltryck under pågående arbete.
    ///   - celebratesSave: Succé-haptik + kort ✓-animation innan action körs.
    ///     Slå på för spara-flöden; av för start-/navigeringsknappar.
    func bottomActionButton(
        _ title: String,
        disabled: Bool = false,
        isBusy: Bool = false,
        celebratesSave: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom) {
            BottomActionButtonBody(
                title: title,
                disabled: disabled,
                isBusy: isBusy,
                celebratesSave: celebratesSave,
                action: action
            )
        }
    }
}

private struct BottomActionButtonBody: View {
    let title: String
    let disabled: Bool
    let isBusy: Bool
    let celebratesSave: Bool
    let action: () -> Void

    @State private var showingCheckmark = false

    var body: some View {
        Button {
            guard !showingCheckmark else { return }
            if celebratesSave {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.spring(duration: 0.25, bounce: 0.5)) {
                    showingCheckmark = true
                }
                // Låt ✓:et hinna landa innan formuläret stängs.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    action()
                    // Stängde inte åtgärden vyn (t.ex. sparfel) måste knappen
                    // gå att trycka igen — annars fastnar den som ✓.
                    withAnimation { showingCheckmark = false }
                }
            } else {
                action()
            }
        } label: {
            Group {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                } else if showingCheckmark {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(title)
                        .font(.body.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(disabled || isBusy)
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
        .background(.bar)
    }
}
