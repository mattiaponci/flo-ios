import UIKit
import Firebase
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        
        // Register for push notifications
        attemptToRegisterForNotifications(application: application)
        
                
        return true
    }
    
    func attemptToRegisterForNotifications(application: UIApplication) {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
            if let error = error {
                print("DEBUG: Failed to request authorization: \(error.localizedDescription)")
            }

            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
                print("DEBUG: SUCCESSFULLY REGISTERED FOR NOTIFICATIONS")
            } else {
                print("DEBUG: User denied notification permissions")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("DEBUG: Registered for notifications with device token: ", deviceToken)
        // Set APNS token for Firebase Messaging
        Messaging.messaging().setAPNSToken(deviceToken, type: .unknown)
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("DEBUG: FCM token is nil")
            return
        }
        print("DEBUG: Registered with FCM Token: ", fcmToken)
        
        // Optionally store the token in User Defaults or update to your server
    }
    
    // Handle messages when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .badge, .sound])
    }

    // Handle messages when the app is in the background or terminated
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("DEBUG: Received remote notification: \(userInfo)")
        completionHandler(.newData)
    }
    
    // MARK: - App Life Cycle
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Pause ongoing tasks or disable user interactions if necessary.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save application state.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Undo changes made when entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart tasks that were paused.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save data if appropriate.
    }
}
