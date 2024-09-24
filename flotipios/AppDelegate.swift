import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Crea la finestra principale
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Imposta il view controller iniziale
        let loginVC = LoginVC()
        let navController = UINavigationController(rootViewController: loginVC)

        window?.rootViewController = navController
        
        // Rendi la finestra visibile
        window?.makeKeyAndVisible()
        
        return true
    }
}
