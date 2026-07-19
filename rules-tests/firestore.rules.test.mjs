//
//  firestore.rules.test.mjs
//  Canine360
//
//  Säkerhetsregeltester mot Firestore-emulatorn. Täcker appens kritiska
//  invarianter: delade hundars modulbehörigheter, shares-frågor,
//  deviceTokens-härdningen och profilskrivningar.
//
//  Kör:  firebase emulators:exec --only firestore "npm --prefix rules-tests test"
//

import { test, before, after, beforeEach } from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc, getDoc, getDocs, setDoc, deleteDoc, collection, query, where,
} from "firebase/firestore";

const OWNER = "owner-uid";
const FRIEND = "friend-uid";     // mottagare av delningen
const STRANGER = "stranger-uid"; // inloggad men ej delaktig
const DOG = "11111111-2222-3333-4444-555555555555";

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: "canine360-rules-test",
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Grunddata skrivs med reglerna avstängda (som admin-SDK:t).
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // Delning: ägaren delar hälsologg + foder med FRIEND, readWrite.
    await setDoc(doc(db, "shares", `${DOG}_${FRIEND}`), {
      dogRemoteID: DOG,
      ownerUid: OWNER,
      ownerDisplayName: "Alex",
      dogName: "Sixten",
      recipientUid: FRIEND,
      modules: ["health", "meals"],
      permission: "readWrite",
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "sharedDogs", DOG), {
      ownerUid: OWNER,
      ownerDisplayName: "Alex",
      name: "Sixten",
      breed: "Malinois",
      birthDate: new Date(),
      sex: "male",
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "sharedDogs", DOG, "healthEvents", "owner-entry"), {
      type: "vetVisit", title: "Vaccination", date: new Date(),
      createdByUid: OWNER, createdByName: "Alex", updatedAt: new Date(),
    });
    await setDoc(doc(db, "sharedDogs", DOG, "healthEvents", "friend-entry"), {
      type: "weighing", title: "Vägning", date: new Date(),
      createdByUid: FRIEND, createdByName: "Vän", updatedAt: new Date(),
    });
    await setDoc(doc(db, "sharedDogs", DOG, "diaryEntries", "secret-diary"), {
      date: new Date(), bleedingLevel: 1, swellingLevel: 1, appetiteLevel: 3,
      energyLevel: 3, mood: "good", createdByUid: OWNER, createdByName: "Alex",
      updatedAt: new Date(),
    });
    await setDoc(doc(db, "users", OWNER), {
      displayName: "Alex", handle: "alex", createdAt: new Date(),
    });
    await setDoc(doc(db, "deviceTokens", "token-owner"), {
      uid: OWNER, updatedAt: new Date(),
    });
    await setDoc(doc(db, "deviceTokens", "token-friend"), {
      uid: FRIEND, updatedAt: new Date(),
    });
  });
});

const asUser = (uid) => env.authenticatedContext(uid).firestore();

// ===== Delade hundar: modulläsning =====

test("mottagare kan lista delad modul (healthEvents)", async () => {
  const snap = await assertSucceeds(
    getDocs(collection(asUser(FRIEND), "sharedDogs", DOG, "healthEvents"))
  );
  if (snap.size !== 2) throw new Error(`väntade 2 poster, fick ${snap.size}`);
});

test("mottagare kan INTE läsa modul som inte delats (diaryEntries)", async () => {
  await assertFails(
    getDocs(collection(asUser(FRIEND), "sharedDogs", DOG, "diaryEntries"))
  );
});

test("främling kan inte läsa delad modul eller hunddokumentet", async () => {
  await assertFails(
    getDocs(collection(asUser(STRANGER), "sharedDogs", DOG, "healthEvents"))
  );
  await assertFails(getDoc(doc(asUser(STRANGER), "sharedDogs", DOG)));
});

test("mottagare kan läsa hunddokumentet, ägaren likaså", async () => {
  await assertSucceeds(getDoc(doc(asUser(FRIEND), "sharedDogs", DOG)));
  await assertSucceeds(getDoc(doc(asUser(OWNER), "sharedDogs", DOG)));
});

test("ägaren kan lista sina egna backup-hundar; främling kan inte lista alla", async () => {
  // Molnbackup-frågan: sharedDogs filtrerat på ownerUid.
  await assertSucceeds(
    getDocs(query(collection(asUser(OWNER), "sharedDogs"), where("ownerUid", "==", OWNER)))
  );
  // Ofiltrerad list (försök skörda andras hundar) ska nekas.
  await assertFails(getDocs(collection(asUser(STRANGER), "sharedDogs")));
});

