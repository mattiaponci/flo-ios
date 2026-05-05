//
//  LoginViewController.swift
//  com.mattiaponcini.project
//
//  Schermata di login: solo wordmark "Flotip" (no bandierina/logo),
//  email + password, bottone Accedi, link verso registrazione.
//  Tasto "invio" sui campi sposta al campo successivo.
//

import UIKit

final class LoginViewController: UIViewController {

    // MARK: - UI

    /// Wordmark "Flotip" (nessun simbolo, nessun logo).
    private let wordmarkLabel: UILabel = {
        let l = UILabel()
        l.text = "Flotip"
        l.font = .systemFont(ofSize: 38, weight: .semibold)
        l.textColor = .Brand.goldPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emailField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .emailAddress
        tf.textContentType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.returnKeyType = .next
        return tf
    }()

    private let passwordField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = true
        tf.textContentType = .password
        tf.returnKeyType = .go
        return tf
    }()

    private let loginButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Accedi", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .Brand.goldPrimary
        btn.setTitleColor(.white, for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        return btn
    }()

    private let registerButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Non hai un account? Registrati", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15)
        btn.setTitleColor(.Brand.goldPrimary, for: .normal)
        return btn
    }()

    /// Link "Password dimenticata?" sotto il bottone Login, allineato a
    /// destra. Apre `ForgotPasswordViewController` con l'email già
    /// pre-compilata se l'utente l'ha digitata in login.
    private let forgotPasswordButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Password dimenticata?", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        btn.setTitleColor(.Brand.goldPrimary, for: .normal)
        btn.contentHorizontalAlignment = .trailing
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Niente titolo nella nav bar (richiesta UX: solo "Flotip" come
        // wordmark dentro la pagina, niente "Accedi" né badge).
        title = nil
        if let nav = navigationController, !nav.isNavigationBarHidden {
            nav.setNavigationBarHidden(true, animated: false)
        }

        setupLayout()
        setupDismissKeyboardGesture()

        emailField.delegate = self
        passwordField.delegate = self

        loginButton.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(handleShowRegister), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(handleShowForgotPassword), for: .touchUpInside)
    }

    /// Tap su qualunque area libera del background → chiude la tastiera.
    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [
            wordmarkLabel,
            emailField,
            passwordField,
            loginButton,
            forgotPasswordButton,
            registerButton,
            activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(36, after: wordmarkLabel)
        // Link "Password dimenticata?" subito sotto il bottone Login,
        // separato di poco per dare l'impressione di azione secondaria
        // collegata al login (e non un blocco a sé).
        stack.setCustomSpacing(8, after: loginButton)
        stack.setCustomSpacing(20, after: forgotPasswordButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            loginButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Actions

    @objc private func handleLogin() {
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""
        setLoading(true)
        AuthService.shared.login(email: email, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)
                switch result {
                case .success:
                    self?.routeToMain()
                case .failure(let error):
                    self?.showAlert(title: "Errore", message: error.localizedDescription)
                }
            }
        }
    }

    @objc private func handleShowRegister() {
        let registerVC = RegisterViewController()
        if let nav = navigationController {
            // Quando entriamo nella registrazione, la nav bar serve (per
            // mostrare "Registrazione" + back); la riveliamo qui.
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(registerVC, animated: true)
        } else {
            present(UINavigationController(rootViewController: registerVC), animated: true)
        }
    }

    @objc private func handleShowForgotPassword() {
        // Pre-compiliamo l'email se l'utente l'ha già digitata: piccolo
        // attrito in meno nel flusso di recupero.
        let prefilled = (emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let forgotVC = ForgotPasswordViewController(prefilledEmail: prefilled.isEmpty ? nil : prefilled)
        if let nav = navigationController {
            nav.setNavigationBarHidden(false, animated: true)
            nav.pushViewController(forgotVC, animated: true)
        } else {
            // Fallback senza nav: pageSheet con grabber, coerente con
            // il resto dell'app per le presentazioni modali.
            let wrapper = UINavigationController(rootViewController: forgotVC)
            wrapper.modalPresentationStyle = .pageSheet
            if let sheet = wrapper.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 16
            }
            present(wrapper, animated: true)
        }
    }

    private func routeToMain() {
        // Il listener in SceneDelegate reagisce automaticamente al login di Firebase Auth.
        // Questa funzione rimane vuota: non serve navigare manualmente.
    }

    private func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        loginButton.isEnabled = !loading
        registerButton.isEnabled = !loading
        forgotPasswordButton.isEnabled = !loading
        emailField.isEnabled = !loading
        passwordField.isEnabled = !loading
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate (Return → next field)

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === emailField {
            passwordField.becomeFirstResponder()
        } else if textField === passwordField {
            // "Go" → fa direttamente login.
            textField.resignFirstResponder()
            handleLogin()
        }
        return true
    }
}
