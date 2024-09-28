//
//  MainTabVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//




import UIKit

class MainTabVC: UITabBarController, UITabBarControllerDelegate {
    let dot = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self

        // Configura i view controllers
        configureViewControllers()
    }
    
    func configureViewControllers() {
        // Crea l'istanza di UserProfileVC
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        
        // Home feed controller
        let feedVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "home_unselected"), selectedImage: #imageLiteral(resourceName: "home_selected"), rootViewController: FeedVC())
        
        // Search feed controller
        let searchVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "search_unselected"), selectedImage: #imageLiteral(resourceName: "search_selected"), rootViewController: SearchVC())
        
        // **BrowserViewController inserito in un UINavigationController**
        let browserVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "grid"), selectedImage: #imageLiteral(resourceName: "grid"), rootViewController: BrowserViewController())
        
        // Notification controller
        let notificationVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "like_unselected"), selectedImage: #imageLiteral(resourceName: "like_selected"), rootViewController: NotificationsVC())
        
        // User profile controller
        let userNavProfileVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "profile_unselected"), selectedImage: #imageLiteral(resourceName: "profile_selected"), rootViewController: userProfileVC)
        
        // Aggiungi i controller al tab bar
        viewControllers = [feedVC, searchVC, browserVC, notificationVC, userNavProfileVC]
        
        // Colore di sfondo della tab bar
        tabBar.backgroundColor = UIColor.white
        view.backgroundColor = UIColor.white
    }

    // Metodo per costruire un UINavigationController con immagini di tab selezionate/non selezionate
    func constructNavController(unselectedImage: UIImage, selectedImage: UIImage, rootViewController: UIViewController = UIViewController()) -> UINavigationController {
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.tabBarItem.image = unselectedImage
        navController.tabBarItem.selectedImage = selectedImage
        navController.navigationBar.tintColor = .black
        return navController
    }
    
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        let index = viewControllers?.firstIndex(of: viewController)
        
        dot.isHidden = true
        return true
    }
}
