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

        /// Tonad fyllnad för inmatningsfält på glasytor. Ljus i mörkt läge,
        /// mörk i ljust — en fast vit ton blir osynlig mot ljus bakgrund.
        static let fieldFill = Color("FieldFill")
        /// Hårfin avgränsning (fältkanter, avdelare) som vänder med färgläget.
        static let hairline = Color("Hairline")

        /// Kortskugga. Mörkt läge tål en djup skugga; på ljus yta blir samma
        /// styrka smutsig, så den dämpas kraftigt där.
        static func cardShadow(_ scheme: ColorScheme, dark: Double = 0.30) -> Color {
            .black.opacity(scheme == .dark ? dark : 0.07)
        }
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
        static let small: CGFloat = 12
        static let card: CGFloat = 20
        static let large: CGFloat = 26
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
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    /// Ytans egen lutning. Mörkt läge lägger en ljus glans uppifrån; ljust läge
    /// kan inte lysa upp en redan vit yta, så där skuggas botten i stället —
    /// samma intryck av ljus uppifrån, motsatt verktyg.
    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [.white.opacity(0.07), .clear]
                : [.clear, .black.opacity(0.030)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Kantljus: ljus överkant och mörkare underkant ger kortet en fysisk
    /// fasett i stället för en platt ram i en enda ton.
    private var edgeGradient: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [.white.opacity(0.14), .white.opacity(0.03)]
                : [.white.opacity(0.95), .black.opacity(0.10)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(surfaceGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(edgeGradient, lineWidth: 0.5)
                    )
            )
            // Två lager: en tät kontaktskugga som förankrar kortet mot ytan,
            // och en vid diffus som ger höjd. En ensam skugga ser billig ut.
            .shadow(
                color: .black.opacity(isDark ? 0.22 : 0.055),
                radius: isDark ? 3 : 2,
                y: 1
            )
            .shadow(
                color: .black.opacity(isDark ? 0.26 : 0.065),
                radius: isDark ? 14 : 16,
                y: isDark ? 6 : 9
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

// MARK: - Skärmyta, tryckrespons och intåg — appens "liv"-verktyg

extension Theme {
    /// Skärmbakgrund med en svag brandglöd upptill i stället för platt färg.
    static var screenSurface: some View {
        ScreenSurface()
    }
}

/// Skärmbakgrunden. Egen vy (inte en `some View`-getter) så den kan läsa
/// färgläget: glöden måste vara betydligt svagare på ljus yta, annars ser
/// den ut som en grön smuts i hörnet i stället för en subtil ton.
private struct ScreenSurface: View {
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    // VIKTIGT: lagren måste ALLTID finnas, bara värdena får skilja mellan
    // lägena. Med `if isDark { … }` ändras vyträdets struktur vid lägesbyte,
    // och att infoga lager mitt under UIKits trait-övergång låste appen
    // (mörkt→ljust frös; ljust→mörkt tog bara bort lager och klarade sig).
    var body: some View {
        ZStack {
            Theme.Colors.screenBackground

            // Ljuskälla uppifrån: ljust läge får en vit ton som klingar av mot
            // botten, så ytan inte blir en död grå platta. Mörkt läge har redan
            // sin djupverkan av svärtan — därav noll opacitet där.
            LinearGradient(
                colors: [
                    .white.opacity(isDark ? 0 : 0.85),
                    .white.opacity(isDark ? 0 : 0.15),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Brandglöd i hörnet — svagare i ljust läge, annars blir den dis.
            RadialGradient(
                colors: [Theme.Colors.brand.opacity(isDark ? 0.09 : 0.055), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 460
            )

            // Ljust läge: en aning djupare mot nederkanten ger skärmen en
            // riktning och får korten att läsa som lyfta ur ytan.
            LinearGradient(
                colors: [.clear, .black.opacity(isDark ? 0 : 0.035)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

/// Tryckrespons för kortlänkar: krymper och dämpas lätt under fingret.
struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

/// Kort med glas + kategoriton som tonar ut mot hörnet (samma recept som
/// Hem-brickorna) — för ytor som ska ha en egen färgidentitet.
private struct TintedCardStyle: ViewModifier {
    var tint: Color
    var padding: CGFloat
    var radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool { colorScheme == .dark }

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // Ljust läge: en vit grund under tonen, annars slår
                    // materialet igenom mot skärmytan och kortet blir grumligt.
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(isDark ? Color.clear : Color.white.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(
                                colors: isDark
                                    ? [tint.opacity(0.20), tint.opacity(0.05)]
                                    : [tint.opacity(0.16), tint.opacity(0.04)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                    )
                    // Samma kantljus som vanliga kort, men i kategorins ton.
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: isDark
                                        ? [tint.opacity(0.34), tint.opacity(0.10)]
                                        : [.white.opacity(0.90), tint.opacity(0.28)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
            .shadow(color: .black.opacity(isDark ? 0.20 : 0.05), radius: isDark ? 3 : 2, y: 1)
            .shadow(color: .black.opacity(isDark ? 0.22 : 0.06), radius: isDark ? 10 : 14, y: isDark ? 4 : 8)
    }
}

extension View {
    func tintedCardStyle(
        _ tint: Color,
        padding: CGFloat = Theme.Spacing.l,
        radius: CGFloat = Theme.Radius.card
    ) -> some View {
        modifier(TintedCardStyle(tint: tint, padding: padding, radius: radius))
    }
}

/// Intågsanimation: innehållet stiger upp och tonar in, förskjutet per index.
private struct RiseIn: ViewModifier {
    let index: Int
    let shown: Bool

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .scaleEffect(shown ? 1 : 0.97)
            .animation(.spring(duration: 0.5, bounce: 0.22).delay(Double(index) * 0.07), value: shown)
    }
}

extension View {
    func riseIn(_ index: Int, shown: Bool) -> some View {
        modifier(RiseIn(index: index, shown: shown))
    }
}

/// Mjuk crossfade när en flik blir synlig i stället för iOS hårda klipp.
/// Medvetet BARA opacity: offset/skala flyttar navigationsfältet med och
/// hackar i toppen av skärmen.
private struct TabAppearTransition: ViewModifier {
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .onAppear {
                shown = false
                withAnimation(.easeOut(duration: 0.28)) { shown = true }
            }
            .onDisappear { shown = false }
    }
}

extension View {
    func tabTransition() -> some View {
        modifier(TabAppearTransition())
    }
}
