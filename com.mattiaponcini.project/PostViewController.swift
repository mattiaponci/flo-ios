//
//  PostViewController.swift
//  Flotip
//
//  Composer di un nuovo "tip": riceve l'immagine catturata,
//  permette di scrivere una didascalia, carica tutto su Firebase
//  (Storage + Firestore via PostService) e poi chiude tutta la pila
//  modale tornando alla tab Cattura.
//

import UIKit

final class PostViewController: UIViewController {

    // MARK: - Input
    private let capturedImage: UIImage
    /// URL della pagina web da cui è stato catturato lo screenshot.
    /// Salvato sul post in modo che il doppio tap su un'immagine possa
    /// riaprire la pagina sorgente nella tab Cattura.
    private let sourceURL: String?
    private var cachedProfile: UserProfile?

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.keyboardDismissMode = .interactive
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 14
        iv.layer.cornerCurve = .continuous
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        iv.backgroundColor = .Brand.creamSurface
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let captionContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamSurface
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let captionTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let captionPlaceholder: UILabel = {
        let l = UILabel()
        l.text = "Aggiungi una didascalia…"
        l.font = .systemFont(ofSize: 16)
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let visibilityLabel: UILabel = {
        let l = UILabel()
        l.text = "Visibile a tutti gli utenti di Flotip"
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .Brand.goldPrimary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private var publishButton: UIBarButtonItem!
    private var saveButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!

    // MARK: - Init

    init(image: UIImage, sourceURL: String? = nil) {
        self.capturedImage = image
        self.sourceURL = sourceURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Nuovo tip"
        setupNavBar()
        setupLayout()
        setupGestures()
        captionTextView.delegate = self
        imageView.image = capturedImage
        loadAuthor()
    }

    // MARK: - Setup

    private func setupNavBar() {
        cancelButton = UIBarButtonItem(title: "Annulla", style: .plain,
                                       target: self, action: #selector(handleCancel))
        cancelButton.tintColor = .secondaryLabel

        publishButton = UIBarButtonItem(title: "Pubblica", style: .done,
                                        target: self, action: #selector(handlePublish))
        publishButton.tintColor = .Brand.goldPrimary
        publishButton.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.Brand.goldPrimary
        ], for: .normal)

        // Bottone secondario "Salva": tinta più tenue (gold secondario, regular)
        // accanto a "Pubblica". Il primo elemento di rightBarButtonItems è il
        // più a destra, quindi mettiamo Pubblica per primo e Salva alla sua sinistra.
        saveButton = UIBarButtonItem(title: "Salva", style: .plain,
                                     target: self, action: #selector(handleSave))
        saveButton.tintColor = .Brand.goldSecondary
        saveButton.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 17, weight: .regular),
            .foregroundColor: UIColor.Brand.goldSecondary
        ], for: .normal)

        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItems = [publishButton, saveButton]
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(imageView)
        contentView.addSubview(captionContainer)
        captionContainer.addSubview(captionTextView)
        captionContainer.addSubview(captionPlaceholder)
        contentView.addSubview(visibilityLabel)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 4.0/3.0),

