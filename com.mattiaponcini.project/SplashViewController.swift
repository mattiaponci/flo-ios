//
//  SplashViewController.swift
//  Flotip
//
//  Splash schermo programmatico mostrato come PRIMO root della scena,
//  subito dopo il LaunchScreen.storyboard (che è solo bianco). Mostra
//  il wordmark "Flotip" con una piccola animazione di entrata, poi cede
//  il controllo al SceneDelegate via callback `onFinish`.
//
//  Versione attuale: testo "Flotip" senza icona/bandiera, per richiesta UX.
//

import UIKit

final class SplashViewController: UIViewController {

    /// Chiamata quando il splash ha terminato la sua animazione.
    var onFinish: (() -> Void)?

    private let wordmarkLabel: UILabel = {
        let l = UILabel()
        l.text = "Flotip"
        l.font = .systemFont(ofSize: 38, weight: .semibold)
        l.textColor = .Brand.goldPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    private func setupLayout() {
        view.addSubview(wordmarkLabel)
        NSLayoutConstraint.activate([
            wordmarkLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            wordmarkLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Stato iniziale per l'animazione: leggermente piccolo e trasparente.
        wordmarkLabel.alpha = 0
        wordmarkLabel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        runEntranceAnimation()
    }

    private func runEntranceAnimation() {
        // Fade-in + leggera scala
        UIView.animate(
            withDuration: 0.55,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.6,
            options: [.curveEaseOut],
            animations: {
                self.wordmarkLabel.alpha = 1
                self.wordmarkLabel.transform = .identity
            },
            completion: { _ in
                // Tieni visibile il testo ~0.6s prima di lasciare il root vero
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.onFinish?()
                }
            }
        )
    }
}
