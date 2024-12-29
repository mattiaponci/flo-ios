//
//  MainTabVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit
import Firebase

class MainTabVC: UITabBarController, UITabBarControllerDelegate, FeedVCDelegate, UserVCDelegate {
    
    // MARK: - Properties
    
    let dot = UIView()
    var isInitialLoad: Bool?
     private var wasFlagTabPreviouslySelected: Bool = false
      private var isInitialLaunch: Bool = true

    // MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()

        // Delegate
        self.delegate = self
        
        // Configure view controllers
        configureViewControllers()
        
        // Configure notification dot
        // configureNotificationDot()
        
        // Observe notifications
        // observeNotifications()
        
        // User validation
        checkIfUserIsLoggedIn()
        
        self.selectedIndex = 2  // Index of the BrowserViewController

        
        // Forza l'aggiornamento per visualizzare l'immagine selezionata
       if let browserNavController = viewControllers?[2] as? UINavigationController {
            browserNavController.tabBarItem.selectedImage = #imageLiteral(resourceName: "flag").withRenderingMode(.alwaysOriginal)
            tabBar.tintColor = .white }
        view.backgroundColor = UIColor.white

    }
    
    // MARK: - Handlers
    
    func configureViewControllers() {
        let feedVC = FeedVC(collectionViewLayout: UICollectionViewFlowLayout())
        feedVC.delegate = self
        
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.delegate = self
     
        let feedNavController = constructNavController(unselectedImage: #imageLiteral(resourceName: "home_unselected"), selectedImage: #imageLiteral(resourceName: "home_selected"), rootViewController: feedVC)

        let searchVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "search_unselected"), selectedImage: #imageLiteral(resourceName: "comment"), rootViewController: SearchVC())
        
        let browserVC = constructNavController(
                 unselectedImage: #imageLiteral(resourceName: "flag"),
                 selectedImage: #imageLiteral(resourceName: "flag1"),
                 rootViewController: BrowserViewController()
             )


        let notificationVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "profile_unselected"), selectedImage: #imageLiteral(resourceName: "profile_selected"), rootViewController: NotificationsVC())

        let userNavProfileVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "profile_unselected"), selectedImage: #imageLiteral(resourceName: "profile_selected"), rootViewController: userProfileVC)

        viewControllers = [feedNavController, searchVC, browserVC, notificationVC, userNavProfileVC]

        tabBar.tintColor = .white
    }

    func constructNavController(unselectedImage: UIImage, selectedImage: UIImage, rootViewController: UIViewController = UIViewController()) -> UINavigationController {
        // Construct nav controller
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.tabBarItem.image = unselectedImage
        navController.tabBarItem.selectedImage = selectedImage
        navController.navigationBar.tintColor = .red
        return navController
    }
    
    func configureNotificationDot() {
        if UIDevice().userInterfaceIdiom == .phone {
            let tabBarHeight = tabBar.frame.height
            if UIScreen.main.nativeBounds.height == 2436 {
                // Configure dot for iPhone X
                dot.frame = CGRect(x: view.frame.width / 5 * 3, y: view.frame.height - tabBarHeight, width: 6, height: 6)
            } else {
                // Configure dot for other phone models
                dot.frame = CGRect(x: view.frame.width / 5 * 3, y: view.frame.height - 16, width: 6, height: 6)
            }
            // Create dot
            dot.center.x = (view.frame.width / 5 * 3 + (view.frame.width / 5) / 2)
            dot.backgroundColor = UIColor(red: 233/255, green: 30/255, blue: 99/255, alpha: 1)
            dot.layer.cornerRadius = dot.frame.width / 2
            self.view.addSubview(dot)
            dot.isHidden = true
        }
    }
    
    // MARK: - UITabBar
    
   
       
       // MARK: - UITabBarControllerDelegate
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        guard let index = viewControllers?.firstIndex(of: viewController) else { return true }

        // Caso in cui si seleziona un altro tab dopo il lancio
        if selectedIndex != index {
            isInitialLaunch = false
            wasFlagTabPreviouslySelected = false
            return true
        }

        // Gestione del clic su "flag"
        if let browserNavController = viewControllers?[index] as? UINavigationController,
           let browserVC = browserNavController.topViewController as? BrowserViewController {

            if isInitialLaunch {
                // Primo clic iniziale su flag
                print("photo done")
                browserVC.captureWebViewScreenshot()
                isInitialLaunch = false
                wasFlagTabPreviouslySelected = true
            } else if wasFlagTabPreviouslySelected {
                // Dal secondo clic consecutivo su flag
                print("photo don")
                browserVC.captureWebViewScreenshot()
            } else {
                // Primo clic su flag dopo aver selezionato un altro tab
                wasFlagTabPreviouslySelected = true
                print("phtot do")
                browserVC.captureWebViewScreenshot()

            }
        } else {
            // Selezionato un altro tab, resetta lo stato
            wasFlagTabPreviouslySelected = false
        }

        return true
    }

    // Funzione per simulare il pulsante premuto
    func simulateButtonPress(for tabBarItem: UITabBarItem) {
        guard let tabBar = tabBarController?.tabBar else { return }

        // Trova il pulsante associato al tabBarItem
        if let tabBarButton = tabBar.subviews.first(where: { view in
            guard let item = (view as? UIControl)?.value(forKey: "item") as? UITabBarItem else { return false }
            return item == tabBarItem
        }) {
            // Anima la pressione del pulsante
            UIView.animate(withDuration: 0.1, animations: {
                tabBarButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }, completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    tabBarButton.transform = CGAffineTransform.identity
                }
            })
        }
    }    // MARK: - API
    
    func checkIfUserIsLoggedIn() {
        if let user = Auth.auth().currentUser {
            print("User logged in with UID: \(user.uid)")
            if let email = user.email {
                print("User email: \(email)")
            } else {
                print("No email associated with this account.")
            }
        } else {
            print("No user is logged in. Redirecting to login screen...")
            DispatchQueue.main.async {
                let loginVC = LoginVC()
                let navController = UINavigationController(rootViewController: loginVC)
                navController.modalPresentationStyle = .fullScreen
                self.present(navController, animated: true, completion: nil)
            }
        }
    }
    
    func observeNotifications() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        NOTIFICATIONS_REF.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            allObjects.forEach { snapshot in
                let notificationId = snapshot.key
                
                NOTIFICATIONS_REF.child(currentUid).child(notificationId).child("checked").observeSingleEvent(of: .value) { snapshot in
                    guard let checked = snapshot.value as? Int else { return }
                    
                    if checked == 0 {
                        self.dot.isHidden = false
                    } else {
                        self.dot.isHidden = true
                    }
                }
            }
        }
    }

    // MARK: - FeedVCDelegate Implementation
    
    func didSelectWebsiteInFeed(url: URL) {
        print("URL received in MainTabVC: \(url.absoluteString)")
        self.selectedIndex = 2 // Assuming BrowserViewController is the third tab (index 2)
        
        if let browserNavController = viewControllers?[2] as? UINavigationController {
            if let browserVC = browserNavController.topViewController as? BrowserViewController {
                browserVC.load(url: url)
            } else {
                let browserVC = BrowserViewController()
                browserVC.load(url: url)
                browserNavController.pushViewController(browserVC, animated: true)
            }
        } else {
            let browserVC = BrowserViewController()
            browserVC.load(url: url)
            present(browserVC, animated: true, completion: nil)
        }
    }
    
    // MARK: - UserVCDelegate Implementation

    func didSelectWebsiteInUser(url: URL) {
        print("MainTabVC: didSelectWebsiteInUser called with URL: \(url.absoluteString)")
        self.selectedIndex = 2  // Assuming BrowserViewController is the third tab (index 2)
        
        if let browserNavController = viewControllers?[2] as? UINavigationController {
            if let browserVC = browserNavController.topViewController as? BrowserViewController {
                browserVC.load(url: url)
            } else {
                let browserVC = BrowserViewController()
                browserVC.load(url: url)
                browserNavController.pushViewController(browserVC, animated: true)
            }
        } else {
            let browserVC = BrowserViewController()
            browserVC.load(url: url)
            present(browserVC, animated: true, completion: nil)
        }
    }
}
