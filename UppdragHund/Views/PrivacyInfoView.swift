//
//  PrivacyInfoView.swift
//  UppdragHund
//
//  Informationssida om datainsamling, cookies/lagring och användarens
//  rättigheter. Innehållet speglar vad appen faktiskt samlar in.
//

import SwiftUI

struct PrivacyInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Senast uppdaterad 15 juli 2026")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                section(
                    "Vilka uppgifter vi samlar in",
                    """
                    • Konto: din e-postadress, ditt namn och ditt användarnamn (@handle). \
                    Om du loggar in med Apple kan Apple dölja din riktiga e-post.
                    • Profil: en valfri profilbild du själv laddar upp.
                    • Hund- och hälsodata: uppgifter du registrerar om dina hundar – namn, ras, \
                    födelsedatum, kön, foton, hälsohändelser, löp, dagbok, foder och träning.
                    • Socialt: inlägg du delar, dina vänner och vänförfrågningar, samt hundar \
                    du delar med andra.
                    • Enhet: en push-token så vi kan skicka notiser till din telefon.
                    """
                )

                section(
                    "Hur uppgifterna används",
                    """
                    Uppgifterna används för att appen ska fungera: visa och synka dina hundars \
                    information mellan dina enheter, låta dig dela med vänner, och skicka de notiser \
                    du valt. Vi använder inte dina uppgifter för annonsering och vi säljer dem inte.
                    """
                )

                section(
                    "Delning med andra",
                    """
                    Dina inlägg syns för dina vänner i appen. När du delar en hund får den du delar \
                    med tillgång till de moduler du valt. I övrigt delas dina uppgifter inte med \
                    andra användare.
                    """
                )

                section(
                    "Cookies och lokal lagring",
                    """
                    Appen är en vanlig iOS-app och använder inte webbläsar-cookies. För att fungera \
                    lagrar den data lokalt på din enhet (dina hundars uppgifter) samt en \
                    inloggnings-token och en push-token. Ingen spårning för reklam sker.
                    """
                )

                section(
                    "Lagring och säkerhet",
                    """
                    Data som synkas och delas lagras hos Google Firebase (autentisering och databas). \
                    Överföring sker krypterat. Data på din enhet skyddas av iOS.
                    """
                )

                section(
                    "Dina rättigheter",
                    """
                    Du kan när som helst radera ditt konto och all din information under \
                    Inställningar → Radera konto. Då tas din profil, dina inlägg, dina hundar och \
                    tillhörande data bort. Du kan också logga ut när du vill.
                    """
                )

                section(
                    "Kontakt",
                    """
                    Har du frågor om dina uppgifter, kontakta oss via appens support.
                    """
                )
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.Colors.screenBackground)
        .navigationTitle("Integritet & data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(title)
                .font(Theme.Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(body)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyInfoView()
    }
}
