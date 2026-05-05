//
//  ForgotPasswordViewController.swift
//  com.mattiaponcini.project
//
//  Schermata "Password dimenticata": l'utente inserisce l'email e
//  riceve da Firebase un link per reimpostare la password.
//
//  Stile coerente con LoginViewController: stessi font, padding,
//  bordi 16pt, palette Brand. Niente logo dentro la pagina, il
//  titolo "Recupera la password" vive nell'header in-page (per
//  matchare l'aspetto delle altre schermate dell'app dove la nav
//  bar viene nascosta o usata solo per il back).
//

import UIKit

final class ForgotPasswordViewController: UIViewController {

    // MARK: - UI

    /// Icona simbolica in alto: lucchetto/busta per dare contesto immediato.
    private let headerIconView: UIImageView = {
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        let iv = UIImageView(image: UIImage(systemName: "lock.rotation",
                                            withConfiguration: cfg))
        iv.tintColor = .Brand.goldPrimary
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Recupera la password"
        l.font = .systemFont(ofSize: 24, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Inserisci l'email associata al tuo account. Ti invieremo un link per reimpostare la password."
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let emailField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.borderStyle = .roundedRect
        tf.keyboardType = .emailAddress
        // contentType .username preferito per il flusso "recupera credenziali"
        // (suggerimenti tastiera più appropriati di .emailAddress quando
        // il campo non sta creando un account né facendo login).
        tf.textContentType = .username
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.returnKeyType = .send
        return tf
    }()

    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Invia email", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .Brand.goldPrimary
        btn.setTitleColor(.white, for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        return btn
    }()

    private let cancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Annulla", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15)
        btn.setTitleColor(.Brand.goldPrimary, for: .normal)
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - Init

    /// Email pre-compilata (es. quella già digitata in login).
    private let prefilledEmail: String?

    init(prefilledEmail: String? = nil) {
        self.prefilledEmail = prefilledEmail
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Quando arriviamo qui dal login (push) la nav bar è nascosta;
        // la mostriamo per dare il pulsante back automatico.
        navigationController?.setNavigationBarHidden(false, animated: false)
        title = nil  // titolo in-page, niente duplicati nella nav bar

        setupLayout()
        setupDismissKeyboardGesture()

        emailField.delegate = self
        if let email = prefilledEmail, !email.isEmpty {
            emailField.text = email
        }

        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
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
        // Container icona (per centrare l'immagine senza forzare la
        // dimensione di tutto lo stack a quella dell'icona).
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(headerIconView)
        NSLayoutConstraint.activate([
            headerIconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            headerIconView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            headerIconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
            headerIconView.widthAnchor.constraint(equalToConstant: 56),
            headerIconView.heightAnchor.constraint(equalToConstant: 56)
        ])

        let stack = UIStackView(arrangedSubviews: [
            iconContainer,
            titleLabel,
            subtitleLabel,
            emailField,
            sendButton,
            cancelButton,
            activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 16
        stack.setCustomSpacing(14, after: iconContainer)
        stack.setCustomSpacing(10, after: titleLabel)
        stack.setCustomSpacing(28, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            sendButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    // MARK: - Actions

    @objc private func handleSend() {
        let email = (emailField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        // Validazione client-side: contiene "@" e "."
        guard isLikelyValidEmail(email) else {
            showAlert(title: "Email non valida",
                      message: "Inserisci un indirizzo email valido (es. nome@dominio.it).")
            return
        }

        view.endEditing(true)
        setLoading(true)
        AuthService.shared.sendPasswordReset(email: email) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    self.handleSendSuccess()
                case .failure(let error):
                    self.handleSendFailure(error)
                }
            }
        }
    }

    @objc private func handleCancel() {
        dismissSelf()
    }

    private func handleSendSuccess() {
        // Toast sulla window (sopravvive al dismiss della VC) +
        // dismiss immediato per portare l'utente di nuovo al login.
        let message = "Email inviata. Controlla la tua posta (anche spam)."
        if let window = view.window {
            ToastView.show(message: message, in: window)
        }
        dismissSelf()
    }

    private func handleSendFailure(_ error: Error) {
        showAlert(title: "Impossibile inviare l'email",
                  message: friendlyMessage(for: error))
    }

    /// Pop dal nav stack se siamo stati pushati, altrimenti dismiss modale.
    private func dismissSelf() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - Helpers

    /// Validazione "leggera" lato client: deve contenere @ e . dopo l'@.
    /// Non vogliamo bloccare email valide ma poco comuni — la validazione
    /// definitiva la fa Firebase server-side.
    private func isLikelyValidEmail(_ email: String) -> Bool {
        guard let at = email.firstIndex(of: "@") else { return false }
        let domain = email[email.index(after: at)...]
        return !domain.isEmpty && domain.contains(".")
    }

    /// Mappa gli errori Firebase più comuni in messaggi user-friendly in
    /// italiano. Per gli altri casi cadiamo sul `localizedDescription`.
    private func friendlyMessage(for error: Error) -> String {
        let ns = error as NSError
        // Firebase Auth error codes — i raw value sono stabili tra le versioni.
        switch ns.code {
        case 17008: // ERROR_INVALID_EMAIL
            return "L'indirizzo email non è valido."
        case 17011: // ERROR_USER_NOT_FOUND
            return "Nessun account associato a questa email."
        case 17020: // ERROR_NETWORK_REQUEST_FAILED
            return "Errore di rete, riprova più tardi."
        case 17010: // ERROR_TOO_MANY_REQUESTS
            return "Troppi tentativi, riprova tra qualche minuto."
        default:
            return error.localizedDescription
        }
    }

    private func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        sendButton.isEnabled = !loading
        sendButton.alpha = loading ? 0.6 : 1.0
        cancelButton.isEnabled = !loading
        emailField.isEnabled = !loading
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension ForgotPasswordViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        handleSend()
        return true
    }
}
