//
//  AlermManager.swift
//  flotipios
//
//  Created by mattia poncini on 19.10.2024.
//
import UIKit

class AlertManager {
    static func showPopup() {
        guard let window = UIApplication.shared.windows.first else { return }
        
        // Create popup view
        let popupView = UIView()
        popupView.backgroundColor = .white
        popupView.layer.cornerRadius = 20
        popupView.translatesAutoresizingMaskIntoConstraints = false
        popupView.layer.shadowColor = UIColor.black.cgColor
        popupView.layer.shadowOpacity = 0.2
        popupView.layer.shadowOffset = CGSize(width: 0, height: 5)
        popupView.layer.shadowRadius = 10
        
        // Create title label
        let titleLabel = UILabel()
        titleLabel.text = "Attention"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create message label
        let messageLabel = UILabel()
        messageLabel.text = "You have made three unsuccessful password attempts. Please try again in one hour."
        messageLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        messageLabel.textColor = .darkGray
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Create "Keep it" button
        let keepItButton = UIButton(type: .system)
        keepItButton.setTitle("ok", for: .normal)
        keepItButton.setTitleColor(.black, for: .normal)
        keepItButton.backgroundColor = .white
        keepItButton.layer.cornerRadius = 10
        keepItButton.layer.borderWidth = 1
        keepItButton.layer.borderColor = UIColor.lightGray.cgColor
        keepItButton.translatesAutoresizingMaskIntoConstraints = false
        keepItButton.addTarget(self, action: #selector(dismissPopup), for: .touchUpInside)
        
        // Add subviews to popup view
        popupView.addSubview(titleLabel)
        popupView.addSubview(messageLabel)
        popupView.addSubview(keepItButton)
        
        // Add popup view to main view
        window.addSubview(popupView)
        
        // Set popup view constraints
        NSLayoutConstraint.activate([
            popupView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            popupView.centerYAnchor.constraint(equalTo: window.centerYAnchor),
            popupView.widthAnchor.constraint(equalToConstant: 300),
            popupView.heightAnchor.constraint(equalToConstant: 240),
            
            titleLabel.topAnchor.constraint(equalTo: popupView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: popupView.centerXAnchor),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            messageLabel.leadingAnchor.constraint(equalTo: popupView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: popupView.trailingAnchor, constant: -20),
            
            keepItButton.centerXAnchor.constraint(equalTo: popupView.centerXAnchor),
            keepItButton.bottomAnchor.constraint(equalTo: popupView.bottomAnchor, constant: -20),
            keepItButton.widthAnchor.constraint(equalToConstant: 120),
            keepItButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc static func dismissPopup() {
        guard let window = UIApplication.shared.windows.first else { return }
        if let popupView = window.subviews.last {
            popupView.removeFromSuperview()
        }
    }
    
    @objc static func removeItem() {
        print("Item removed from cart.")
        dismissPopup()
    }
    
    @objc static func showTopAlert() {
        guard let window = UIApplication.shared.windows.first else { return }
        
        // Create alert view
        let alertView = UIView()
        alertView.translatesAutoresizingMaskIntoConstraints = false
        alertView.layer.cornerRadius = 10
        alertView.clipsToBounds = true
        
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.red.withAlphaComponent(1).cgColor, UIColor.red.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = CGRect(x: 0, y: 0, width: window.frame.width - 20, height: 80)
        alertView.layer.insertSublayer(gradientLayer, at: 0)
        
        // Create label
        let alertLabel = UILabel()
        alertLabel.text = "Wrong user name or password"
        alertLabel.textColor = .white
        alertLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        alertLabel.translatesAutoresizingMaskIntoConstraints = false
        alertView.addSubview(alertLabel)
        
        // Add alert view to main view
        window.addSubview(alertView)
        
        // Set alert view constraints
        NSLayoutConstraint.activate([
            alertView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 10),
            alertView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -10),
            alertView.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 20),
            alertView.heightAnchor.constraint(equalToConstant: 80),
            
            alertLabel.centerXAnchor.constraint(equalTo: alertView.centerXAnchor),
            alertLabel.centerYAnchor.constraint(equalTo: alertView.centerYAnchor)
        ])
        
        // Animate alert view
        alertView.transform = CGAffineTransform(translationX: 0, y: -100)
        UIView.animate(withDuration: 0.4, animations: {
            alertView.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 2, options: [], animations: {
                alertView.alpha = 0
            }) { _ in
                alertView.removeFromSuperview()
            }
        }
    }
}
