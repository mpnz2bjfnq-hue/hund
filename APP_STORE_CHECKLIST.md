# App Store-inlämning – checklista & granskarnoter

## Att göra i App Store Connect (manuellt)

1. **Integritetspolicy-URL** (App Information → Privacy Policy URL)
   - Aktivera GitHub Pages: repo → Settings → Pages → Source: `main`-branch, mapp `/docs` → Save.
   - URL blir: `https://<ditt-github-namn>.github.io/UppdragHund/privacy.html`
2. **Support-URL** (App Information)
   - `https://<ditt-github-namn>.github.io/UppdragHund/` (supportsidan i /docs)
3. **Demo-konto** (App Review Information)
   - Skapa ett testkonto i appen (e-post + lösenord), lägg gärna in en hund
     och lite data. Fyll i uppgifterna under "Sign-in required".
4. **App Privacy-deklarationen** (utan spårning/annonser):
   - Kontaktinfo: Namn, E-postadress → kopplad till identitet, för appfunktion.
   - Användarinnehåll: Foton/videor, Annat användarinnehåll (inlägg,
     hunddata) → kopplad till identitet, för appfunktion.
   - Identifierare: Användar-ID → kopplad till identitet, för appfunktion.
   - INGEN data används för spårning.
   - Plats: samlas INTE in (används endast lokalt på enheten, lämnar den aldrig).
5. **Åldersklassning**: svara ärligt — socialt innehåll/UGC ger normalt 12+/13+.

## Förslag till "Notes for Review"

> Canine360 is a dog-care app (health tracking, heat-cycle prediction,
> training) with a closed social layer: content is only visible between
> mutually accepted friends and invited team members.
>
> Sign-in is required because the app's core features are account-based:
> cloud sync of dog data between devices, sharing dogs with friends, and
> the social feed. Demo account provided above.
>
> UGC moderation (Guideline 1.2): users can report any post or comment
> (long-press → "Rapportera"), block users (feed → long-press →
> "Blockera"; managed under Settings → "Blockerade användare"), and
> contact us via the in-app support page. Reports are reviewed promptly.
>
> Location is used only to measure walk distance on-device; routes never
> leave the device. Account deletion is available in-app under
> Settings → "Radera konto" and deletes all server data plus the
> Firebase Auth account.

## Innan arkivering
- Höj build-nummer (och ev. versionsnummer).
- Product → Archive → Distribute App → App Store Connect.
