<<<<<<< HEAD
//
//  SceneDelegate.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

//
//  SceneDelegate.swift
//  InstagramCopy
//
//  Created by Stephen Dowless on 2/5/20.
//  Copyright © 2020 Stephan Dowless. All rights reserved.
//

=======
>>>>>>> 72ea93f (push notification ok)
import Foundation
import SwiftUI
import Firebase
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate, MessagingDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabVC() // Assicurati che MainTabVC sia configurato
        self.window = window
        window.makeKeyAndVisible()
        
        // Configura Firebase Messaging Delegate
        Messaging.messaging().delegate = self
<<<<<<< HEAD
        


=======
        print("DEBUG: Firebase Messaging Delegate configurato")
        
>>>>>>> 72ea93f (push notification ok)
        // Richiedi il permesso per le notifiche push
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Errore nella richiesta di autorizzazione: \(error.localizedDescription)")
<<<<<<< HEAD
=======
            } else {
                print("DEBUG: Permessi notifiche concessi: \(granted)")
>>>>>>> 72ea93f (push notification ok)
            }
        }

        // Registra per le notifiche remote
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
<<<<<<< HEAD
        // Called as the scene is being released by the system.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
=======
        // Chiamato quando la scena viene rilasciata dal sistema.
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Riprendi attività se necessario.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Pausa attività in caso di interruzione.
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Esegui eventuali preparazioni prima che l'app torni in primo piano.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Salva dati o stato quando l'app entra in background.
>>>>>>> 72ea93f (push notification ok)
    }
    
    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
<<<<<<< HEAD
        guard let fcmToken = fcmToken else { return }
        print("FCM token ricevuto: \(fcmToken)")

        // Puoi anche inviare il token al tuo server, se necessario
        // sendFCMTokenToServer(fcmToken)
    }

  /*  func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
        print("Messaggio ricevuto: \(remoteMessage.appData)")
    }*/
=======
        print("DEBUG: Metodo messaging(_:didReceiveRegistrationToken:) chiamato")
        guard let fcmToken = fcmToken else {
            print("DEBUG: Il token FCM è nil")
            return
        }
        print("DEBUG: FCM token ricevuto: \(fcmToken)")
    }
>>>>>>> 72ea93f (push notification ok)
}

// Estensione per gestire le notifiche push
extension SceneDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
<<<<<<< HEAD
=======
        print("DEBUG: Notifica ricevuta in foreground: \(notification.request.content.userInfo)")
>>>>>>> 72ea93f (push notification ok)
        completionHandler([.alert, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
<<<<<<< HEAD
        print("Notifica ricevuta con risposta: \(response.notification.request.content.userInfo)")
=======
        print("DEBUG: Notifica ricevuta con risposta: \(response.notification.request.content.userInfo)")
>>>>>>> 72ea93f (push notification ok)
        completionHandler()
    }
}
