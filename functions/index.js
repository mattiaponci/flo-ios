/**
 * Cloud Functions per Flotip — runtime Node 22, firebase-functions v2.
 *
 * Trigger: notifyFollowRequest
 *   Si attiva quando viene creato il documento
 *     users/{recipientUid}/followRequests/{requesterUid}
 *   e invia una push notification (via FCM) a tutti i token registrati
 *   nella subcollection users/{recipientUid}/fcmTokens.
 *
 *   Payload notifica:
 *     title: "Nuova richiesta di follow"
 *     body:  "[Nome] vuole seguirti"
 *     data:  { type: "followRequest", requesterUid, recipientUid }
 *
 *   I token diventati invalidi (Apple/Google li hanno scaduti, app
 *   disinstallata) vengono rimossi automaticamente dalla subcollection per
 *   evitare di spammare l'API e tenere la lista pulita.
 *
 * Setup (lato sviluppatore):
 *   1. cd functions && npm install
 *   2. firebase deploy --only functions
 *
 * Requisiti runtime:
 *   - Project su Firebase Blaze plan (le Cloud Functions non sono incluse
 *     nel piano Spark gratuito).
 *   - APNs Auth Key configurata in Firebase Console → Project Settings →
 *     Cloud Messaging → Apple app configuration.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Region Europa (più vicino, latency più bassa per utenti italiani).
// Puoi cambiarla con setGlobalOptions({ region: "us-central1" }) se preferisci.
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

exports.notifyFollowRequest = onDocumentCreated(
  "users/{recipientUid}/followRequests/{requesterUid}",
  async (event) => {
    const { recipientUid, requesterUid } = event.params;

    // 1. Resolve nome del requester (per il body della notifica).
    let requesterName = "Qualcuno";
    try {
      const requesterDoc = await db.doc(`users/${requesterUid}`).get();
      const data = requesterDoc.data() || {};
      const first = (data.firstName || "").trim();
      const last = (data.lastName || "").trim();
      const full = `${first} ${last}`.trim();
      if (full.length > 0) {
        requesterName = full;
      } else if (data.email) {
        // Fallback: parte locale dell'email come "handle".
        requesterName = String(data.email).split("@")[0];
      }
    } catch (err) {
      logger.warn(
        `notifyFollowRequest: failed to load requester profile uid=${requesterUid}`,
        err
      );
    }

    // 2. Carica i token FCM del recipient.
    let tokensSnap;
    try {
      tokensSnap = await db
        .collection(`users/${recipientUid}/fcmTokens`)
        .get();
    } catch (err) {
      logger.error(
        `notifyFollowRequest: failed to load fcmTokens for uid=${recipientUid}`,
        err
      );
      return null;
    }

    if (tokensSnap.empty) {
      logger.log(
        `notifyFollowRequest: no FCM tokens for recipient uid=${recipientUid}, skipping push`
      );
      return null;
    }

    const tokens = tokensSnap.docs.map((d) => d.id);

    // 3. Multicast.
    const message = {
      tokens,
      notification: {
        title: "Nuova richiesta di follow",
        body: `${requesterName} vuole seguirti`,
      },
      data: {
        type: "followRequest",
        requesterUid: String(requesterUid),
        recipientUid: String(recipientUid),
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    let response;
    try {
      response = await admin.messaging().sendEachForMulticast(message);
    } catch (err) {
      logger.error("notifyFollowRequest: sendEachForMulticast failed", err);
      return null;
    }

    logger.log(
      `notifyFollowRequest: sent=${response.successCount} failed=${response.failureCount}`
    );

    // 4. Pulizia: rimuovi i token che il server ha rifiutato perché invalidi.
    const tokensToRemove = [];
    response.responses.forEach((resp, idx) => {
      if (resp.success) return;
      const code = resp.error && resp.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(tokens[idx]);
      } else {
        logger.warn(
          `notifyFollowRequest: send error for token ${tokens[idx]}: ${code}`
        );
      }
    });
    if (tokensToRemove.length > 0) {
      const batch = db.batch();
      for (const tok of tokensToRemove) {
        batch.delete(db.doc(`users/${recipientUid}/fcmTokens/${tok}`));
      }
      try {
        await batch.commit();
        logger.log(
          `notifyFollowRequest: removed ${tokensToRemove.length} stale token(s)`
        );
      } catch (err) {
        logger.error("notifyFollowRequest: stale token cleanup failed", err);
      }
    }

    return null;
  }
);
