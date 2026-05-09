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

const {
  onDocumentCreated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { setGlobalOptions } = require("firebase-functions/v2");
const { FieldValue } = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const path = require("path");
const os = require("os");
const fs = require("fs");
const sharp = require("sharp");

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

/**
 * Trigger: onLikeCreated / onLikeDeleted
 *   posts/{postId}/likes/{userId}
 *
 * Mantiene `posts/{postId}.likesCount` denormalizzato così il client può
 * fare 1 read per snapshot del post invece di leggere l'intera subcollection
 * `likes` ad ogni apertura. Su un post con 1.000 like questo passa da
 * 1.000 read a 1 read per ogni utente che apre il post.
 *
 * Idempotenza: il client crea/cancella il doc like con set/delete (ID =
 * uid del liker) — un re-tap sullo stesso like non duplica il trigger.
 * Usiamo FieldValue.increment(±1) per essere safe rispetto a race
 * concorrenti fra utenti diversi che mettono like nello stesso momento.
 */
exports.onLikeCreated = onDocumentCreated(
  "posts/{postId}/likes/{userId}",
  async (event) => {
    const { postId } = event.params;
    try {
      await db.doc(`posts/${postId}`).update({
        likesCount: FieldValue.increment(1),
      });
    } catch (err) {
      logger.error(`onLikeCreated: increment failed postId=${postId}`, err);
    }
    return null;
  }
);

exports.onLikeDeleted = onDocumentDeleted(
  "posts/{postId}/likes/{userId}",
  async (event) => {
    const { postId } = event.params;
    try {
      await db.doc(`posts/${postId}`).update({
        likesCount: FieldValue.increment(-1),
      });
    } catch (err) {
      logger.error(`onLikeDeleted: decrement failed postId=${postId}`, err);
    }
    return null;
  }
);

/**
 * Trigger: onPostImageFinalized
 *   Storage object create on `posts/{uid}/{postId}.jpg`
 *
 * Crea una thumbnail 600px (lato lungo) e aggiorna il doc Firestore
 * `posts/{postId}` con il campo `imageURLThumb`. Il client iOS preferisce
 * la thumb nel feed e nei grid profilo (250 KB → ~40 KB), riservando
 * l'originale al fullscreen detail. Risparmio banda Storage stimato:
 * ~75% sui post viewer più comuni.
 *
 * Idempotenza: se il file caricato è GIÀ una thumb (suffisso _thumb),
 * usciamo subito per evitare ricorsione (la thumb generata triggera a
 * sua volta il finalize).
 *
 * Memoria 512 MiB: sharp è lazy ma su immagini grandi (>5 MB) può
 * picchiare oltre i 256 MiB default.
 */
exports.onPostImageFinalized = onObjectFinalized(
  {
    region: "europe-west1",
    memory: "512MiB",
    cpu: 1,
  },
  async (event) => {
    const filePath = event.data.name; // es. posts/abc123/post456.jpg
    const contentType = event.data.contentType || "";
    const bucket = admin.storage().bucket(event.data.bucket);

    // Filtra: solo posts/{uid}/{postId}.jpg, ignora altre cartelle.
    if (!filePath || !filePath.startsWith("posts/")) {
      return null;
    }
    if (!contentType.startsWith("image/")) {
      return null;
    }

    const fileName = path.basename(filePath);
    const baseName = path.parse(fileName).name; // es. "post456"
    const ext = path.parse(fileName).ext;       // es. ".jpg"

    // Stop ricorsione: la thumb è "{base}_thumb.jpg" e ritriggera il
    // finalize. Skip esplicito.
    if (baseName.endsWith("_thumb")) {
      return null;
    }

    // postId == nome file senza estensione (vedi PostService.publish:
    // path = posts/{uid}/{postId}.jpg).
    const postId = baseName;

    const tmpOriginal = path.join(os.tmpdir(), `${baseName}_orig${ext}`);
    const tmpThumb = path.join(os.tmpdir(), `${baseName}_thumb${ext}`);
    const thumbStoragePath = path.join(
      path.dirname(filePath),
      `${baseName}_thumb${ext}`
    );

    try {
      // 1. Download originale.
      await bucket.file(filePath).download({ destination: tmpOriginal });

      // 2. Resize: 1080px lato lungo (copre i display iPhone Pro/Max al
      //    100% in fullscreen senza blur visibile), JPEG quality 70 con
      //    mozjpeg (~25% in meno di byte vs libjpeg a parità di
      //    quality). `withoutEnlargement` evita upscale di immagini più
      //    piccole della soglia. La grid profilo/libreria (celle 120pt)
      //    riceve la stessa thumb e la downscala via UIImageView: ok,
      //    perché URLCache caches una sola copia.
      await sharp(tmpOriginal)
        .resize({ width: 1080, height: 1080, fit: "inside", withoutEnlargement: true })
        .jpeg({ quality: 70, mozjpeg: true })
        .toFile(tmpThumb);

      // 3. Upload thumb su Storage.
      await bucket.upload(tmpThumb, {
        destination: thumbStoragePath,
        metadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000, immutable",
        },
      });

      // 4. Genera URL pubblico (signed URL long-lived). Usiamo il token
      //    di Firebase Storage per consistency con il resto dell'app.
      const [signedUrl] = await bucket.file(thumbStoragePath).getSignedUrl({
        action: "read",
        expires: "01-01-2500",
      });

      // 5. Aggiorna doc Firestore con l'URL della thumb. Il client picka
      //    `imageURLThumb` (se presente) per feed/grid e `imageURL` per
      //    fullscreen.
      await db.doc(`posts/${postId}`).update({
        imageURLThumb: signedUrl,
      });

      logger.log(
        `onPostImageFinalized: thumb generated postId=${postId} path=${thumbStoragePath}`
      );
    } catch (err) {
      logger.error(
        `onPostImageFinalized: failed postId=${postId} path=${filePath}`,
        err
      );
    } finally {
      // Cleanup tmp files (Cloud Functions ha disco effimero ma comunque
      // limitato; meglio lasciare pulito).
      for (const p of [tmpOriginal, tmpThumb]) {
        try {
          if (fs.existsSync(p)) fs.unlinkSync(p);
        } catch (_) {
          /* ignore */
        }
      }
    }

    return null;
  }
);
