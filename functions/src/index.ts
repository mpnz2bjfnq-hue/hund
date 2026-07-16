/**
 * Cloud Functions för UppdragHund/Canine360 – push-notiser.
 *
 * Triggar på Firestore-skrivningar och skickar FCM-push till berörda
 * användares enheter. Enhets-tokens lagras av appen under
 * users/{uid}/fcmTokens/{token}.
 */

import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getAuth } from "firebase-admin/auth";

initializeApp();
const db = getFirestore();

/** Hämtar en användares alla enhets-tokens. */
async function tokensForUser(uid: string): Promise<string[]> {
  const snap = await db.collection("users").doc(uid).collection("fcmTokens").get();
  return snap.docs.map((d) => d.id);
}

/** Skickar en notis till en användares alla enheter och städar ogiltiga tokens. */
async function sendToUser(
  uid: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const tokens = await tokensForUser(uid);
  if (tokens.length === 0) return;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  });

  // Ta bort tokens som inte längre är giltiga.
  const invalid: string[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success) {
      const code = r.error?.code ?? "";
      if (
        code.includes("registration-token-not-registered") ||
        code.includes("invalid-argument")
      ) {
        invalid.push(tokens[i]);
      } else {
        logger.warn(`FCM-fel för ${uid}: ${code}`);
      }
    }
  });
  await Promise.all(
    invalid.map((t) =>
      db.collection("users").doc(uid).collection("fcmTokens").doc(t).delete()
    )
  );
}

const REGION = "europe-north1";

/** 1) Nytt inlägg → notifiera författarens vänner. */
export const onNewPost = onDocumentCreated(
  { document: "users/{uid}/posts/{postId}", region: REGION },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const authorUid = event.params.uid;
    const authorName: string = post.authorName ?? "En vän";
    const text: string = post.text ?? "";
    const snippet = text.length > 80 ? `${text.slice(0, 77)}…` : text;

    const friendsSnap = await db
      .collection("users")
      .doc(authorUid)
      .collection("friends")
      .get();

    await Promise.all(
      friendsSnap.docs.map((friend) =>
        sendToUser(friend.id, `${authorName} delade en uppdatering`, snippet, {
          type: "post",
          authorUid,
        })
      )
    );
  }
);

/** 2) Delad hund → notifiera mottagaren. */
export const onDogShared = onDocumentCreated(
  { document: "shares/{shareId}", region: REGION },
  async (event) => {
    const share = event.data?.data();
    if (!share) return;

    const recipientUid: string = share.recipientUid;
    const ownerName: string = share.ownerDisplayName ?? "En vän";
    const dogName: string = share.dogName ?? "en hund";
    if (!recipientUid) return;

    await sendToUser(
      recipientUid,
      "Ny delad hund",
      `${ownerName} delade ${dogName} med dig.`,
      { type: "share", dogRemoteID: share.dogRemoteID ?? "" }
    );
  }
);

/**
 * Raderar en användares konto och ALL data (GDPR "rätt att bli glömd").
 * Körs med admin-rättigheter så den når även data som säkerhetsreglerna
 * hindrar klienten från att röra, och tar bort själva inloggningskontot.
 */
export const deleteAccount = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Du måste vara inloggad.");
  }
  await deleteAllUserData(uid);
  logger.info(`Raderade konto och data för ${uid}`);
  return { ok: true };
});

/** Är uid:t admin enligt config/admins? */
async function isAdminUid(uid: string | undefined): Promise<boolean> {
  if (!uid) return false;
  const doc = await db.collection("config").doc("admins").get();
  const uids: string[] = doc.data()?.uids ?? [];
  return uids.includes(uid);
}

/** Admin: radera en annan användares konto + all data. */
export const adminDeleteUser = onCall({ region: REGION }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!(await isAdminUid(callerUid))) {
    throw new HttpsError("permission-denied", "Endast admin.");
  }
  const targetUid: string = request.data?.targetUid;
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "targetUid saknas.");
  }
  if (targetUid === callerUid) {
    throw new HttpsError("failed-precondition", "Använd Radera konto för ditt eget konto.");
  }
  await deleteAllUserData(targetUid);
  logger.info(`ADMIN ${callerUid} raderade konto ${targetUid}`);
  return { ok: true };
});

