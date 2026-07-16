//
//  BottomActionButton.swift
//  UppdragHund
//
//  Primärknapp förankrad i botten av skapa-/spara-flöden, nära tummen,
//  i stället för uppe i navigationsfältet. Läggs på med .bottomActionButton().
//

import SwiftUI

extension View {
    /// Fäster en stor primärknapp längst ner på skärmen (ovanför hemindikatorn).
    /// - Parameters:
    ///   - title: Knapptext, t.ex. "Spara".
    ///   - disabled: Grå och otryckbar, t.ex. tills formuläret är giltigt.
    ///   - isBusy: Visar en spinner och blockerar dubbeltryck under pågående arbete.
    func bottomActionButton(
        _ title: String,
        disabled: Bool = false,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom) {
            Button(action: action) {
                Group {
                    if isBusy {
                        ProgressView()
                            .tint(.white)
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
}
