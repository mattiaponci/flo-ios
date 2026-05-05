//
//  PushNotificationService.swift
//  Flotip
//
//  Wrapper attorno a FirebaseMessaging + UNUserNotificationCenter per gestire
//  le push notification dell'app (in particolare le richieste di follow).
//
//  Architettura: l'AppDelegate conferma UNUserNotificationCenterDelegate e
//  MessagingDelegate ma delega tutta la logica reale a `PushNotificationService.shared`.
//
//  Tutti i riferimenti a FirebaseMessaging sono gated dietro
//  `#if canImport(FirebaseMessaging)` perché il pod non è (ancora) presente
//  nel Podfile. Aggiungere `pod 'Firebase/Messaging'` e fare `pod install`
//  attiva automaticamente questo codice senza altre modifiche.
//
//  Persistenza token:
//    users/{uid}/fcmTokens/{token}
//      { token: String, platform: "ios", createdAt: Timestamp,
//        updatedAt: Timestamp }
//
//  Il document ID è il token stesso così:
//    - lo stesso device che si re-installa l'app sovrascrive il proprio doc
//      (idempotenza nativa)
//    - la Cloud Function può iterare la subcollection per fare multicast
//      verso tutti i device dell'utente.
//

import Foundation
import os.log
import UIKit
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging

private let pushLog = OSLog(subsystem: "com.mattiaponcini.project", category: "PushService")

final class PushNotificationService: NSObject {

    static let shared = PushNotificationService()
    private override init() { super.init() }

    private lazy var db = Firestore.firestore()

    /// Auth state listener: quando un utente fa login (o si riavvia l'app
    /// con utente già loggato) salviamo il suo FCM token in Firestore.
    /// Quando fa logout, NON cancelliamo il doc — il token può ancora servire
    /// se l'utente rifa login sullo stesso device, e cancellare richiederebbe
    /// permessi che potrebbero essere persi al signOut.
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    /// Cache dell'ultimo token ricevuto da Firebase. Lo persistiamo finché
    /// `currentUser` esiste; se l'utente è nil al momento della ricezione,
    /// lo salviamo non appena un utente fa login.
    private var lastKnownToken: String?

    // MARK: - Bootstrap (chiamato da AppDelegate.didFinishLaunching)

    /// Setup completo:
    ///  1. Imposta UNUserNotificationCenter delegate (passato dall'AppDelegate)
    ///  2. Imposta Messaging delegate (se il pod è installato)
    ///  3. Avvia il listener auth per persistere il token quando l'utente è loggato
    func bootstrap(unDelegate: UNUserNotificationCenterDelegate) {
        UNUserNotificationCenter.current().delegate = unDelegate

        Messaging.messaging().delegate = self

        // Listener auth: salviamo il token quando l'utente cambia.
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if user != nil, let token = self.lastKnownToken {
                self.persistTokenIfPossible(token)
            }
        }
    }

    // MARK: - Permessi

    /// Richiede il permesso a inviare notifiche locali/remote.
    /// Idempotente: se l'utente ha già negato/accettato, iOS non ripropone
    /// il prompt. Va chiamata dopo il login (es. dal SceneDelegate quando
    /// `updateRootViewController` riceve un user non-nil) oppure dal primo
    /// VC visibile dopo l'autenticazione.
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error = error {
                        os_log("requestAuthorization error: %{public}@",
                               log: pushLog, type: .error, error.localizedDescription)
                    }
                    os_log("requestAuthorization granted=%{public}d",
                           log: pushLog, type: .info, granted ? 1 : 0)
                    if granted {
                        DispatchQueue.main.async {
                            UIApplication.shared.registerForRemoteNotifications()
                        }
                    }
                }
            case .authorized, .provisional, .ephemeral:
                // Già autorizzato in passato: assicuriamo che l'app sia
                // registrata per le remote notifications (necessario dopo
                // ogni cold start, anche se il permesso è già concesso).
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                os_log("notifications denied by user", log: pushLog, type: .info)
            @unknown default:
                break
            }
        }
    }

    // MARK: - APNs ↔ FCM bridge

    /// L'AppDelegate riceve il token APNs e ce lo passa qui: lo inoltriamo
    /// a Firebase Messaging per ottenere il token FCM corrispondente.
    func setAPNsToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - Persist token

    /// Salva un token FCM in `users/{uid}/fcmTokens/{token}`. Idempotente:
    /// `setData(merge: true)` aggiorna `updatedAt` se il doc esiste già.
    /// Se l'utente non è loggato, il token resta in cache (`lastKnownToken`)
    /// e verrà persistito al prossimo cambio di stato auth.
    func persistTokenIfPossible(_ token: String) {
        lastKnownToken = token
        guard let uid = Auth.auth().currentUser?.uid, !uid.isEmpty else {
            os_log("token cached, no user logged in yet", log: pushLog, type: .debug)
            return
        }
        let ref = db.collection("users").document(uid)
            .collection("fcmTokens").document(token)
        let data: [String: Any] = [
            "token": token,
            "platform": "ios",
            "updatedAt": FieldValue.serverTimestamp(),
            // createdAt inserito solo alla prima creazione: setData con merge
            // mantiene il valore esistente; serve un campo separato.
            "createdAt": FieldValue.serverTimestamp()
        ]
        ref.setData(data, merge: true) { error in
            if let error = error {
                os_log("persist token failed: %{public}@",
                       log: pushLog, type: .error, error.localizedDescription)
            } else {
                os_log("token persisted for uid=%{public}@",
                       log: pushLog, type: .info, uid)
            }
        }
    }
}

// MARK: - MessagingDelegate

extension PushNotificationService: MessagingDelegate {
    /// Chiamato da Firebase ogni volta che il token FCM viene aggiornato:
    /// al primo bootstrap, dopo refresh server-side, dopo cambio Apple ID, etc.
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else { return }
        os_log("FCM token received (len=%{public}d)",
               log: pushLog, type: .info, token.count)
        persistTokenIfPossible(token)
    }
}
