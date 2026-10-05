/**
 * Dragon Boat Runner – Cloud Functions
 *
 * 1. notifySessionChange: when the admin / co-admin creates, changes or
 *    deletes a training, race or event, every team member gets a push
 *    notification (FCM topics team_<teamId>_en / team_<teamId>_de).
 * 2. trainingReminder: every 10 minutes – about 3 hours before a training,
 *    members who have not answered yet (no 👍/👎/❓) get a personal push.
 * 3. cleanupDeletedTeam: when the admin deletes a team, all its data, the
 *    invite code and the team entry in every member's profile are removed.
 * 4. sendFeedback: feedback written in the app is e-mailed to the developer.
 *    The address lives only here on the server – users never see it.
 *
 * Secrets (set once):
 *   firebase functions:secrets:set GMAIL_USER          (a Gmail address used to send)
 *   firebase functions:secrets:set GMAIL_APP_PASSWORD  (Google "App password")
 */
const {onDocumentWritten, onDocumentCreated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const nodemailer = require("nodemailer");

initializeApp();

// Must be the same region as your Firestore database (README: europe-west3).
const REGION = "europe-west3";
const TIME_ZONE = "Europe/Berlin";
const FEEDBACK_TO = "mohsen.khanmohammadi.electrical@gmail.com";

setGlobalOptions({region: REGION, maxInstances: 5});

const GMAIL_USER = defineSecret("GMAIL_USER");
const GMAIL_APP_PASSWORD = defineSecret("GMAIL_APP_PASSWORD");

const TEXT = {
  en: {
    training: "Training", race: "Race", event: "Event",
    created: "New", updated: "Changed", deleted: "Cancelled",
  },
  de: {
    training: "Training", race: "Rennen", event: "Veranstaltung",
    created: "Neu", updated: "Geändert", deleted: "Abgesagt",
  },
};

function same(a, b) {
  if (a && typeof a.toMillis === "function" && b && typeof b.toMillis === "function") {
    return a.toMillis() === b.toMillis();
  }
  return (a ?? null) === (b ?? null);
}

exports.notifySessionChange = onDocumentWritten(
    "teams/{teamId}/sessions/{sessionId}",
    async (event) => {
      const before = event.data.before.exists ? event.data.before.data() : null;
      const after = event.data.after.exists ? event.data.after.data() : null;

      let kind;
      if (!before && after) kind = "created";
      else if (before && !after) kind = "deleted";
      else {
        const fields = ["type", "title", "start", "location", "notes"];
        if (!fields.some((f) => !same(before[f], after[f]))) return; // e.g. seating only
        kind = "updated";
      }

      const s = after || before;
      const {teamId, sessionId} = event.params;
      const start = s.start && s.start.toDate ? s.start.toDate() : new Date();

      for (const lang of ["en", "de"]) {
        const t = TEXT[lang];
        const when = new Intl.DateTimeFormat(lang === "de" ? "de-DE" : "en-GB", {
          weekday: "short", day: "numeric", month: "short",
          hour: "2-digit", minute: "2-digit", timeZone: TIME_ZONE,
        }).format(start);
        const name = (s.title && s.title.trim()) || t[s.type] || t.training;
        const body = [when, s.location].filter(Boolean).join(" · ");
        try {
          await getMessaging().send({
            topic: `team_${teamId}_${lang}`,
            notification: {title: `${t[kind]}: ${name}`, body},
            data: {teamId, sessionId, kind},
            android: {priority: "high", notification: {sound: "default"}},
            apns: {payload: {aps: {sound: "default"}}},
          });
        } catch (e) {
          logger.error("FCM send failed", e);
        }
      }
    });

const REMIND = {
  en: {title: "Are you coming? 🐉", body: (when) => `Training ${when} – please answer 👍 / 👎 / ❓ in the app.`},
  de: {title: "Kommst du? 🐉", body: (when) => `Training ${when} – bitte in der App mit 👍 / 👎 / ❓ antworten.`},
};

exports.trainingReminder = onSchedule(
    {schedule: "every 10 minutes", timeZone: TIME_ZONE},
    async () => {
      const db = getFirestore();
      const now = Date.now();
      const snap = await db.collectionGroup("sessions")
          .where("start", ">", Timestamp.fromMillis(now + 2 * 3600e3))
          .where("start", "<=", Timestamp.fromMillis(now + 3 * 3600e3))
          .get();

      for (const doc of snap.docs) {
        const s = doc.data();
        if (s.type !== "training" || s.reminderSent === true) continue;
        const teamRef = doc.ref.parent.parent;
        const team = (await teamRef.get()).data();
        if (!team) continue;

        const rsvps = await doc.ref.collection("rsvps").get();
        const answered = new Set(rsvps.docs.filter((d) => d.data().status).map((d) => d.id));
        const missing = (team.memberIds || []).filter((u) => !answered.has(u));

        const byLang = {en: [], de: []};
        const owner = {}; // token -> uid (to clean up invalid tokens)
        if (missing.length) {
          const users = await db.getAll(...missing.map((u) => db.doc(`users/${u}`)));
          for (const u of users) {
            if (!u.exists) continue;
            const d = u.data();
            const lang = d.lang === "de" ? "de" : "en";
            for (const t of d.fcmTokens || []) {
              byLang[lang].push(t);
              owner[t] = u.id;
            }
          }
        }

        const start = s.start.toDate();
        for (const lang of ["en", "de"]) {
          const tokens = byLang[lang];
          const when = new Intl.DateTimeFormat(lang === "de" ? "de-DE" : "en-GB", {
            weekday: "short", hour: "2-digit", minute: "2-digit", timeZone: TIME_ZONE,
          }).format(start);
          for (let i = 0; i < tokens.length; i += 500) {
            const chunk = tokens.slice(i, i + 500);
            try {
              const res = await getMessaging().sendEachForMulticast({
                tokens: chunk,
                notification: {title: REMIND[lang].title, body: REMIND[lang].body(when)},
                data: {teamId: teamRef.id, sessionId: doc.id, kind: "reminder"},
                android: {priority: "high", notification: {sound: "default"}},
                apns: {payload: {aps: {sound: "default"}}},
              });
              // remove tokens of uninstalled apps
              await Promise.all(res.responses.map((r, k) => {
                const code = r.error && r.error.code;
                if (code === "messaging/registration-token-not-registered" ||
                    code === "messaging/invalid-registration-token") {
                  const t = chunk[k];
                  return db.doc(`users/${owner[t]}`)
                      .update({fcmTokens: FieldValue.arrayRemove(t)}).catch(() => {});
                }
                return null;
              }));
            } catch (e) {
              logger.error("Reminder send failed", e);
            }
          }
        }
        await doc.ref.update({reminderSent: true});
      }
    });

exports.cleanupDeletedTeam = onDocumentDeleted("teams/{teamId}", async (event) => {
  const db = getFirestore();
  const {teamId} = event.params;
  const data = event.data ? event.data.data() : {};
  const ref = db.doc(`teams/${teamId}`);
  await db.recursiveDelete(ref); // sessions, attendance, runs, members
  if (data.code) await db.doc(`codes/${data.code}`).delete().catch(() => {});
  const batch = db.batch();
  for (const uid of data.memberIds || []) {
    batch.set(db.doc(`users/${uid}`), {teamIds: FieldValue.arrayRemove(teamId)}, {merge: true});
  }
  await batch.commit();
  try {
    await getStorage().bucket().deleteFiles({prefix: `teams/${teamId}/`});
  } catch (e) {
    logger.warn("Storage cleanup", e);
  }
});

exports.sendFeedback = onDocumentCreated(
    {document: "feedback/{id}", secrets: [GMAIL_USER, GMAIL_APP_PASSWORD]},
    async (event) => {
      const d = event.data.data();
      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {user: GMAIL_USER.value(), pass: GMAIL_APP_PASSWORD.value()},
      });
      const from = [d.name, d.email, d.phone].filter(Boolean).join(" · ");
      await transporter.sendMail({
        from: `"Dragon Boat Runner" <${GMAIL_USER.value()}>`,
        to: FEEDBACK_TO,
        replyTo: d.email || undefined,
        subject: `Dragon Boat Runner – Feedback von/from ${d.name || "User"}`,
        text: `${d.text}\n\n---\n${from}\nLanguage: ${d.lang || "-"}\nUser ID: ${d.uid}`,
      });
      await event.data.ref.update({sentAt: FieldValue.serverTimestamp()});
    });
