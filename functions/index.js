// functions/index.js
//
// Deploy with:  firebase deploy --only functions
//
// Requires:
//   - Firebase project on the Blaze (pay-as-you-go) plan (needed for
//     Realtime Database triggers and scheduled functions)
//   - Realtime Database rules that allow the ESP32 to write to /door_logs
//     (Firestore rules do not apply to the Realtime Database — see note
//     at the bottom of this file)

const { onValueCreated } = require("firebase-functions/v2/database");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const DEFAULT_EXPIRY_ALERT_DAYS = 7;

function requireAuth(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in is required.");
  return request.auth.uid;
}

function requirePermission(permission) {
  if (!["view", "edit", "admin"].includes(permission)) {
    throw new HttpsError("invalid-argument", "Invalid cabinet permission.");
  }
}

async function addCabinetMember(cabinetId, ownerId, memberId, permission) {
  const ref = db.collection("cabinets").doc(cabinetId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Cabinet not found.");
    const cabinet = snapshot.data();
    if (cabinet.userId !== ownerId) throw new HttpsError("permission-denied", "Only the owner can share this cabinet.");
    transaction.update(ref, {
      sharedWith: FieldValue.arrayUnion([memberId]),
      [`permissions.${memberId}`]: permission,
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

exports.shareCabinetByEmail = onCall({ region: "us-central1" }, async (request) => {
  const ownerId = requireAuth(request);
  const { cabinetId, email, permission = "view" } = request.data || {};
  if (typeof cabinetId !== "string" || typeof email !== "string") {
    throw new HttpsError("invalid-argument", "Cabinet ID and email are required.");
  }
  requirePermission(permission);
  const users = await db.collection("users").where("email", "==", email.trim().toLowerCase()).limit(1).get();
  if (users.empty) throw new HttpsError("not-found", "No account exists for this email address.");
  const memberId = users.docs[0].id;
  if (memberId === ownerId) throw new HttpsError("failed-precondition", "You cannot share with yourself.");
  await addCabinetMember(cabinetId, ownerId, memberId, permission);
  await sendPushAndLog(memberId, "📂 Cabinet Shared", "A cabinet was shared with you.", { type: "share", cabinetId });
  return { memberId };
});

exports.createCabinetInvite = onCall({ region: "us-central1" }, async (request) => {
  const ownerId = requireAuth(request);
  const { cabinetId, permission = "view" } = request.data || {};
  if (typeof cabinetId !== "string") throw new HttpsError("invalid-argument", "Cabinet ID is required.");
  requirePermission(permission);
  const cabinet = await db.collection("cabinets").doc(cabinetId).get();
  if (!cabinet.exists || cabinet.data().userId !== ownerId) throw new HttpsError("permission-denied", "Only the owner can create an invite.");
  const invite = db.collection("cabinet_invites").doc();
  await invite.set({ cabinetId, ownerId, permission, createdAt: FieldValue.serverTimestamp(), expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000), acceptedBy: null });
  return { inviteId: invite.id, link: `smartcabinet://join?invite=${invite.id}` };
});

exports.acceptCabinetInvite = onCall({ region: "us-central1" }, async (request) => {
  const memberId = requireAuth(request);
  const { inviteId } = request.data || {};
  if (typeof inviteId !== "string") throw new HttpsError("invalid-argument", "Invite code is required.");
  const inviteRef = db.collection("cabinet_invites").doc(inviteId);
  await db.runTransaction(async (transaction) => {
    const inviteSnap = await transaction.get(inviteRef);
    if (!inviteSnap.exists) throw new HttpsError("not-found", "Invite not found.");
    const invite = inviteSnap.data();
    if (invite.acceptedBy) throw new HttpsError("failed-precondition", "This invite was already used.");
    if (invite.expiresAt.toMillis() < Date.now()) throw new HttpsError("deadline-exceeded", "This invite has expired.");
    if (invite.ownerId === memberId) throw new HttpsError("failed-precondition", "You already own this cabinet.");
    const cabinetRef = db.collection("cabinets").doc(invite.cabinetId);
    const cabinetSnap = await transaction.get(cabinetRef);
    if (!cabinetSnap.exists || cabinetSnap.data().userId !== invite.ownerId) throw new HttpsError("not-found", "Cabinet is unavailable.");
    transaction.update(cabinetRef, { sharedWith: FieldValue.arrayUnion([memberId]), [`permissions.${memberId}`]: invite.permission, updatedAt: FieldValue.serverTimestamp() });
    transaction.update(inviteRef, { acceptedBy: memberId, acceptedAt: FieldValue.serverTimestamp() });
  });
  return { success: true };
});

// Short mobile recordings are transcribed by Azure Speech so users do not need
// an on-device Chinese or Malay recognition pack. Set AZURE_SPEECH_KEY and
// AZURE_SPEECH_REGION in functions/.env before deploying.
exports.transcribeVoice = onCall(
  { region: "asia-southeast1", timeoutSeconds: 60, memory: "512MiB" },
  async (request) => {
    requireAuth(request);
    const { audioBase64, languageCode = "en" } = request.data || {};
    if (typeof audioBase64 !== "string" || audioBase64.length === 0) {
      throw new HttpsError("invalid-argument", "Audio is required.");
    }
    // Callable requests have size limits; keep clips short and reject large data.
    if (audioBase64.length > 8 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "Voice recording is too large. Keep it under 30 seconds.");
    }
    const key = process.env.AZURE_SPEECH_KEY;
    const region = process.env.AZURE_SPEECH_REGION;
    if (!key || !region) {
      throw new HttpsError("failed-precondition", "Azure Speech is not configured on the server.");
    }
    const localeByLanguage = { en: "en-US", zh: "zh-CN", ms: "ms-MY" };
    const locale = localeByLanguage[languageCode] || "en-US";
    const endpoint = `https://${region}.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=${encodeURIComponent(locale)}&format=detailed`;
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Ocp-Apim-Subscription-Key": key,
        "Content-Type": "audio/wav; codecs=audio/pcm; samplerate=16000",
        Accept: "application/json",
      },
      body: Buffer.from(audioBase64, "base64"),
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error("Azure Speech failed:", response.status, result);
      throw new HttpsError("internal", "Azure Speech could not transcribe this recording.");
    }
    return { transcript: (result.DisplayText || "").trim() };
  }
);

