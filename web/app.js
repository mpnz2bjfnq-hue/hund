//
// Canine360 — deltagar-webb för hundkurser.
// Samma Firebase-projekt som iOS-appen: samma konton, team, uppgifter och
// träffar. Byggd för deltagare utan iPhone (Android/dator).
//

import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js";
import {
  initializeAppCheck, ReCaptchaV3Provider,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-check.js";
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword,
  createUserWithEmailAndPassword, signOut, updateProfile,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-auth.js";
import {
  getFirestore, collection, doc, getDoc, getDocs, setDoc, updateDoc,
  query, where, orderBy, limit, arrayUnion, arrayRemove, serverTimestamp,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js";
import {
  getFunctions, httpsCallable,
} from "https://www.gstatic.com/firebasejs/10.12.2/firebase-functions.js";

const app = initializeApp({
  projectId: "canine360-f1221",
  appId: "1:266247775406:web:8b13bc6fc4f3c77f68393f",
  apiKey: "AIzaSyDQyE6mB3eqJ0nh03occ5jNAyYUp3tfnvo",
  authDomain: "canine360-f1221.firebaseapp.com",
  storageBucket: "canine360-f1221.firebasestorage.app",
  messagingSenderId: "266247775406",
});
// App Check: intygar att anropen kommer från den riktiga webbappen
// (reCAPTCHA v3) så Firestore/Functions kan enforca. Site-nyckeln är
// PUBLIK och hör hemma i klientkoden; secret-nyckeln bor bara i
// Firebase-konsolen. Måste initieras FÖRE getFirestore/getFunctions.
// TODO: byt ut mot din reCAPTCHA v3 site key från google.com/recaptcha/admin.
const RECAPTCHA_V3_SITE_KEY = "6LebhVotAAAAAN2CU-Lba9HhyuZluLTZPk1_KFXw";
if (RECAPTCHA_V3_SITE_KEY !== "DIN_RECAPTCHA_V3_SITE_KEY") {
  initializeAppCheck(app, {
    provider: new ReCaptchaV3Provider(RECAPTCHA_V3_SITE_KEY),
    isTokenAutoRefreshEnabled: true,
  });
}

const auth = getAuth(app);
const db = getFirestore(app);
const functions = getFunctions(app, "europe-north1");

// ---------- Hjälpare ----------

const $ = (id) => document.getElementById(id);
const views = ["view-loading", "view-auth", "view-teams", "view-team"];
function show(viewId) {
  views.forEach((v) => $(v).classList.toggle("hidden", v !== viewId));
}
function esc(s) {
  const div = document.createElement("div");
  div.textContent = s ?? "";
  return div.innerHTML;
}
function fmtDate(ts) {
  if (!ts?.toDate) return "";
  return ts.toDate().toLocaleString("sv-SE", {
    weekday: "short", day: "numeric", month: "short",
    hour: "2-digit", minute: "2-digit",
  });
}
function bytesToURL(bytes) {
  try {
    const arr = bytes.toUint8Array();
    return URL.createObjectURL(new Blob([arr], { type: "image/jpeg" }));
  } catch { return null; }
}

let currentUser = null;
let currentTeam = null;

// ---------- Auth ----------

let isSignupMode = false;

$("auth-toggle").onclick = () => {
  isSignupMode = !isSignupMode;
  $("auth-name-row").classList.toggle("hidden", !isSignupMode);
  $("auth-submit").textContent = isSignupMode ? "Skapa konto" : "Logga in";
  $("auth-toggle").textContent = isSignupMode
    ? "Har du redan ett konto? Logga in"
    : "Ny här? Skapa konto";
  $("auth-error").classList.add("hidden");
};

$("auth-submit").onclick = async () => {
  const email = $("auth-email").value.trim();
  const password = $("auth-password").value;
  const name = $("auth-name").value.trim();
  const errorEl = $("auth-error");
  errorEl.classList.add("hidden");

  if (!email || password.length < 6 || (isSignupMode && !name)) {
    errorEl.textContent = "Fyll i alla fält — lösenordet behöver minst 6 tecken.";
    errorEl.classList.remove("hidden");
    return;
  }

  $("auth-submit").disabled = true;
  try {
    if (isSignupMode) {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(cred.user, { displayName: name });
      await ensureProfile(cred.user, name);
    } else {
      await signInWithEmailAndPassword(auth, email, password);
    }
  } catch (e) {
    const messages = {
      "auth/invalid-credential": "Fel e-post eller lösenord.",
      "auth/user-not-found": "Fel e-post eller lösenord.",
      "auth/wrong-password": "Fel e-post eller lösenord.",
      "auth/email-already-in-use": "E-posten används redan — logga in i stället.",
      "auth/invalid-email": "Ogiltig e-postadress.",
      "auth/weak-password": "Lösenordet behöver minst 6 tecken.",
    };
    errorEl.textContent = messages[e.code] ?? "Något gick fel — försök igen.";
    errorEl.classList.remove("hidden");
  }
  $("auth-submit").disabled = false;
};

$("btn-signout").onclick = () => signOut(auth);

/// Samma självläkning som iOS: profil-dokument med namn + auto-handle,
/// så att vänner/teammedlemmar ser ett riktigt namn.
async function ensureProfile(user, fallbackName) {
  const ref = doc(db, "users", user.uid);
  const snapshot = await getDoc(ref);
  const data = snapshot.data();
  if (data?.displayName && data?.handle) return;

  const alphabet = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ";
  const suffix = Array.from({ length: 6 }, () =>
    alphabet[Math.floor(Math.random() * alphabet.length)]).join("");
  await setDoc(ref, {
    displayName: data?.displayName ?? fallbackName ?? user.displayName ?? "Hundägare",
    handle: data?.handle ?? `DOG-${suffix}`,
    createdAt: data?.createdAt ?? serverTimestamp(),
  }, { merge: true });
}

onAuthStateChanged(auth, async (user) => {
  currentUser = user;
  if (!user) {
    show("view-auth");
    return;
  }
  await ensureProfile(user, null).catch(() => {});
  await loadTeams();
  show("view-teams");
});

// ---------- Mina team ----------

async function loadTeams() {
  const snapshot = await getDocs(query(
    collection(db, "teams"),
    where("memberUids", "array-contains", currentUser.uid),
  ));
  const teams = snapshot.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .sort((a, b) => (a.name ?? "").localeCompare(b.name ?? "", "sv"));

  const list = $("teams-list");
  list.innerHTML = "";
  $("teams-empty").classList.toggle("hidden", teams.length > 0);

  for (const team of teams) {
    const kindNames = { consulting: "Konsulentverksamhet", course: "Hundkurs", social: "Vanlig grupp" };
    const button = document.createElement("button");
    button.className = "team-row";
    let icon = "🐾";
    let iconHTML = icon;
    if (team.photoData) {
      const url = bytesToURL(team.photoData);
      if (url) iconHTML = `<img src="${url}" alt="">`;
    }
    button.innerHTML = `
      <span class="team-icon">${iconHTML}</span>
      <span>
        <div>${esc(team.name)}</div>
        <div class="sub">${(team.memberUids ?? []).length} medlemmar · ${kindNames[team.teamType] ?? "Team"}</div>
      </span>
      <span class="chev">›</span>`;
    button.onclick = () => openTeam(team);
    list.appendChild(button);
  }
}

$("btn-join").onclick = async () => {
  const code = $("join-code").value.trim();
  const errorEl = $("join-error");
  errorEl.classList.add("hidden");
  if (code.replace(/[^A-Za-z0-9]/g, "").length < 6) {
    errorEl.textContent = "Ange hela koden.";
    errorEl.classList.remove("hidden");
    return;
  }
  $("btn-join").disabled = true;
  try {
    const join = httpsCallable(functions, "joinTeamWithCode");
    const result = await join({ code });
    $("join-code").value = "";
    await loadTeams();
    alert(`Välkommen! Du är nu med i ${result.data?.teamName ?? "teamet"}. 🎉`);
  } catch {
    errorEl.textContent = "Det gick inte att gå med — kontrollera koden och försök igen.";
    errorEl.classList.remove("hidden");
  }
  $("btn-join").disabled = false;
};

// ---------- Teamsida ----------

document.querySelectorAll(".tab").forEach((tab) => {
  tab.onclick = () => {
    document.querySelectorAll(".tab").forEach((t) => t.classList.toggle("active", t === tab));
    ["posts", "tasks", "meetups", "members"].forEach((name) => {
      $(`tab-${name}`).classList.toggle("hidden", tab.dataset.tab !== name);
    });
  };
});

$("btn-back").onclick = () => {
  currentTeam = null;
  loadTeams();
  show("view-teams");
};

async function openTeam(team) {
  // Hämta färskt team-dokument så medlemslistan är aktuell.
  const fresh = await getDoc(doc(db, "teams", team.id)).catch(() => null);
  currentTeam = fresh?.exists() ? { id: team.id, ...fresh.data() } : team;
  $("team-title").textContent = currentTeam.name;

  // Vanliga grupper har inga uppgifter — dölj fliken (matchar iOS).
  const hasTasks = currentTeam.teamType !== "social";
  document.querySelector('[data-tab="tasks"]').classList.toggle("hidden", !hasTasks);
  document.querySelector('[data-tab="posts"]').click();

  show("view-team");
  renderMembers();
  await Promise.all([loadPosts(), hasTasks ? loadTasks() : Promise.resolve(), loadMeetups()]);
}

function renderMembers() {
  const container = $("tab-members");
  container.innerHTML = "";
  const uids = currentTeam.memberUids ?? [];
  const consultants = currentTeam.consultantUids ?? [];

  for (const uid of uids) {
    const roles = [
      uid === currentTeam.ownerUid ? `<span class="badge">Ägare</span>` : "",
      consultants.includes(uid) ? `<span class="badge">Konsulent</span>` : "",
      uid === currentUser.uid ? `<span class="badge warn">Du</span>` : "",
    ].join("");
    const item = document.createElement("div");
    item.className = "item";
    item.innerHTML = `<div class="title">${esc(currentTeam.memberNames?.[uid] ?? "Medlem")} ${roles}</div>`;
    container.appendChild(item);
  }
  const meta = document.createElement("p");
  meta.className = "empty";
  meta.textContent = `${uids.length} medlemmar`;
  container.appendChild(meta);
}

async function loadPosts() {
  const container = $("tab-posts");
  container.innerHTML = `<p class="empty">Laddar…</p>`;
  const snapshot = await getDocs(query(
    collection(db, "teams", currentTeam.id, "posts"),
    orderBy("createdAt", "desc"), limit(50),
  )).catch(() => null);

  const posts = snapshot?.docs.map((d) => d.data()) ?? [];
  if (posts.length === 0) {
    container.innerHTML = `<p class="empty">Inga inlägg än.</p>`;
    return;
  }
  container.innerHTML = "";
  for (const post of posts) {
    const item = document.createElement("div");
    item.className = "item";
    let photoHTML = "";
    if (post.photoData) {
      const url = bytesToURL(post.photoData);
      if (url) photoHTML = `<img class="post-photo" src="${url}" alt="">`;
    }
    item.innerHTML = `
      <div class="body">${esc(post.text)}</div>${photoHTML}
      <div class="meta">${esc(post.authorName ?? "")} · ${fmtDate(post.createdAt)}</div>`;
    container.appendChild(item);
  }
}

async function loadTasks() {
  const container = $("tab-tasks");
  container.innerHTML = `<p class="empty">Laddar…</p>`;
  const snapshot = await getDocs(query(
    collection(db, "teams", currentTeam.id, "tasks"),
    orderBy("createdAt", "desc"),
  )).catch(() => null);

  const tasks = snapshot?.docs.map((d) => ({ id: d.id, ...d.data() })) ?? [];
  if (tasks.length === 0) {
    container.innerHTML = `<p class="empty">Inga uppgifter än.</p>`;
    return;
  }
  container.innerHTML = "";
  for (const task of tasks) {
    const done = (task.completedUids ?? []).includes(currentUser.uid);
    const item = document.createElement("div");
    item.className = "item";
    const extras = [
      task.trainingPlan?.title ? `<span class="badge">Pass: ${esc(task.trainingPlan.title)}</span>` : "",
      task.meetupTitle ? `<span class="badge">Träff: ${esc(task.meetupTitle)}</span>` : "",
      task.dueDate ? `<span class="badge warn">Klar senast ${fmtDate(task.dueDate)}</span>` : "",
    ].join("");
    item.innerHTML = `
      <div class="task-check ${done ? "done" : ""}">
        <div class="box">${done ? "✓" : ""}</div>
        <div style="flex:1">
          <div class="title">${esc(task.title)}</div>
          ${task.note ? `<div class="body muted">${esc(task.note)}</div>` : ""}
          ${extras ? `<div style="margin-top:6px">${extras}</div>` : ""}
          <div class="meta">Utlagd av ${esc(task.createdByName ?? "")} · ${(task.completedUids ?? []).length} klara</div>
        </div>
      </div>`;
    item.querySelector(".task-check").onclick = async () => {
      await updateDoc(doc(db, "teams", currentTeam.id, "tasks", task.id), {
        completedUids: done ? arrayRemove(currentUser.uid) : arrayUnion(currentUser.uid),
      }).catch(() => {});
      loadTasks();
    };
    container.appendChild(item);
  }
}

async function loadMeetups() {
  const container = $("tab-meetups");
  container.innerHTML = `<p class="empty">Laddar…</p>`;
  const snapshot = await getDocs(query(
    collection(db, "meetups"),
    where("invitedUids", "array-contains", currentUser.uid),
  )).catch(() => null);

  const meetups = (snapshot?.docs.map((d) => ({ id: d.id, ...d.data() })) ?? [])
    .filter((m) => m.teamId === currentTeam.id)
    .sort((a, b) => (a.date?.seconds ?? 0) - (b.date?.seconds ?? 0));

  if (meetups.length === 0) {
    container.innerHTML = `<p class="empty">Inga träffar planerade.</p>`;
    return;
  }
  container.innerHTML = "";
  for (const meetup of meetups) {
    const going = (meetup.goingUids ?? []).includes(currentUser.uid);
    const declined = (meetup.declinedUids ?? []).includes(currentUser.uid);
    const spots = meetup.maxSpots
      ? `${(meetup.goingUids ?? []).length} av ${meetup.maxSpots} platser`
      : `${(meetup.goingUids ?? []).length} kommer`;
    const isFull = meetup.maxSpots && (meetup.goingUids ?? []).length >= meetup.maxSpots;
    const series = meetup.seriesIndex && meetup.seriesCount
      ? `<span class="badge">Tillfälle ${meetup.seriesIndex} av ${meetup.seriesCount}</span>` : "";
    const isPast = meetup.date?.toDate && meetup.date.toDate() < new Date();

    const item = document.createElement("div");
    item.className = "item";
    if (isPast) item.style.opacity = "0.55";
    item.innerHTML = `
      <div class="title">${esc(meetup.title)}</div>
      <div class="meta">📍 ${esc(meetup.locationName ?? "")} · ${fmtDate(meetup.date)}</div>
      <div style="margin-top:6px">${series}<span class="badge">${spots}</span>${isFull && !going ? '<span class="badge warn">Fullt</span>' : ""}</div>
      ${isPast ? "" : `
      <div class="rsvp-row">
        <button class="btn small outline ${going ? "selected" : ""}" data-rsvp="going" ${isFull && !going ? "disabled" : ""}>
          ${going ? "✓ Kommer" : isFull ? "Fullt" : "Kommer"}
        </button>
        <button class="btn small outline declined ${declined ? "selected" : ""}" data-rsvp="declined">
          ${declined ? "✗ Kan inte" : "Kan inte"}
        </button>
      </div>`}`;

    item.querySelectorAll("[data-rsvp]").forEach((button) => {
      button.onclick = async () => {
        const wantsGoing = button.dataset.rsvp === "going";
        await updateDoc(doc(db, "meetups", meetup.id), {
          goingUids: wantsGoing ? arrayUnion(currentUser.uid) : arrayRemove(currentUser.uid),
          declinedUids: wantsGoing ? arrayRemove(currentUser.uid) : arrayUnion(currentUser.uid),
        }).catch(() => {});
        loadMeetups();
      };
    });
    container.appendChild(item);
  }
}
