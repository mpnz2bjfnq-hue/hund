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
  doc, getDoc, getDocs, setDoc, deleteDoc, updateDoc, collection, query, where,
  arrayUnion, arrayRemove, increment, writeBatch,
} from "firebase/firestore";

const OWNER = "owner-uid";
const FRIEND = "friend-uid";     // mottagare av delningen
const STRANGER = "stranger-uid"; // inloggad men ej delaktig
const DOG = "11111111-2222-3333-4444-555555555555";
const TEAM = "team-1";
const TASK = "task-1";
// Fast skapelsedatum så uppgiftstester kan bevara createdAt oförändrat.
const TASK_CREATED = new Date("2026-01-01T00:00:00Z");

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
    // Team: OWNER äger, FRIEND är vanlig medlem. En uppgift skapad av ägaren.
    await setDoc(doc(db, "teams", TEAM), {
      name: "Valpkurs", ownerUid: OWNER, ownerName: "Alex",
      memberUids: [OWNER, FRIEND], memberNames: { [OWNER]: "Alex", [FRIEND]: "Vän" },
      consultantUids: [], teamType: "course", createdAt: new Date(),
    });
    await setDoc(doc(db, "teams", TEAM, "tasks", TASK), {
      title: "Träna inkallning", note: null, dueDate: null,
      createdByUid: OWNER, createdByName: "Alex", createdAt: TASK_CREATED,
      completedUids: [],
    });
    // Träffar: vänträff med platser kvar, fullbokad träff, och en stadsträff
    // som saknar invitedNames-fältet helt (nil-säkerheten i update-regeln).
    await setDoc(doc(db, "meetups", "meetup-1"), {
      title: "Träningsträff", locationName: "Parken", date: new Date(),
      ownerUid: OWNER, ownerName: "Alex",
      invitedUids: [FRIEND, STRANGER], invitedNames: { [OWNER]: "Alex" },
      goingUids: [STRANGER], declinedUids: [], createdAt: new Date(), maxSpots: 2,
    });
    await setDoc(doc(db, "meetups", "meetup-full"), {
      title: "Full kurs", locationName: "Hallen", date: new Date(),
      ownerUid: OWNER, ownerName: "Alex",
      invitedUids: [FRIEND, STRANGER], invitedNames: {},
      goingUids: [STRANGER], declinedUids: [], createdAt: new Date(), maxSpots: 1,
    });
    await setDoc(doc(db, "communities", "city-1"), {
      name: "Hundstaden", memberCount: 1, createdAt: new Date(),
    });
    await setDoc(doc(db, "communities", "city-1", "members", STRANGER), {
      joinedAt: new Date(),
    });
    await setDoc(doc(db, "meetups", "meetup-city"), {
      title: "Stadsträff", locationName: "Torget", date: new Date(),
      ownerUid: OWNER, ownerName: "Alex", communityId: "city-1",
      invitedUids: [], goingUids: [], declinedUids: [], createdAt: new Date(),
    });
    // Forumtråd för replyCount-hårdningen.
    await setDoc(doc(db, "forum", "thread-1"), {
      title: "Tråd", text: "Innehåll", authorUid: OWNER, authorName: "Alex",
      replyCount: 3, lastActivityAt: new Date(), createdAt: new Date(),
    });
    // Handle-registret: OWNERs eget namn + ett som tillhör FRIEND.
    await setDoc(doc(db, "handles", "alex"), { uid: OWNER });
    await setDoc(doc(db, "handles", "taget"), { uid: FRIEND });
    // Väntande vänförfrågan OWNER → FRIEND (vänstatus-frågorna på profilen).
    await setDoc(doc(db, "friendRequests", "req-1"), {
      fromUid: OWNER, fromDisplayName: "Alex", fromHandle: "alex",
      toUid: FRIEND, status: "pending", createdAt: new Date(),
    });
    // Privat molnbackup: ett träningspass i ägarens eget område.
    await setDoc(doc(db, "userBackups", OWNER, "trainingPlans", "plan-1"), {
      title: "Morgonpass", note: null, createdAt: new Date(),
      authorUid: OWNER, authorName: "Alex", exercises: [],
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

// ===== Team-uppgifter: redigering =====

test("ägaren kan redigera uppgiftens innehåll", async () => {
  await assertSucceeds(
    setDoc(doc(asUser(OWNER), "teams", TEAM, "tasks", TASK), {
      title: "Träna platsliggning", note: "5 min/dag", dueDate: new Date(),
      createdByUid: OWNER, createdByName: "Alex", createdAt: TASK_CREATED,
      completedUids: [],
    })
  );
});

test("vanlig medlem kan INTE redigera uppgiftens innehåll", async () => {
  await assertFails(
    setDoc(doc(asUser(FRIEND), "teams", TEAM, "tasks", TASK), {
      title: "Kapad titel", note: null, dueDate: null,
      createdByUid: OWNER, createdByName: "Alex", createdAt: TASK_CREATED,
      completedUids: [],
    })
  );
});

test("redigering kan inte ändra skaparfält eller andras avbockningar", async () => {
  // Ägaren försöker skriva om createdByUid — ska nekas.
  await assertFails(
    setDoc(doc(asUser(OWNER), "teams", TEAM, "tasks", TASK), {
      title: "Träna inkallning", note: null, dueDate: null,
      createdByUid: FRIEND, createdByName: "Vän", createdAt: TASK_CREATED,
      completedUids: [],
    })
  );
});

test("medlem kan fortfarande bocka av sig själv", async () => {
  await assertSucceeds(
    setDoc(doc(asUser(FRIEND), "teams", TEAM, "tasks", TASK), {
      title: "Träna inkallning", note: null, dueDate: null,
      createdByUid: OWNER, createdByName: "Alex", createdAt: TASK_CREATED,
      completedUids: [FRIEND],
    })
  );
});

// ===== Privat molnbackup (userBackups) =====

test("ägaren kan läsa och skriva sin egen backup", async () => {
  await assertSucceeds(getDoc(doc(asUser(OWNER), "userBackups", OWNER, "trainingPlans", "plan-1")));
  await assertSucceeds(
    setDoc(doc(asUser(OWNER), "userBackups", OWNER, "trainingPlans", "plan-2"), {
      title: "Kvällspass", note: null, createdAt: new Date(),
      authorUid: OWNER, authorName: "Alex", exercises: [],
    })
  );
  await assertSucceeds(deleteDoc(doc(asUser(OWNER), "userBackups", OWNER, "trainingPlans", "plan-1")));
});

test("ingen annan kan läsa eller skriva någons backup", async () => {
  await assertFails(getDoc(doc(asUser(STRANGER), "userBackups", OWNER, "trainingPlans", "plan-1")));
  await assertFails(
    setDoc(doc(asUser(STRANGER), "userBackups", OWNER, "trainingPlans", "evil"), { title: "x" })
  );
  await assertFails(
    getDocs(collection(asUser(FRIEND), "userBackups", OWNER, "trainingPlans"))
  );
});

// ===== users: profiler =====

test("man kan inte sätta instructor-flaggan på sin egen profil", async () => {
  await assertFails(
    setDoc(doc(asUser(OWNER), "users", OWNER), { instructor: true }, { merge: true })
  );
});

// ===== friendRequests: vänstatus-frågorna på profilen =====

test("avsändaren kan fråga på sina utgående förfrågningar (fromUid+toUid+status)", async () => {
  const snap = await assertSucceeds(getDocs(query(
    collection(asUser(OWNER), "friendRequests"),
    where("fromUid", "==", OWNER),
    where("toUid", "==", FRIEND),
    where("status", "==", "pending")
  )));
  if (snap.size !== 1) throw new Error(`väntade 1 utgående förfrågan, fick ${snap.size}`);
});

test("mottagaren kan fråga på sina inkommande förfrågningar (toUid+fromUid+status)", async () => {
  const snap = await assertSucceeds(getDocs(query(
    collection(asUser(FRIEND), "friendRequests"),
    where("toUid", "==", FRIEND),
    where("fromUid", "==", OWNER),
    where("status", "==", "pending")
  )));
  if (snap.size !== 1) throw new Error(`väntade 1 inkommande förfrågan, fick ${snap.size}`);
});

test("främling kan inte fråga på andras förfrågningar", async () => {
  await assertFails(getDocs(query(
    collection(asUser(STRANGER), "friendRequests"),
    where("fromUid", "==", OWNER),
    where("toUid", "==", FRIEND),
    where("status", "==", "pending")
  )));
});

// ===== meetups: RSVP-hårdningen =====

test("inbjuden kan svara för SIG SJÄLV (going + invitedUids + invitedNames)", async () => {
  await assertSucceeds(updateDoc(doc(asUser(FRIEND), "meetups", "meetup-1"), {
    goingUids: arrayUnion(FRIEND),
    declinedUids: arrayRemove(FRIEND),
    invitedUids: arrayUnion(FRIEND),
    ["invitedNames." + FRIEND]: "Vän",
  }));
});

test("inbjuden kan INTE skriva in någon annans uid i goingUids", async () => {
  await assertFails(updateDoc(doc(asUser(FRIEND), "meetups", "meetup-1"), {
    goingUids: arrayUnion(OWNER),
  }));
});

test("inbjuden kan INTE ta bort någon annans RSVP", async () => {
  await assertFails(updateDoc(doc(asUser(FRIEND), "meetups", "meetup-1"), {
    goingUids: arrayRemove(STRANGER),
  }));
});

test("fullbokad träff nekar nya going-svar men tillåter avböj (maxSpots)", async () => {
  await assertFails(updateDoc(doc(asUser(FRIEND), "meetups", "meetup-full"), {
    goingUids: arrayUnion(FRIEND),
  }));
  await assertSucceeds(updateDoc(doc(asUser(FRIEND), "meetups", "meetup-full"), {
    declinedUids: arrayUnion(FRIEND),
  }));
});

test("stadsmedlem kan svara på stadsträff som saknar invitedNames-fältet", async () => {
  await assertSucceeds(updateDoc(doc(asUser(STRANGER), "meetups", "meetup-city"), {
    goingUids: arrayUnion(STRANGER),
    invitedUids: arrayUnion(STRANGER),
    ["invitedNames." + STRANGER]: "Främling",
  }));
});

// ===== forum: replyCount-hårdningen =====

test("replyCount får stegas ±1 men inte sättas godtyckligt på andras trådar", async () => {
  await assertSucceeds(updateDoc(doc(asUser(FRIEND), "forum", "thread-1"), {
    replyCount: increment(1), lastActivityAt: new Date(),
  }));
  await assertFails(updateDoc(doc(asUser(FRIEND), "forum", "thread-1"), {
    replyCount: 999,
  }));
});


// ===== handles: unika @användarnamn + friendCount-låset =====

test("byte till ledigt handle med claim i samma batch tillåts", async () => {
  const db = asUser(OWNER);
  const batch = writeBatch(db);
  batch.set(doc(db, "handles", "nytt-namn"), { uid: OWNER });
  batch.delete(doc(db, "handles", "alex"));
  batch.set(doc(db, "users", OWNER), { handle: "nytt-namn" }, { merge: true });
  await assertSucceeds(batch.commit());
});

test("handlebyte utan registrering i samma batch nekas", async () => {
  await assertFails(
    setDoc(doc(asUser(OWNER), "users", OWNER), { handle: "oregistrerat" }, { merge: true })
  );
});

test("någon annans registrerade handle kan inte tas", async () => {
  const db = asUser(OWNER);
  const batch = writeBatch(db);
  batch.set(doc(db, "handles", "taget"), { uid: OWNER });
  batch.set(doc(db, "users", OWNER), { handle: "taget" }, { merge: true });
  await assertFails(batch.commit());
});

test("klienten kan inte skriva sitt eget friendCount", async () => {
  await assertFails(
    setDoc(doc(asUser(OWNER), "users", OWNER), { friendCount: 9999 }, { merge: true })
  );
});
