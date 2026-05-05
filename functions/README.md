# Flotip Cloud Functions

Trigger Firestore che invia push notification quando arriva una richiesta
di follow.

## Setup iniziale

```bash
# 1. Da repository root, se non l'hai mai fatto:
firebase login
firebase init functions   # rispondi: usa la cartella esistente "functions"

# 2. Installa dipendenze
cd functions
npm install

# 3. Deploy
firebase deploy --only functions
```

## Trigger esposti

### `notifyFollowRequest`

- **Sorgente**: `users/{recipientUid}/followRequests/{requesterUid}` `onCreate`
- **Effetto**: invia push FCM a tutti i token in
  `users/{recipientUid}/fcmTokens` con titolo
  `"Nuova richiesta di follow"` e body `"<Nome> vuole seguirti"`.
- **Cleanup**: rimuove dalla subcollection i token rifiutati dal server APNs
  (utile per device disinstallati).

## Requisiti

- **Piano Blaze** (le Cloud Functions non sono incluse nel piano Spark gratuito).
- **APNs Auth Key** caricata in
  Firebase Console → Project Settings → Cloud Messaging → Apple app configuration.
- **Push Notifications capability** abilitata sul target Xcode dell'app.
