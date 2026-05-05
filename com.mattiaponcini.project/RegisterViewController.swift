//
//  RegisterViewController.swift
//  com.mattiaponcini.project
//
//  Schermata di registrazione: foto profilo + campi anagrafici + email +
//  password + conferma password + checkbox legale + bottone "Registrati".
//
//  Niente logo o wordmark dentro la schermata: il titolo "Registrazione"
//  vive solo nella top bar (UINavigationItem.title).
//
//  Il tasto "Avanti" / "Vai" della tastiera porta al campo successivo.
//  Età minima 16 anni (legge GDPR/UK Online Safety / store policy).
//  L'utente deve spuntare la checkbox "Ho letto e accetto" per poter
//  premere "Registrati": il bottone resta disabilitato finché non lo fa.
//  Il link apre la pagina /legal del sito Flotip in Safari.
//

import UIKit
import PhotosUI
import SafariServices

final class RegisterViewController: UIViewController, PHPickerViewControllerDelegate {

    // MARK: - Constants

    /// URL della pagina legale (Terms of Service + Privacy Policy).
    /// Punta al deployment Railway del sito Flotip. Quando passerai al
    /// dominio personalizzato (es. flotip.app/legal) basta aggiornare
    /// questa stringa.
    private static let legalURL = URL(string: "https://web-production-4890a.up.railway.app/legal")!