            captionContainer.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            captionContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            captionContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            captionContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 110),

            captionTextView.topAnchor.constraint(equalTo: captionContainer.topAnchor),
            captionTextView.leadingAnchor.constraint(equalTo: captionContainer.leadingAnchor),
            captionTextView.trailingAnchor.constraint(equalTo: captionContainer.trailingAnchor),
            captionTextView.bottomAnchor.constraint(equalTo: captionContainer.bottomAnchor),

            captionPlaceholder.topAnchor.constraint(equalTo: captionTextView.topAnchor, constant: 14),
            captionPlaceholder.leadingAnchor.constraint(equalTo: captionTextView.leadingAnchor, constant: 16),
            captionPlaceholder.trailingAnchor.constraint(equalTo: captionTextView.trailingAnchor, constant: -16),

            visibilityLabel.topAnchor.constraint(equalTo: captionContainer.bottomAnchor, constant: 8),
            visibilityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            visibilityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            visibilityLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Author

    private func loadAuthor() {
        AuthService.shared.fetchCurrentUserProfile { [weak self] result in
            DispatchQueue.main.async {
                if case let .success(profile) = result {
                    self?.cachedProfile = profile
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func handleSave() {
        view.endEditing(true)
        let sheet = UIAlertController(
            title: "Aggiungi a libreria",
            message: "Scegli in quale categoria salvare lo screenshot.",
            preferredStyle: .actionSheet
        )

        // "Salvati" è riservata ai bookmark di post altrui dal feed
        // (porta sempre `originalPostId` non-nil). Il composer non salva
        // post originali, quindi mostriamo solo le categorie classiche.
        let composerCategories: [LibraryCategory] = LibraryCategory.allCases
            .filter { $0 != .saved }
        for category in composerCategories {
            sheet.addAction(UIAlertAction(title: category.displayName, style: .default) { [weak self] _ in
                self?.performSave(to: category)
            })
        }
        sheet.addAction(UIAlertAction(title: "Annulla", style: .cancel))

        // iPad: action sheet richiede sourceView per il popover.
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = saveButton
        }
        present(sheet, animated: true)
    }

    private func performSave(to category: LibraryCategory) {
        setLoading(true)
        let caption = captionTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        LibraryService.shared.save(
            image: capturedImage,
            category: category,
            caption: caption.isEmpty ? nil : caption,
            sourceURL: sourceURL
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    self.dismissAfterSave(message: "Salvato in \(category.displayName)")
                case .failure(let error):
                    self.showAlert(title: "Errore di salvataggio",
                                   message: self.detailedErrorMessage(error))
                }
            }
        }
    }

    /// Chiude il composer (e l'overlay anteprima) e mostra un toast sulla
    /// finestra principale, così resta visibile dopo il dismiss.
    private func dismissAfterSave(message: String) {
        let window = view.window
        window?.rootViewController?.dismiss(animated: true) {
            if let tab = window?.rootViewController as? MainTabBarController {
                tab.selectedIndex = 1   // Cattura
            }
            if let w = window {
                ToastView.show(message: message, in: w)
            }
        }
    }

    @objc private func handlePublish() {
        view.endEditing(true)
        setLoading(true)

        let caption = captionTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        PostService.shared.publish(image: capturedImage,
                                   caption: caption,
                                   sourceURL: sourceURL,
                                   author: cachedProfile) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    self.dismissAndReturnToCaptureTab()
                case .failure(let error):
                    self.showAlert(title: "Errore di pubblicazione",
                                   message: self.detailedErrorMessage(error))
                }
            }
        }
    }

    /// Chiude tutta la pila modale (PostVC + ScreenshotPreview overlay) e
    /// porta l'utente sulla tab Cattura.
    private func dismissAndReturnToCaptureTab() {
        let window = view.window
        // dismiss(animated:) sul root della finestra chiude TUTTI i modali sopra di esso
        window?.rootViewController?.dismiss(animated: true) {
            if let tab = window?.rootViewController as? MainTabBarController {
                tab.selectedIndex = 1   // Cattura
            }
        }
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        publishButton.isEnabled = !loading
        saveButton.isEnabled = !loading
        cancelButton.isEnabled = !loading
        captionTextView.isEditable = !loading
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    /// Estrae l'errore con il massimo livello di dettaglio possibile.
    /// L'NSError sotto a un Error Swift contiene `domain` + `code`
    /// (es. `FIRFirestoreErrorDomain` 7 = permission denied) che sono
    /// FONDAMENTALI per capire se è un problema di Security Rules
    /// invece di un generico "qualcosa è andato storto".
    private func detailedErrorMessage(_ error: Error) -> String {
        let ns = error as NSError
        var lines: [String] = [error.localizedDescription]
        lines.append("Codice: \(ns.domain) #\(ns.code)")
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("Causa: \(underlying.localizedDescription) (\(underlying.domain) #\(underlying.code))")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - UITextViewDelegate

extension PostViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        captionPlaceholder.isHidden = !textView.text.isEmpty
    }
}
