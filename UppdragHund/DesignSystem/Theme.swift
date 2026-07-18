//
//  Theme.swift
//  UppdragHund
//
//  Delad design-grund: färger, spacing, radie, typografi och kortstil.
//  Färgerna backas av asset-katalogen (dark-låst nu, adaptiva senare).
//

import SwiftUI

enum Theme {

    // MARK: - Färger

    enum Colors {
        /// Varumärke + primära actions (grön #34C759). Delas med systemets accent.
        static let brand = Color.accentColor

        static let screenBackground = Color("ScreenBackground")
        static let cardBackground = Color("CardBackground")

        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")

        // Semantiska statusfärger — bär betydelse, ska inte bli gröna.
        static let heat = Color("Heat")          // löp
        static let verified = Color("Verified")  // verifierad-bock
        static let warning = Color("Warning")    // varningar/påminnelser
    }

    // MARK: - Spacing (8pt-baserad skala)

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Hörnradie

    enum Radius {
        static let small: CGFloat = 10
        static let card: CGFloat = 16
        static let large: CGFloat = 22
        static let pill: CGFloat = 999
    }

    // MARK: - Typografi-ramp

    enum Typography {
        /// Stor sidrubrik, t.ex. "Kalender".
        static let screenTitle = Font.title2.weight(.bold)
        /// Sektionsrubrik, t.ex. "Översikt", "Kommande".
        static let sectionTitle = Font.title3.weight(.bold)
        /// Framträdande värde, t.ex. vikt-siffran på ett stat-kort.
        static let metric = Font.title2.weight(.semibold)
        /// Standardtext.
        static let body = Font.body
        /// Sekundär/etikett-text.
        static let caption = Font.subheadline
        /// Liten bildtext.
        static let footnote = Font.footnote
    }
}

// MARK: - Kortstil

private struct CardStyle: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                Theme.Colors.cardBackground,
                in: RoundedRectangle(cornerRadius: radius, style: .continuous)
            )
    }
}

extension View {
    /// Enhetlig kort-yta: mörk fyllnad + rundade hörn + inre padding.
    func cardStyle(
        padding: CGFloat = Theme.Spacing.l,
        radius: CGFloat = Theme.Radius.card
    ) -> some View {
        modifier(CardStyle(padding: padding, radius: radius))
    }
}

// MARK: - Zoom-övergång (iOS 18+), tyst no-op på iOS 17

/// Hundkortet växer upp till profilsidan (Apples zoom-transition). API:t
/// finns först i iOS 18 — på iOS 17 blir det en vanlig push.
extension View {
    @ViewBuilder
    func heroZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func heroZoomDestination(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
