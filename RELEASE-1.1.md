# Canine360 1.1 — releaselogg

Allt sedan 1.0 (build 12, tagg `v1.0-build12-appstore`, släppt 2026-07-20).
Branch: `feat/canine360-app-build` t.o.m. `aa79d31`.

## Nya funktioner

### Försäkring per hund
- Nya valfria fält: bolag, försäkringsnummer, telefon, förnyelsedatum
  (AddDogView → "Försäkring (valfritt)").
- Försäkringskort på hundprofilen: stort kopierbart försäkringsnummer,
  "Ring bolaget"-knapp, förnyelsedatum. Följer med i molnbackupen.
- Lokal påminnelse 14 dagar före förnyelsedatumet (självläkande svep vid
  inloggning; änglar får ingen påminnelse).

### Team & vänner
- Konsulentteam kan nu bjuda in med kod/QR precis som kurser — deltagarna
  behöver inte vara vänner i appen.
- QR-koden innehåller en djuplänk: systemkameran öppnar appen direkt på
  Gå med-vyn med koden ifylld.
- Inbyggd QR-skanner i "Gå med med kod" (VisionKit), med vettig vy om
  kameran nekats.
- Teamets medlemslista är tryckbar → medlemmens profil → "Lägg till vän"
  (vänstatus-knapp på alla profiler: lägg till / skickad / svara / vänner).
- "Ta bort vän" via svep/håll-in i vänlistan (från 760b18b-rundan).

### Promenader
- Promenaden mäter nu även med låst skärm/i bakgrunden
  (UIBackgroundModes location; blå indikator under aktiv spårning).
- Tiden är datumbaserad — bakgrundstid tappas inte, Live Activity och
  sparat pass stämmer överens.

## Förbättringar
- Server-pushar skickas på användarens språk (sv/en).
- Sparfel visas med felmeddelande i stället för att sväljas (SaveAlert).
- Tillgänglighet + Dynamic Type-putsar; RSVP-state-fixar.
- Stadsträffar man tackat ja till syns under "Träffar" och får
  1-timmespåminnelsen.
- Blockerade användare markeras i medlems-/deltagarlistor; deras
  kommentarer filtreras korrekt överallt (även efter kontobyte).
- Stadsträffars exakta plats/karta/deltagare visas bara för stadens
  medlemmar (titel/datum kvar för upptäckt).
- @användarnamn är nu hårt unika (handles-register; admin kör
  engångsmigreringen i Adminpanel → Underhåll).
- Vänantal kan inte förfalskas (skrivs enbart av servern).

## Buggfixar (stora granskningen 2026-07-21/22)

### Synk & delning
- Förgiftade tombstones kunde stoppa ALL synk permanent — självläker nu.
- Redigeringar under pågående push tappades tyst — fixat (stämpel före
  push + dirty-generation).
- Nätverksfel mitt i pull kunde radera mottagarens delade hund lokalt
  (inkl. egna opushade poster) — nätverksfel propageras nu i stället.
- Molnåterställda hundar utan loggdata persisterades aldrig — fixat.
- Ägarens push kunde skriva över vänners nyare poster — vänposter
  upsertas aldrig av ägaren längre.
- Delning hoppade fram synkstämpeln så andra modulers ändringar skippades.
- Fotobatchar kunde spräcka Firestores byte-tak — fallback per dokument.
- Molnbackupen bär nu även normaltemp, skapelsedatum och bortgångsdatum.
- Tombstone-läckor städas (raderad hund, avdelad modul, revokad delning).

### Notiser
- Hundradering/återkallad delning/utloggning/kontoradering avbokar nu
  alla hundens notiser (löp, hälsa, försäkring) — inga spöknotiser.
- Löpnotiser byggs upp igen vid inloggning (inte bara via Kalender).
- Radering i Hälsologgen avbokar bokningsnotisen (+ flervals-säkring).
- Live Activity-spöken efter force-quit städas vid appstart.

### Server (regler + Cloud Functions, deployade)
- Träff-RSVP: bara eget uid kan läggas till/tas bort; maxSpots verkställs
  på servern (ingen överbokning); admin kan radera rapporterade träffar.
- Forum: replyCount kan bara stegas ±1.
- Kontoradering är GDPR-komplett: userBackups, deviceTokens, forum,
  community-medlemskap, teamInvites, reports, supportTickets,
  teamJoinCodes och handle-registreringar städas nu också.
- Inget spök-profildokument efter kontoradering (onFriendsChanged-guard).
- Admins "Ta bort innehållet" fungerar för forumtrådar/svar/träffar.

### Övrigt
- "Lämna teamet" fungerar nu för medlemmar (nekades tyst av reglerna).
- Krasch i "Avsluta löp" vid klockskevhet fixad; löplängd/prognos räknas
  dygnsnormaliserat (ingen off-by-one).
- Kalenderprognos pekar inte bakåt; dagvyn matchar kalenderns löpmålning.
- Uppgiftsredigering tappar inte träffkopplingen när träffen passerat.
- Dubbla vänförfrågningar stoppas; "God förmiddag" kl 10–12;
  Idag-karusellen stannar när man svept själv; widget-titel-fallback.
- Hela appen: nya strängar översatta till engelska.

## Inför släppet (manuellt)
1. Merga till `main` → Xcode Cloud bygger.
2. Bumpa MARKETING_VERSION till 1.1.
3. Adminpanel → Underhåll → "Migrera @handles till registret" (en gång).
4. Ny version i App Store Connect, välj molnbuild, klistra in texten
   nedan, ev. nya skärmbilder, skicka in.
5. OBS: nytt bakgrundsläge (plats) — motivering vid ev. granskningsfråga:
   promenadmätning med skärmen låst, aktiv endast under pågående promenad.

---

## App Store "Nyheter i denna version" (svenska)

Stor uppdatering med efterlängtade nyheter och massor av förbättringar!

FÖRSÄKRING PÅ HUNDEN
• Spara bolag, försäkringsnummer och telefon — allt samlat på hundens profil, redo att läsas upp hos veterinären
• Påminnelse innan försäkringen förnyas, så du hinner se över den

TEAM & VÄNNER
• Bjud in till kurser och konsulentteam med QR-kod — skanna direkt i appen eller med kameran
• Tryck på en teammedlem för att se profilen och lägga till som vän
• Ta bort vänner med ett svep

PROMENADER
• Promenaden mäter nu hela vägen — även med skärmen låst

DESSUTOM
• Stadsträffar du tackat ja till syns under Träffar, med påminnelse
• Notiser på ditt språk, tryggare delning av hundar mellan konton och en lång rad buggfixar och förbättringar

Tack för att ni testar, tipsar och rapporterar — fortsätt gärna! 🐾

## App Store "What's New" (English)

A big update with long-requested features and lots of polish!

INSURANCE ON YOUR DOG
• Save the company, policy number and phone — all on your dog's profile, ready at the vet
• Get a reminder before your policy renews

TEAMS & FRIENDS
• Invite people to courses and consultant teams with a QR code — scan it right in the app
• Tap a team member to view their profile and add them as a friend
• Remove friends with a swipe

WALKS
• Walk tracking now keeps measuring — even with the screen locked

AND MORE
• City meetups you've joined now show up under Meetups, with a reminder
• Notifications in your language, safer dog sharing between accounts, and a long list of bug fixes and improvements

Thanks for testing and sharing feedback — keep it coming! 🐾
