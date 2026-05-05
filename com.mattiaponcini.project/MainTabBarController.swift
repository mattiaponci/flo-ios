//
//  MainTabBarController.swift
//  com.mattiaponcini.project
//

import UIKit

class MainTabBarController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self

        // Tinta oro per le icone/etichette della tab attiva
        tabBar.tintColor = .Brand.goldPrimary

        // Tab bar fluttuante stile TikTok: trasparente con blur "chrome
        // material" e niente hairline divider, così le immagini del feed
        // si vedono in trasparenza sotto.
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.isTranslucent = true

        let feedVC = FeedViewController()
        feedVC.tabBarItem = UITabBarItem(title: "Feed", image: UIImage(systemName: "house"), tag: 0)

        let screenshotVC = ScreenshotViewController()
        // Tab Cattura:
        //  - non selezionata: icona SF Symbol "due quadrati sovrapposti".
        //  - selezionata: bandiera del logo dell'app (asta + due quadrati
        //    sovrapposti), come template image monocromatico. UIKit la tinge
        //    automaticamente con il `tintColor` della tab bar impostato sopra
        //    a `Brand.goldPrimary`, in coerenza con gli altri SF Symbol.
        screenshotVC.tabBarItem = UITabBarItem(
            title: nil,
            image: UIImage(systemName: "square.on.square"),
            selectedImage: UIImage(named: "FlotipFlagTab")
        )
        screenshotVC.tabBarItem.tag = 1
        // Senza title l'icona viene centrata: l'offset down preserva
        // l'allineamento con le altre tab che hanno il titolo sotto, mentre
        // i valori negativi su left/right (e l'asimmetria tra top/bottom)
        // fanno "sbordare" l'icona oltre il rettangolo standard, rendendola
        // visivamente più grande del classico SF Symbol da 25pt (~+30-40%).
        // Combinato con la silhouette al ~95% del canvas nel PNG, l'effetto
        // è una bandiera nettamente più grande degli altri tab item.
        screenshotVC.tabBarItem.imageInsets = UIEdgeInsets(top: 2, left: -4, bottom: -10, right: -4)

        let profileVC = ProfileViewController()
        profileVC.tabBarItem = UITabBarItem(title: "Profilo", image: UIImage(systemName: "person"), tag: 2)

        viewControllers = [feedVC, screenshotVC, profileVC]

        // Avvia sulla tab Cattura
        selectedIndex = 1
    }

    // Chiamato quando si tocca una tab già selezionata
    func tabBarController(_ tabBarController: UITabBarController,
                          shouldSelect viewController: UIViewController) -> Bool {
        if viewController === selectedViewController,
           let screenshotVC = viewController as? ScreenshotViewController {
            // Secondo tap sulla tab Screenshot: scatta screenshot
            screenshotVC.takeWebViewSnapshot()
        }
        return true
    }
}