/** Admin: skicka en push-notis till ALLA användare. */
export const adminBroadcast = onCall({ region: REGION }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!(await isAdminUid(callerUid))) {
    throw new HttpsError("permission-denied", "Endast admin.");
  }
  const title: string = (request.data?.title ?? "").toString().trim();
  const body: string = (request.data?.body ?? "").toString().trim();
  if (!title || !body) {
    throw new HttpsError("invalid-argument", "Titel och text krävs.");
  }

  const tokensSnap = await db.collectionGroup("fcmTokens").get();
  const tokenDocs = tokensSnap.docs;
  let sent = 0;
  for (let i = 0; i < tokenDocs.length; i += 500) {
    const chunk = tokenDocs.slice(i, i + 500);
    const response = await getMessaging().sendEachForMulticast({
      tokens: chunk.map((d) => d.id),
      notification: { title, body },
      data: { type: "broadcast" },
      apns: { payload: { aps: { sound: "default" } } },
    });
    sent += response.successCount;
    response.responses.forEach((r, j) => {
      if (!r.success) {
        logger.warn(
          `Broadcast-fel för ${chunk[j].ref.path} (…${chunk[j].id.slice(-8)}): ${r.error?.code} – ${r.error?.message}`
        );
      }
    });
  }
  logger.info(`ADMIN ${callerUid} broadcast till ${tokenDocs.length} tokens, ${sent} levererade`);
  return { ok: true, tokens: tokenDocs.length, sent };
});

/** Gemensam raderings-kaskad för deleteAccount + adminDeleteUser. */
async function deleteAllUserData(uid: string): Promise<void> {
  // 1) Ta bort mig ur mina vänners friends-listor (kopplingen är dubbelriktad).
  const friendsSnap = await db.collection("users").doc(uid).collection("friends").get();
  await Promise.all(
    friendsSnap.docs.map((f) =>
      db.collection("users").doc(f.id).collection("friends").doc(uid).delete().catch(() => undefined)
    )
  );

  // 2) Mitt användardokument + subkollektioner (posts, friends, fcmTokens).
  await db.recursiveDelete(db.collection("users").doc(uid));

  // 3) Vänförfrågningar där jag är avsändare eller mottagare.
  const [fromReqs, toReqs] = await Promise.all([
    db.collection("friendRequests").where("fromUid", "==", uid).get(),
    db.collection("friendRequests").where("toUid", "==", uid).get(),
  ]);
  await Promise.all(
    [...fromReqs.docs, ...toReqs.docs].map((d) => d.ref.delete().catch(() => undefined))
  );

  // 4) Delningar jag äger eller är mottagare av.
  const [ownShares, recvShares] = await Promise.all([
    db.collection("shares").where("ownerUid", "==", uid).get(),
    db.collection("shares").where("recipientUid", "==", uid).get(),
  ]);
  await Promise.all(
    [...ownShares.docs, ...recvShares.docs].map((d) => d.ref.delete().catch(() => undefined))
  );

  // 5) Delade hundar jag äger (med alla modul-subkollektioner).
  const myDogs = await db.collection("sharedDogs").where("ownerUid", "==", uid).get();
  await Promise.all(myDogs.docs.map((d) => db.recursiveDelete(d.ref)));

  // 6) Team: ta bort team jag äger, lämna team jag är med i.
  const [ownedTeams, memberTeams] = await Promise.all([
    db.collection("teams").where("ownerUid", "==", uid).get(),
    db.collection("teams").where("memberUids", "array-contains", uid).get(),
  ]);
  await Promise.all(ownedTeams.docs.map((d) => d.ref.delete().catch(() => undefined)));
  await Promise.all(
    memberTeams.docs
      .filter((d) => d.data().ownerUid !== uid)
      .map((d) =>
        d.ref
          .update({
            memberUids: FieldValue.arrayRemove(uid),
            [`memberNames.${uid}`]: FieldValue.delete(),
          })
          .catch(() => undefined)
      )
  );

  // 7) Träffar: ta bort mina, plocka bort mig ur andras.
  const [ownedMeetups, invitedMeetups] = await Promise.all([
    db.collection("meetups").where("ownerUid", "==", uid).get(),
    db.collection("meetups").where("invitedUids", "array-contains", uid).get(),
  ]);
  await Promise.all(ownedMeetups.docs.map((d) => d.ref.delete().catch(() => undefined)));
  await Promise.all(
    invitedMeetups.docs
      .filter((d) => d.data().ownerUid !== uid)
      .map((d) =>
        d.ref
          .update({
            invitedUids: FieldValue.arrayRemove(uid),
            goingUids: FieldValue.arrayRemove(uid),
            declinedUids: FieldValue.arrayRemove(uid),
            [`invitedNames.${uid}`]: FieldValue.delete(),
          })
          .catch(() => undefined)
      )
  );

  // 8) Själva inloggningskontot.
  await getAuth().deleteUser(uid).catch(() => undefined);
}

