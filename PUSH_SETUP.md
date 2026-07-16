# Push-notiser – setup-checklista

Appkoden är klar (FCM-token registreras vid inloggning, Cloud Functions skickar
push vid nytt inlägg / delad hund / vänförfrågan). Följande steg måste göras på
**dina** Apple-/Firebase-konton innan notiserna fungerar. Ordningen spelar roll.

## 1. Apple Developer Program (betalt)
Push-notiser kräver ett betalt medlemskap ($99/år). Ett gratis-konto kan inte
använda Push-capability.

## 2. Lägg till capability i Xcode
Öppna projektet → target **UppdragHund** → **Signing & Capabilities**:
- Klicka **+ Capability** → lägg till **Push Notifications**.
  (Detta lägger `aps-environment` i entitlements och registrerar Push på App-ID:t
  automatiskt via ditt betalkonto.)
- (Valfritt, för framtida tysta notiser) **+ Capability** → **Background Modes**
  → bocka i **Remote notifications**.

## 3. APNs-nyckel → Firebase
1. [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles**
   → **Keys** → **+** → bocka i **Apple Push Notifications service (APNs)** → skapa.
2. Ladda ner `.p8`-filen (går bara att ladda ner en gång). Notera **Key ID** och ditt **Team ID**.
3. [Firebase Console](https://console.firebase.google.com) → projekt **canine360-f1221**
   → ⚙️ **Project settings** → **Cloud Messaging** → under **Apple app configuration**
   → **APNs Authentication Key** → ladda upp `.p8` + Key ID + Team ID.

## 4. Uppgradera Firebase till Blaze
Cloud Functions kräver **Blaze** (pay-as-you-go). Firebase Console → **Upgrade**
längst ner till vänster. (Fri kvot räcker gott för normal användning.)

## 5. Firestore-säkerhetsregler
Appen skriver enhets-tokens till `users/{uid}/fcmTokens/{token}`. Se till att
reglerna tillåter ägaren att skriva där, t.ex.:

```
match /users/{uid}/fcmTokens/{token} {
  allow read, write: if request.auth != null && request.auth.uid == uid;
}
```

Cloud Functions kör som admin och kringgår reglerna vid utskick.

## 6. Deploya funktionerna
Från repo-roten:

```bash
npm install -g firebase-tools      # om du inte redan har den
firebase login
firebase deploy --only functions   # deployar onNewPost, onDogShared, onFriendRequest
```

## 7. Testa
1. Bygg och installera appen på telefonen (via vanliga flödet).
2. Vid inloggning kommer notis-tillståndsfrågan – tillåt.
3. Be en vän (eller ett testkonto) posta ett inlägg / dela en hund / skicka
   vänförfrågan → du ska få en push.
4. Loggar: `firebase functions:log`.

## Vad koden redan gör
- `AppDelegate` – APNs-registrering, FCM-token, visar notiser i förgrunden.
- `PushNotificationService` – ber om tillstånd, sparar/tar bort token i Firestore.
- `functions/src/index.ts` – tre triggers som skickar push till berörda användare
  och städar bort ogiltiga tokens.
