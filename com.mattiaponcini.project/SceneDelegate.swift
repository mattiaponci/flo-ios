//
//  SceneDelegate.swift
//  com.mattiaponcini.project
//
//  Decide il root view controller in base allo stato di Firebase Auth.
//

import UIKit
import FirebaseCore
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    /// Handle del listener Firebase Auth — ricevuto al login/logout.
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    /// True finché lo splash è visibile. Mentre è true, gli aggiornamenti
    /// del listener auth vengono memorizzati ma non applicati al root —
    /// vengono eseguiti tutti insieme quando lo splash termina.
    private var splashActive = true
    private var pendingUser: FirebaseAuth.User??

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        // Forza light mode in tutta l'app (sfondo bianco, testi neri).
        window.overrideUserInterfaceStyle = .light
        self.window = window

        // Safety net: se per qualche ragione FirebaseApp non è ancora configurato
        // (es. cambia ordine di init), lo configuriamo qui — è idempotente.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Splash programmatico con il logo Flotip animato
        let splash = SplashViewController()
        splash.onFinish = { [weak self] in
            self?.splashFinished()
        }
        window.rootViewController = splash
        window.makeKeyAndVisible()

        startAuthListener()
    }

    /// Chiamato dallo splash quando finisce l'animazione di entrata.
    private func splashFinished() {
        splashActive = false
        // Se il listener auth ha già scattato, applica adesso quello stato.
        if let user = pendingUser {
            pendingUser = nil
            updateRootViewController(for: user)
        }
    }

    // MARK: - Auth State Listener

    private func startAuthListener() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Se lo splash è ancora visibile, accumula l'ultimo stato e
                // applicalo solo dopo che lo splash è terminato.
                if self.splashActive {
                    self.pendingUser = user
                } else {
                    self.updateRootViewController(for: user)
                }
            }
        }
    }

    private func updateRootViewController(for user: FirebaseAuth.User?) {
        guard let window = window else { return }

        if let uid = user?.uid {
            // Avvia il listener Firestore del feed: filtra "only following"
            // — vedi PostService.startObservingFeed(for:) per il dettaglio
            // del chunking e del merge real-time.
            PostService.shared.startObservingFeed(for: uid)

            // Push notifications: richiediamo il permesso (idempotente: se
            // l'utente ha già risposto in passato, iOS non mostra di nuovo
            // il prompt) e ci registriamo per le remote notifications così
            // FCM può recuperare il token APNs dal device.
            PushNotificationService.shared.requestAuthorizationIfNeeded()

            if window.rootViewController is MainTabBarController { return }
            transition(to: MainTabBarController())
        } else {
            // Stop al listener su logout
            PostService.shared.stopObservingFeed()
            AppStore.shared.setPosts([])

            if let nav = window.rootViewController as? UINavigationController,
               nav.viewControllers.first is LoginViewController {
                nav.popToRootViewController(animated: false)
                return
            }
            transition(to: makeLoginRoot())
        }
    }

    private func transition(to newRoot: UIViewController) {
        guard let window = window else { return }
        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: { window.rootViewController = newRoot },
                          completion: nil)
    }

    private func makeLoginRoot() -> UIViewController {
        return UINavigationController(rootViewController: LoginViewController())
    }

    // MARK: - Lifecycle

    func sceneDidDisconnect(_ scene: UIScene) {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authStateHandle = nil
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}

    /// Riprendiamo i listener Firestore del feed quando l'app torna in
    /// foreground. La pausa avviene in `sceneDidEnterBackground` per
    /// risparmiare reads mentre nessuno guarda lo schermo.
    func sceneWillEnterForeground(_ scene: UIScene) {
        PostService.shared.resumeObservingFeedIfNeeded()
    }

    /// Sospende i listener Firestore del feed quando l'app va in background:
    /// ogni post nuovo dai followed users costerebbe 1 read di snapshot
    /// che l'utente non vede comunque. Vedi
    /// `PostService.pauseObservingFeedForBackground()` per il dettaglio.
    func sceneDidEnterBackground(_ scene: UIScene) {
        PostService.shared.pauseObservingFeedForBackground()
    }
}