// ═══════════════════════════════════════════════════════
// Shared helper: write a Firestore notification doc AND
// send a push notification via FCM to the user's device.
// ═══════════════════════════════════════════════════════
async function sendPushAndLog(userId, title, body, extraData = {}) {
  if (!userId) return;

  // 1) Save to Firestore so the in-app Notifications screen shows it
  await db.collection("notifications").add({
    userId,
    title,
    body,
    type: extraData.type || "general",
    itemId: extraData.itemId || null,
    doorId: extraData.doorId || null,
    doorStatus: extraData.doorStatus || null,
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });

  // 2) Look up this user's saved FCM token and push to their phone
  const tokenDoc = await db.collection("fcm_tokens").doc(userId).get();
  const token = tokenDoc.exists ? tokenDoc.data().token : null;
  if (!token) {
    console.log(`No FCM token on file for user ${userId}, skipping push.`);
    return;
  }

  const dataPayload = {};
  for (const [k, v] of Object.entries({ userId, ...extraData })) {
    if (v !== null && v !== undefined) dataPayload[k] = String(v);
  }

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: dataPayload,
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    });
  } catch (e) {
    console.error(`FCM send failed for user ${userId}:`, e.message);
    // Clean up dead tokens so we don't keep failing on them
    if (e.code === "messaging/registration-token-not-registered") {
      await db.collection("fcm_tokens").doc(userId).delete().catch(() => {});
    }
  }
}