    /// Età minima per registrarsi.
    private static let minimumAge = 16

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private let photoButton: UIButton = {
        let btn = UIButton(type: .custom)
        btn.setTitle("+ foto", for: .normal)
        btn.setTitleColor(.Brand.goldPrimary, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        btn.backgroundColor = .Brand.creamSurface
        btn.layer.cornerRadius = 60
        btn.layer.borderWidth = 1
        btn.layer.borderColor = UIColor.Brand.goldSecondary.cgColor
        btn.clipsToBounds = true
        btn.imageView?.contentMode = .scaleAspectFill
        return btn
    }()

    private let firstNameField = RegisterViewController.makeField(
        placeholder: "Nome", contentType: .givenName, returnKey: .next)
    private let lastNameField = RegisterViewController.makeField(
        placeholder: "Cognome", contentType: .familyName, returnKey: .next)

    private let birthDateField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Data di nascita"
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .next
        return tf
    }()
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.maximumDate = Date()
        if #available(iOS 13.4, *) { dp.preferredDatePickerStyle = .wheels }
        return dp
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
        tf.placeholder = "Password (min. 6 caratteri)"
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = true
        tf.textContentType = .newPassword
        tf.returnKeyType = .next
        return tf
    }()

    private let confirmPasswordField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Conferma password"
        tf.borderStyle = .roundedRect
        tf.isSecureTextEntry = true
        tf.textContentType = .newPassword
        tf.returnKeyType = .go
        return tf
    }()

    /// Riga checkbox + label "Ho letto e accetto…".
    /// Il bottone Registrati resta disabilitato finché legalAccepted == false.
    private let legalCheckbox: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        b.setImage(UIImage(systemName: "square", withConfiguration: cfg), for: .normal)
        b.tintColor = .Brand.goldPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        b.contentEdgeInsets = .zero
        return b
    }()

    private let legalLabel: UILabel = {
        let l = UILabel()
        l.text = "Ho letto e accetto i Termini di Servizio e la Privacy Policy."
        l.font = .systemFont(ofSize: 13)
        l.textColor = .label
        l.numberOfLines = 0
        l.isUserInteractionEnabled = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Link separato sotto la checkbox per APRIRE la pagina legale
    /// (così la spunta resta un'azione esplicita, distinta dal "leggi").
    private let legalLinkButton: UIButton = {
        let b = UIButton(type: .system)
        let title = NSAttributedString(
            string: "Leggi i Termini di Servizio →",
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.Brand.goldPrimary,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ])
        b.setAttributedTitle(title, for: .normal)
        b.contentHorizontalAlignment = .leading
        return b
    }()

    private let registerButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Registrati", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = .Brand.goldPrimary
        btn.setTitleColor(.white, for: .normal)
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - State

    private var selectedPhoto: UIImage?
    private var legalAccepted: Bool = false {
        didSet { updateRegisterEnabled() }
    }

    // MARK: - Helpers (factory)

    private static func makeField(placeholder: String,
                                  contentType: UITextContentType?,
                                  returnKey: UIReturnKeyType) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.borderStyle = .roundedRect
        tf.textContentType = contentType
        tf.returnKeyType = returnKey
        return tf
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Registrazione"
        setupLayout()
        setupActions()
        setupDatePicker()
        setupDismissKeyboardGesture()
        setupFieldDelegates()

        updateRegisterEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Quando arriviamo qui da LoginViewController la nav bar è
        // (eventualmente) nascosta: la riveliamo per mostrare il titolo
        // "Registrazione" e il pulsante back automatico.
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    /// Tap su qualunque area libera → chiude la tastiera (e il date picker).
    private func setupDismissKeyboardGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Container foto profilo (per centrare il bottone tondo).
        let photoContainer = UIView()
        photoContainer.translatesAutoresizingMaskIntoConstraints = false
        photoButton.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.addSubview(photoButton)
        NSLayoutConstraint.activate([
            photoButton.centerXAnchor.constraint(equalTo: photoContainer.centerXAnchor),
            photoButton.topAnchor.constraint(equalTo: photoContainer.topAnchor),
            photoButton.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor),
            photoButton.widthAnchor.constraint(equalToConstant: 120),
            photoButton.heightAnchor.constraint(equalToConstant: 120)
        ])

        // Riga checkbox + label allineata a sinistra.
        let legalRow = UIStackView(arrangedSubviews: [legalCheckbox, legalLabel])
        legalRow.axis = .horizontal
        legalRow.alignment = .top
        legalRow.spacing = 10
        legalRow.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            legalCheckbox.widthAnchor.constraint(equalToConstant: 28),
            legalCheckbox.heightAnchor.constraint(equalToConstant: 28)
        ])

        // Stack principale verticale.
        let stack = UIStackView(arrangedSubviews: [
            photoContainer,
            firstNameField,
            lastNameField,
            birthDateField,
            emailField,
            passwordField,
            confirmPasswordField,
            legalRow,
            legalLinkButton,
            registerButton,
            activityIndicator
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(20, after: photoContainer)
        stack.setCustomSpacing(18, after: confirmPasswordField)
        stack.setCustomSpacing(2, after: legalRow)
        stack.setCustomSpacing(20, after: legalLinkButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            registerButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func setupActions() {
        photoButton.addTarget(self, action: #selector(handlePickPhoto), for: .touchUpInside)
        registerButton.addTarget(self, action: #selector(handleRegister), for: .touchUpInside)
        legalCheckbox.addTarget(self, action: #selector(toggleLegal), for: .touchUpInside)
        legalLinkButton.addTarget(self, action: #selector(openLegal), for: .touchUpInside)

        // Tap sulla label → toggla la checkbox (target più ampio).
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleLegal))
        legalLabel.addGestureRecognizer(tap)
    }

    private func setupFieldDelegates() {
        firstNameField.delegate = self
        lastNameField.delegate = self
        birthDateField.delegate = self
        emailField.delegate = self
        passwordField.delegate = self
        confirmPasswordField.delegate = self
    }

    private func setupDatePicker() {
        birthDateField.inputView = datePicker
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                   action: #selector(handleDateDone))
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.setItems([flex, done], animated: false)
        birthDateField.inputAccessoryView = toolbar
    }

    @objc private func handleDateDone() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "it_IT")
        birthDateField.text = formatter.string(from: datePicker.date)
        view.endEditing(true)
        // Dopo aver scelto la data passiamo al campo email per fluidità.
        emailField.becomeFirstResponder()
    }

    // MARK: - Actions

    @objc private func handlePickPhoto() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, _ in
            DispatchQueue.main.async {
                guard let self = self, let image = image as? UIImage else { return }
                self.selectedPhoto = image
                self.photoButton.setTitle(nil, for: .normal)
                // .alwaysOriginal evita che il tint del bottone colori la foto.
                self.photoButton.setImage(image.withRenderingMode(.alwaysOriginal), for: .normal)
            }
        }
    }

    @objc private func toggleLegal() {
        legalAccepted.toggle()
        let cfg = UIImage.SymbolConfiguration(pointSize: 22,
                                              weight: legalAccepted ? .semibold : .regular)
        let symbol = legalAccepted ? "checkmark.square.fill" : "square"
        legalCheckbox.setImage(UIImage(systemName: symbol, withConfiguration: cfg), for: .normal)
        legalCheckbox.tintColor = legalAccepted ? .Brand.goldPrimary : .Brand.goldSecondary
    }

    @objc private func openLegal() {
        // Usiamo SFSafariViewController così l'utente può leggere e tornare
        // alla registrazione senza uscire dall'app.
        let safari = SFSafariViewController(url: Self.legalURL)
        safari.preferredControlTintColor = .Brand.goldPrimary
        present(safari, animated: true)
    }

    @objc private func handleRegister() {
        let firstName = firstNameField.text ?? ""
        let lastName = lastNameField.text ?? ""
        let email = emailField.text ?? ""
        let password = passwordField.text ?? ""
        let confirm = confirmPasswordField.text ?? ""
        let birthDate = datePicker.date

        // Validazione: data di nascita scelta.
        guard !(birthDateField.text ?? "").isEmpty else {
            showAlert(title: "Errore", message: "Seleziona la data di nascita.")
            return
        }

        // Validazione: età minima 16.
        let years = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        guard years >= Self.minimumAge else {
            showAlert(title: "Età non sufficiente",
                      message: "Devi avere almeno \(Self.minimumAge) anni per registrarti su Flotip.")
            return
        }

        // Validazione: checkbox legale (extra-difesa anche se il bottone è disabled).
        guard legalAccepted else {
            showAlert(title: "Accettazione richiesta",
                      message: "Per continuare devi confermare di aver letto i Termini di Servizio.")
            return
        }

        setLoading(true)
        AuthService.shared.register(
            firstName: firstName,
            lastName: lastName,
            birthDate: birthDate,
            photo: selectedPhoto,
            email: email,
            password: password,
            confirmPassword: confirm
        ) { [weak self] result in
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

    // MARK: - Helpers

    private func updateRegisterEnabled() {
        registerButton.isEnabled = legalAccepted
        registerButton.alpha = legalAccepted ? 1.0 : 0.45
    }

    private func routeToMain() {
        // Il listener in SceneDelegate reagisce automaticamente alla registrazione.
        // Non serve navigare manualmente.
    }

    private func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        let inputs: [UIControl] = [registerButton, photoButton, firstNameField, lastNameField,
                                   birthDateField, emailField, passwordField, confirmPasswordField,
                                   legalCheckbox, legalLinkButton]
        inputs.forEach { $0.isEnabled = !loading }
        // Anche da loading, se il legal non è accettato il bottone resta disabled.
        if !loading { updateRegisterEnabled() }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate (Return → next field)

extension RegisterViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case firstNameField:
            lastNameField.becomeFirstResponder()
        case lastNameField:
            // Apre il date picker mostrando la birth-date toolbar.
            birthDateField.becomeFirstResponder()
        case birthDateField:
            emailField.becomeFirstResponder()
        case emailField:
            passwordField.becomeFirstResponder()
        case passwordField:
            confirmPasswordField.becomeFirstResponder()
        case confirmPasswordField:
            // "Vai" → registrazione (verifica anche legal/age).
            textField.resignFirstResponder()
            handleRegister()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
