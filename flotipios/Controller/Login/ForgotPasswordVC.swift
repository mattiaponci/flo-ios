//
//  ForgotPasswordVC.swift
//  flotipios
//
//  Created by mattia poncini on 24.09.2024.
//

import UIKit

class ForgotPasswordVC: UIViewController {
    
    // Creazione del campo email
    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Enter your email"
        tf.attributedPlaceholder = NSAttributedString(string: "Enter your email", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
        tf.textColor = .black
        tf.keyboardType = .emailAddress
        return tf
    }()
    
    // Creazione del bottone Reset Password
    let resetPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Reset Password", for: .normal)
        button.setTitleColor(.white, for: .normal)
        // Colore blu più scuro
        button.backgroundColor = UIColor(red: 217/255, green: 183/255, blue: 67/255, alpha: 1)
        button.layer.cornerRadius = 5
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.addTarget(self, action: #selector(handleResetPassword), for: .touchUpInside)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        configureViewComponents()
        
        // Permette di chiudere la tastiera con un tap fuori dal TextField
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // Azione per il bottone Reset Password
    @objc func handleResetPassword() {
        guard let email = emailTextField.text, !email.isEmpty else {
            print("Error: Email field is empty")
            return
        }
        
        // Mostra un pop-up di conferma
        let alertController = UIAlertController(title: "Success", message: "Email send", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    func configureViewComponents() {
        // Configurazione dello StackView
        let stackView = UIStackView(arrangedSubviews: [emailTextField, resetPasswordButton])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        // Aggiunta delle constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
            stackView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 40),
            stackView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -40),
            stackView.heightAnchor.constraint(equalToConstant: 90) // Altezza totale: 40 + 10 + 40
        ])
    }
}
