//
//  AppDelegate.swift
//  com.mattiaponcini.project
//
//  Created by mattia poncini on 29.04.2026.
//
//  Bootstrap di Firebase + setup delle push notification.
//  La logica reale delle push (token persist, permessi) vive in
//  `PushNotificationService`. Qui ci limitiamo a:
//    - inizializzare FirebaseApp
//    - settare i delegate (UNUserNotificationCenter, Messaging via service)
//    - inoltrare i callback APNs al service
//

import UIKit
import os.log
import FirebaseCore
import UserNotifications

private let appDelegateLog = OSLog(subsystem: "com.mattiaponcini.project", category: "AppDelegate")

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()

        // Push notifications: il service prende il delegate del notification
        // center e (se il pod FirebaseMessaging è installato) il MessagingDelegate.
        // La richiesta di permesso viene fatta da SceneDelegate quando
        // l'utente è loggato, NON qui — vogliamo evitare il prompt iOS sullo
        // splash screen prima ancora che l'utente abbia visto cosa fa l'app.
        PushNotificationService.shared.bootstrap(unDelegate: self)

        return true
    }

    // MARK: - Remote notifications (APNs)

    /// Apple Push Notification service ci consegna il device token.
    /// Lo inoltriamo a `PushNotificationService` che lo passa a Firebase
    /// Messaging — quest'ultimo a sua volta restituirà il token FCM via
    /// `MessagingDelegate.didReceiveRegistrationToken`.
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        os_log("APNs token received len=%{public}d",
               log: appDelegateLog, type: .info, hex.count)
        PushNotificationService.shared.setAPNsToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // In simulator la registrazione APNs fallisce sempre (non c'è APNs):
        // questo log è informativo, non un errore reale.
        os_log("APNs registration failed: %{public}@",
               log: appDelegateLog, type: .info, error.localizedDescription)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration",
                                    sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication,
                     didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Notifica ricevuta mentre l'app è in foreground. Permettiamo a iOS di
    /// mostrarla comunque (banner + sound + badge) così l'utente vede la
    /// richiesta di follow anche se sta usando l'app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .badge, .sound, .list])
    }

    /// L'utente ha tappato sulla notifica. Inspect del payload `data`:
    ///   - `type == "followRequest"` → deep-link alla Libreria, dove la
    ///     sezione "Notifiche" (FollowRequestsRowView) mostra in cima la
    ///     richiesta. Ogni altro tipo di notifica futura sarà gestito qui.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler:
                                @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        os_log("notification tapped: %{public}@",
               log: appDelegateLog, type: .info,
               String(describing: userInfo))

        // Dispatch sul main thread: tutte le manipolazioni di UIWindow / VC
        // hierarchy devono essere main-thread.
        DispatchQueue.main.async { [weak self] in
            self?.routeNotification(userInfo: userInfo)
            completionHandler()
        }
    }

    /// Routes a notification payload all'esperienza giusta dentro l'app.
    /// Per ora gestisce solo `type == "followRequest"`: porta l'utente
    /// direttamente sulla schermata Notifiche dentro il LibraryHostViewController.
    private func routeNotification(userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        // Recupera la root window della scene attiva (o qualsiasi scene connessa
        // nel caso l'app fosse in background e la scene sia ancora .unattached).
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first

        guard let window = scene?.windows.first(where: { $0.isKeyWindow })
                        ?? scene?.windows.first,
              let rootVC = window.rootViewController else {
            os_log("routeNotification: no rootViewController found",
                   log: appDelegateLog, type: .error)
            return
        }

        switch type {
        case "followRequest":
            presentNotifications(from: rootVC, in: window)
        default:
            os_log("routeNotification: unknown type=%{public}@",
                   log: appDelegateLog, type: .info, type)
        }
    }

    /// Apre `LibraryHostViewController` sul tab Notifiche, partendo da qualsiasi
    /// VC nella gerarchia. Casi gestiti:
    ///   - LibraryHostViewController già visibile → switcha al tab Notifiche senza
    ///     ri-presentare nulla.
    ///   - MainTabBarController visibile → presenta LibraryHostViewController sopra.
    ///   - Login/altro → non facciamo nulla (utente non autenticato).
    private func presentNotifications(from rootVC: UIViewController, in window: UIWindow) {
        // Trovare la VC più in alto nella gerarchia presentata.
        var top: UIViewController = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }

        // Caso 1: LibraryHostViewController già visibile → switcha sul tab Notifiche.
        if let host = top as? LibraryHostViewController {
            host.switchToNotificationsTab()
            return
        }

        // Caso 2: l'utente non è autenticato (login in cima) → ignora.
        guard rootVC is MainTabBarController else {
            os_log("routeNotification: user not authenticated, skipping",
                   log: appDelegateLog, type: .info)
            return
        }

        // Caso 3: presentiamo il container sul tab Notifiche.
        let vc = LibraryHostViewController(initialTab: .notifications)
        vc.modalPresentationStyle = .fullScreen
        let transition = CATransition()
        transition.duration = 0.35
        transition.type = .push
        transition.subtype = .fromRight
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        window.layer.add(transition, forKey: kCATransition)
        top.present(vc, animated: false)
    }
}
