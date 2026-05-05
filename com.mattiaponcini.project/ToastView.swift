//
//  ToastView.swift
//  Flotip
//
//  Toast minimale (HUD breve) usato per feedback dopo azioni come
//  "Salvato in libreria". Si appoggia direttamente alla UIWindow così
//  sopravvive ai dismiss modali in corso.
//

import UIKit

final class ToastView: UIView {

    /// Mostra un toast scuro con testo bianco in fondo alla window per
    /// circa 1.8s, con fade in/out morbidi. Non blocca l'interazione utente.
    static func show(message: String,
                     in window: UIWindow,
                     duration: TimeInterval = 1.8) {
        let toast = ToastView(message: message)
        toast.alpha = 0
        toast.translatesAutoresizingMaskIntoConstraints = false
        window.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor,
                                          constant: -32),
            toast.leadingAnchor.constraint(greaterThanOrEqualTo: window.leadingAnchor, constant: 24),
            toast.trailingAnchor.constraint(lessThanOrEqualTo: window.trailingAnchor, constant: -24)
        ])

        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: {
            toast.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [.curveEaseIn], animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        })
    }

    private init(message: String) {
        super.init(frame: .zero)
        backgroundColor = UIColor.black.withAlphaComponent(0.82)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = false

        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