/** 9) Enhet bytte konto → ta bort enhetens token från tidigare konto,
 *  så pushar inte läcker mellan konton på samma telefon. */
export const onDeviceTokenClaimed = onDocumentWritten(
  { document: "deviceTokens/{token}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after?.uid) return;
    if (!before?.uid || before.uid === after.uid) return;

    const token = event.params.token;
    await db
      .collection("users")
      .doc(before.uid)
      .collection("fcmTokens")
      .doc(token)
      .delete()
      .catch(() => undefined);
    logger.info(`Token flyttad från ${before.uid} till ${after.uid}`);
  }
);

/** 10) Vänlista ändrad → uppdatera denormaliserat friendCount på profilen,
 *  så att andra användare (som inte får läsa vänlistan) kan se antalet. */
export const onFriendsChanged = onDocumentWritten(
  { document: "users/{uid}/friends/{friendId}", region: REGION },
  async (event) => {
    const uid = event.params.uid;
    const snap = await db.collection("users").doc(uid).collection("friends").count().get();
    await db
      .collection("users")
      .doc(uid)
      .set({ friendCount: snap.data().count }, { merge: true })
      .catch(() => undefined);
  }
);

/** 7) Nytt supportärende → notifiera alla admins. */
export const onNewTicket = onDocumentCreated(
  { document: "supportTickets/{ticketId}", region: REGION },
  async (event) => {
    const ticket = event.data?.data();
    if (!ticket) return;
    const adminsDoc = await db.collection("config").doc("admins").get();
    const adminUids: string[] = adminsDoc.data()?.uids ?? [];
    const name: string = ticket.name ?? "En användare";
    const subject: string = ticket.subject ?? "Supportärende";
    const isFeedback = ticket.kind === "feedback";
    await Promise.all(
      adminUids.map((uid) =>
        sendToUser(
          uid,
          isFeedback ? "Ny feedback 💬" : "Nytt supportärende 🎫",
          `${name}: ${subject}`,
          { type: isFeedback ? "feedback" : "supportTicket", ticketId: event.params.ticketId }
        )
      )
    );
  }
);

/** 8) Ärende markerat som löst → notifiera användaren. */
export const onTicketResolved = onDocumentWritten(
  { document: "supportTickets/{ticketId}", region: REGION },
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status !== "open" || after.status !== "resolved") return;
    if (after.kind === "feedback") return;

    const uid: string = after.uid;
    const subject: string = after.subject ?? "ditt ärende";
    if (!uid) return;
    await sendToUser(uid, "Supportärende löst ✅", `Vi har löst: ${subject}`, {
      type: "supportTicketResolved",
    });
  }
);

