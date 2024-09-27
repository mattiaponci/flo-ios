//
//  MainTabVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit

class MainTabVC: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // configure view controllers
        configureViewControllers()
     

    }
    

    func configureViewControllers() {
        
        
        
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
       // userProfileVC.delegate = self
        
        // home feed controller
        let feedVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "home_unselected"), selectedImage: #imageLiteral(resourceName: "home_selected"), rootViewController: FeedVC())
        
                                            // search feed controller
        let searchVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "search_unselected"), selectedImage: #imageLiteral(resourceName: "search_selected"), rootViewController: SearchVC())
        
        let browserVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "grid"), selectedImage: #imageLiteral(resourceName: "grid"), rootViewController: BrowserViewController())

        
        let notificationVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "like_unselected"), selectedImage: #imageLiteral(resourceName: "like_selected"), rootViewController: NotificationsVC())

        
        let userNavProfileVC = constructNavController(unselectedImage: #imageLiteral(resourceName: "profile_unselected"), selectedImage: #imageLiteral(resourceName: "profile_selected"), rootViewController: userProfileVC)

        
        // view controllers to be added to tab controller
        viewControllers = [feedVC, searchVC, browserVC, notificationVC, userNavProfileVC]
        
        // tab bar tint color
        //tabBar.tintColor = .gray
        tabBar.backgroundColor = UIColor.white
        
        view.backgroundColor = UIColor.white

    }
                                            /// construct navigation controllers
    func constructNavController(unselectedImage: UIImage, selectedImage: UIImage, rootViewController: UIViewController = UIViewController()) -> UINavigationController {
                                                
                                                // construct nav controller
    let navController = UINavigationController(rootViewController: rootViewController)
                                               
    navController.tabBarItem.image = unselectedImage
    navController.tabBarItem.selectedImage = selectedImage
    navController.navigationBar.tintColor = .black
                                                
                                                // return nav controller
    return navController
 }
}