// ═══════════════════════════════════════════════════════
// 1) DOOR OPEN → PUSH NOTIFICATION
// Triggers on every new entry written to /door_logs by the ESP32.
// ═══════════════════════════════════════════════════════
exports.onDoorEvent = onValueCreated(
  {
    ref: "/door_logs/{logId}",
    // Match the Realtime Database instance used by your ESP32 firmware
    instance: "smart-cabinet-test-7-default-rtdb",
    region: "us-central1",
  },
  async (event) => {
    const log = event.data.val();
    if (!log || !log.userId || !log.event) return;

    // Only alert on door-open events (skip locked/unlocked/closed noise)
    if (!log.event.includes("opened")) return;

    const isUpper = log.event.includes("upper");
    const doorLabel = isUpper ? "Upper Door" : "Lower Door";

    await sendPushAndLog(
      log.userId,
      `🚪 ${doorLabel} Opened`,
      `${log.deviceId || "Your cabinet"}'s ${doorLabel.toLowerCase()} was just opened.`,
      {
        type: `door_${isUpper ? "upper" : "lower"}_opened`,
        doorId: isUpper ? "upper" : "lower",
        doorStatus: "opened",
      }
    );
  }
);

// ═══════════════════════════════════════════════════════
// 2) DAILY EXPIRY / LOW-STOCK CHECK
// Runs once a day for every user, using each user's own
// configurable alert threshold (users/{uid}.expiryAlertDays,
// defaults to 7 if the user hasn't set one).
// Keeps firing every day until the item is fixed (restocked,
// expiry date changed, or item removed).
// ═══════════════════════════════════════════════════════
exports.dailyItemAlerts = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "Asia/Kuala_Lumpur",
  },
  async () => {
    const usersSnap = await db.collection("users").get();
    const now = new Date();

    for (const userDoc of usersSnap.docs) {
      const userId = userDoc.id;
      const alertDays = userDoc.data().expiryAlertDays ?? DEFAULT_EXPIRY_ALERT_DAYS;

      const itemsSnap = await db
        .collection("items")
        .where("userId", "==", userId)
        .get();

      for (const itemDoc of itemsSnap.docs) {
        const item = itemDoc.data();
        const itemId = itemDoc.id;

        // ── Expiry check ──────────────────────────────
        if (item.expiryDate instanceof Timestamp) {
          const expiry = item.expiryDate.toDate();
          const daysLeft = Math.ceil((expiry - now) / 86400000);

          if (daysLeft < 0) {
            await sendPushAndLog(
              userId,
              `🚫 ${item.name} has expired`,
              `Expired on ${expiry.toLocaleDateString()}. Please remove or discard it.`,
              { type: "expiry", itemId }
            );
          } else if (daysLeft <= alertDays) {
            await sendPushAndLog(
              userId,
              `⏰ ${item.name} expiring soon`,
              `${daysLeft} day(s) left — expires ${expiry.toLocaleDateString()}.`,
              { type: "expiry", itemId }
            );
          }
        }

        // ── Stock check ────────────────────────────────
        const qty = item.quantity ?? 0;
        const lowThreshold = item.lowStockThreshold ?? 0;

        if (qty === 0) {
          await sendPushAndLog(
            userId,
            `📭 ${item.name} out of stock`,
            `Time to restock ${item.name}.`,
            { type: "low_stock", itemId }
          );
        } else if (qty <= lowThreshold) {
          await sendPushAndLog(
            userId,
            `📉 ${item.name} low stock`,
            `Only ${qty} ${item.unit || ""} left.`,
            { type: "low_stock", itemId }
          );
        }
      }
    }
  }
);

// ═══════════════════════════════════════════════════════
// NOTE on Realtime Database rules
// ═══════════════════════════════════════════════════════
// The Firestore rules you shared define /door_logs and /iot_devices
// paths, but your ESP32 firmware actually writes to the *Realtime
// Database* (FIREBASE_DB_URL), which is governed by SEPARATE rules
// (usually in database.rules.json), not the firestore.rules file.
// Make sure your Realtime Database rules allow the ESP32's request
// (it authenticates via ?auth=<API_KEY>, which is a legacy method —
// consider migrating to a Firebase Auth ID token or at least locking
// the rule to the specific structure/fields you expect), e.g.:
//
// {
//   "rules": {
//     "door_logs": {
//       ".read": false,
//       ".write": true,
//       ".indexOn": ["userId"]
//     },
//     "iot_devices": {
//       ".read": false,
//       ".write": true
//     }
//   }
// }
//
// This Cloud Function uses the Admin SDK, which always bypasses
// security rules, so it will work regardless — this note is only
// about whether the ESP32 itself is allowed to write.