/** 6) Team-inbjudan → notifiera mottagaren (även vid förnyad inbjudan). */
export const onTeamInvite = onDocumentWritten(
  { document: "teamInvites/{inviteId}", region: REGION },
  async (event) => {
    const after = event.data?.after?.data();
    if (!after || after.status !== "pending") return;
    const before = event.data?.before?.data();
    // Skicka bara när inbjudan blir pending (ny eller förnyad).
    if (before && before.status === "pending") return;

    const toUid: string = after.toUid;
    const fromName: string = after.fromName ?? "En vän";
    const teamName: string = after.teamName ?? "ett team";
    if (!toUid) return;

    await sendToUser(toUid, "Team-inbjudan", `${fromName} bjuder in dig till ${teamName}.`, {
      type: "teamInvite",
      teamId: after.teamId ?? "",
    });
  }
);

/** 5) Nytt team-inlägg → notifiera teamets övriga medlemmar. */
export const onNewTeamPost = onDocumentCreated(
  { document: "teams/{teamId}/posts/{postId}", region: REGION },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const teamSnap = await db.collection("teams").doc(event.params.teamId).get();
    const team = teamSnap.data();
    if (!team) return;

    const members: string[] = team.memberUids ?? [];
    const authorName: string = post.authorName ?? "En vän";
    const text: string = post.text ?? "";
    const snippet = text.length > 80 ? `${text.slice(0, 77)}…` : text;

    await Promise.all(
      members
        .filter((uid) => uid !== post.authorUid)
        .map((uid) =>
          sendToUser(uid, `${authorName} i ${team.name}`, snippet, {
            type: "teamPost",
            teamId: event.params.teamId,
          })
        )
    );
  }
);

/** 4) Ny hundträff → notifiera de inbjudna. */
/** Ny uppgift i ett team → notifiera alla medlemmar utom den som la ut den. */
export const onNewTeamTask = onDocumentCreated(
  { document: "teams/{teamId}/tasks/{taskId}", region: REGION },
  async (event) => {
    const task = event.data?.data();
    if (!task) return;

    const teamSnap = await db.collection("teams").doc(event.params.teamId).get();
    const team = teamSnap.data();
    if (!team) return;

    const members: string[] = team.memberUids ?? [];
    const byName: string = task.createdByName ?? "En konsulent";
    const title: string = task.title ?? "ny uppgift";

    await Promise.all(
      members
        .filter((uid) => uid !== task.createdByUid)
        .map((uid) =>
          sendToUser(uid, `Ny uppgift i ${team.name}`, `${byName}: ${title}`, {
            type: "teamTask",
            teamId: event.params.teamId,
          })
        )
    );
  }
);

export const onNewMeetup = onDocumentCreated(
  { document: "meetups/{meetupId}", region: REGION },
  async (event) => {
    const meetup = event.data?.data();
    if (!meetup) return;

    const ownerName: string = meetup.ownerName ?? "En vän";
    const title: string = meetup.title ?? "hundträff";
    const location: string = meetup.locationName ?? "";
    const when = meetup.date?.toDate?.()
      ? new Intl.DateTimeFormat("sv-SE", { dateStyle: "medium", timeStyle: "short" }).format(meetup.date.toDate())
      : "";
    const invited: string[] = meetup.invitedUids ?? [];

    await Promise.all(
      invited
        .filter((uid) => uid !== meetup.ownerUid)
        .map((uid) =>
          sendToUser(uid, `${ownerName} bjuder in till ${title}`, `${location}${when ? ` · ${when}` : ""}`, {
            type: "meetup",
            meetupId: event.params.meetupId,
          })
        )
    );
  }
);

/** 3) Vänförfrågan → notifiera mottagaren. */
export const onFriendRequest = onDocumentCreated(
  { document: "friendRequests/{reqId}", region: REGION },
  async (event) => {
    const req = event.data?.data();
    if (!req || req.status !== "pending") return;

    const toUid: string = req.toUid;
    const fromName: string = req.fromDisplayName ?? "Någon";
    if (!toUid) return;

    await sendToUser(toUid, "Ny vänförfrågan", `${fromName} vill bli din vän.`, {
      type: "friendRequest",
      fromUid: req.fromUid ?? "",
    });
  }
);