// ===== Delade hundar: skrivningar =====

test("readWrite-mottagare kan skapa egen post i delad modul", async () => {
  await assertSucceeds(
    setDoc(doc(asUser(FRIEND), "sharedDogs", DOG, "mealEntries", "new-meal"), {
      type: "meal", time: new Date(), name: "Frukost",
      createdByUid: FRIEND, createdByName: "Vän", updatedAt: new Date(),
    })
  );
});

test("mottagare kan INTE skapa post med någon annans författar-uid", async () => {
  await assertFails(
    setDoc(doc(asUser(FRIEND), "sharedDogs", DOG, "mealEntries", "forged"), {
      type: "meal", time: new Date(), name: "Falsk",
      createdByUid: OWNER, createdByName: "Alex", updatedAt: new Date(),
    })
  );
});

test("mottagare kan radera SIN post men inte ägarens", async () => {
  await assertSucceeds(
    deleteDoc(doc(asUser(FRIEND), "sharedDogs", DOG, "healthEvents", "friend-entry"))
  );
  await assertFails(
    deleteDoc(doc(asUser(FRIEND), "sharedDogs", DOG, "healthEvents", "owner-entry"))
  );
});

test("ägaren kan skriva och radera i alla moduler", async () => {
  await assertSucceeds(
    setDoc(doc(asUser(OWNER), "sharedDogs", DOG, "diaryEntries", "new"), {
      date: new Date(), bleedingLevel: 1, swellingLevel: 1, appetiteLevel: 3,
      energyLevel: 3, mood: "good", createdByUid: OWNER, createdByName: "Alex",
      updatedAt: new Date(),
    })
  );
  await assertSucceeds(
    deleteDoc(doc(asUser(OWNER), "sharedDogs", DOG, "healthEvents", "owner-entry"))
  );
});

// ===== Shares: frågeformerna klienten använder =====

test("ägarens shares-fråga (ownerUid + dogRemoteID) tillåts", async () => {
  await assertSucceeds(
    getDocs(query(
      collection(asUser(OWNER), "shares"),
      where("ownerUid", "==", OWNER),
      where("dogRemoteID", "==", DOG)
    ))
  );
});

test("mottagarens shares-fråga (recipientUid) tillåts", async () => {
  await assertSucceeds(
    getDocs(query(
      collection(asUser(FRIEND), "shares"),
      where("recipientUid", "==", FRIEND)
    ))
  );
});

test("shares-fråga utan ägar-/mottagarfilter nekas (dagens bugg)", async () => {
  await assertFails(
    getDocs(query(
      collection(asUser(OWNER), "shares"),
      where("dogRemoteID", "==", DOG)
    ))
  );
});

test("främling kan inte läsa någon annans share", async () => {
  await assertFails(getDoc(doc(asUser(STRANGER), "shares", `${DOG}_${FRIEND}`)));
});

// ===== deviceTokens: härdningen =====

test("ingen inloggad kan LISTA deviceTokens", async () => {
  await assertFails(getDocs(collection(asUser(STRANGER), "deviceTokens")));
});

test("man kan bara registrera token på sitt eget konto", async () => {
  await assertSucceeds(
    setDoc(doc(asUser(FRIEND), "deviceTokens", "friend-new-token"), {
      uid: FRIEND, updatedAt: new Date(),
    })
  );
  await assertFails(
    setDoc(doc(asUser(STRANGER), "deviceTokens", "hijack"), {
      uid: OWNER, updatedAt: new Date(),
    })
  );
});

test("den som kan token-ID:t får hämta och radera posten", async () => {
  await assertSucceeds(getDoc(doc(asUser(FRIEND), "deviceTokens", "token-friend")));
  await assertSucceeds(deleteDoc(doc(asUser(FRIEND), "deviceTokens", "token-friend")));
});

// ===== users: profiler =====

test("inloggad kan läsa profiler; utloggad kan inte", async () => {
  await assertSucceeds(getDoc(doc(asUser(STRANGER), "users", OWNER)));
  await assertFails(
    getDoc(doc(env.unauthenticatedContext().firestore(), "users", OWNER))
  );
});

test("man kan inte skriva någon annans profil", async () => {
  await assertFails(
    setDoc(doc(asUser(STRANGER), "users", OWNER), { displayName: "Hackad" }, { merge: true })
  );
});

test("man kan inte sätta instructor-flaggan på sin egen profil", async () => {
  await assertFails(
    setDoc(doc(asUser(OWNER), "users", OWNER), { instructor: true }, { merge: true })
  );
});
