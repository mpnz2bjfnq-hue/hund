# Firestore-säkerhetsregler

`firestore.rules` i repo-roten är källan till sanning för Firestore-reglerna.
De deployas inte automatiskt — gör så här efter varje ändring:

## Deploy via Firebase-konsolen (enklast)

1. Öppna [Firebase-konsolen](https://console.firebase.google.com) → ditt projekt
2. **Firestore Database** → fliken **Regler**
3. Klistra in hela innehållet i `firestore.rules`
4. **Publicera**

## Deploy via CLI (alternativ)

```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

(Kräver en `firebase.json` som pekar på regelfilen — skapas med `firebase init firestore`.)

## Vad reglerna gör

- **users/friendRequests**: som tidigare — profiler läsbara för inloggade
  (krävs för handle-uppslag), vänförfrågningar bara för inblandade parter.
- **users/{uid}/posts**: profilinlägg. Ägaren skapar/raderar; ägaren och
  vänner (finns i ägarens `friends`-subkollektion) kan läsa.
- **shares/{dogRemoteID}_{recipientUid}**: ägaren skapar/ändrar/tar bort,
  mottagaren kan läsa sin egen. Dokument-ID:ts format är tvingande —
  reglerna för `sharedDogs` slår upp exakt den sökvägen med `exists()/get()`.
- **sharedDogs/{dogId}** + subkollektioner: ägaren har full åtkomst.
  En mottagare kan läsa hunddokumentet om en share finns, och läsa en modul
  endast om den ingår i sharens `modules`-lista. Skrivning för mottagare
  kräver `permission == "readWrite"`, att modulen delas, och att
  `createdByUid` är mottagarens egen uid.

**Obs:** varje modulläsning kostar en extra `get()` (dokumentläsning) för
regelutvärderingen — väntat och okej på den här datamängden.

**Viktigt:** UI:t döljer bara knappar; det är de här reglerna som faktiskt
hindrar en läs-vän från att skriva. Testa gärna i konsolens Rules Playground.
