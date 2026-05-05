//
//  EditProfileViewController.swift
//  com.mattiaponcini.project
//
//  Schermata di modifica del profilo presentata in modale dal nuovo
//  Profilo (bottone "Modifica profilo" nell'header oppure dall'azione
//  "Modifica profilo" nel menu impostazioni).
//
//  Permette all'utente di:
//  - cambiare la foto profilo (UIImagePickerController, libreria foto)
//  - aggiornare la bio (UITextView con placeholder)
//
//  Salva via AuthService.updateProfile e notifica il caller con il
//  nuovo UserProfile aggiornato (foto + bio). Email/nome/cognome
//  restano in sola lettura: per ora non sono modificabili dall'app.
//

import UIKit

final class EditProfileViewController: UIViewController {

    // MARK: - Input

    private var profile: UserProfile
    private let onSave: (UserProfile) -> Void
    private var pickedImage: UIImage?

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

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamSurface
        iv.layer.cornerRadius = 56
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isUserInteractionEnabled = true
        return iv
    }()

    private let changePhotoButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Cambia foto profilo", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.tintColor = .Brand.goldPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let nameRow = ReadOnlyRow(label: "Nome")
    private let emailRow = ReadOnlyRow(label: "Email")

    private let bioContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamSurface
        v.layer.cornerRadius = 10
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let bioLabel: UILabel = {
        let l = UILabel()
        l.text = "Bio"
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bioTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let bioPlaceholder: UILabel = {
        let l = UILabel()
        l.text = "Racconta qualcosa di te…"
        l.font = .systemFont(ofSize: 16)
        l.textColor = .tertiaryLabel
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

    private var saveButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!

    // MARK: - Init

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Modifica profilo"
        setupNavBar()
        setupLayout()
        bioTextView.delegate = self
        populate()
    }

    // MARK: - Setup

    private func setupNavBar() {
        cancelButton = UIBarButtonItem(title: "Annulla", style: .plain,
                                       target: self, action: #selector(handleCancel))
        cancelButton.tintColor = .secondaryLabel
        saveButton = UIBarButtonItem(title: "Salva", style: .done,
                                     target: self, action: #selector(handleSave))
        saveButton.tintColor = .Brand.goldPrimary
        saveButton.setTitleTextAttributes([
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.Brand.goldPrimary
        ], for: .normal)
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.rightBarButtonItem = saveButton
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(changePhotoButton)
        contentView.addSubview(nameRow)
        contentView.addSubview(emailRow)
        contentView.addSubview(bioContainer)
        bioContainer.addSubview(bioLabel)
        bioContainer.addSubview(bioTextView)
        bioContainer.addSubview(bioPlaceholder)

        view.addSubview(activityIndicator)

        // Tap su avatar e bottone aprono il picker.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleChangePhoto))
        avatarImageView.addGestureRecognizer(tap)
        changePhotoButton.addTarget(self, action: #selector(handleChangePhoto), for: .touchUpInside)

        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            avatarImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 112),
            avatarImageView.heightAnchor.constraint(equalToConstant: 112),

            changePhotoButton.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 8),
            changePhotoButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            nameRow.topAnchor.constraint(equalTo: changePhotoButton.bottomAnchor, constant: 24),
            nameRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            nameRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            emailRow.topAnchor.constraint(equalTo: nameRow.bottomAnchor, constant: 16),
            emailRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            emailRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            bioContainer.topAnchor.constraint(equalTo: emailRow.bottomAnchor, constant: 24),
            bioContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bioContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            bioContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32),

            bioLabel.topAnchor.constraint(equalTo: bioContainer.topAnchor, constant: 12),
            bioLabel.leadingAnchor.constraint(equalTo: bioContainer.leadingAnchor, constant: 12),
            bioLabel.trailingAnchor.constraint(equalTo: bioContainer.trailingAnchor, constant: -12),

            bioTextView.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 8),
            bioTextView.leadingAnchor.constraint(equalTo: bioContainer.leadingAnchor, constant: 12),
            bioTextView.trailingAnchor.constraint(equalTo: bioContainer.trailingAnchor, constant: -12),
            bioTextView.bottomAnchor.constraint(equalTo: bioContainer.bottomAnchor, constant: -12),
            bioTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100),

            bioPlaceholder.topAnchor.constraint(equalTo: bioTextView.topAnchor),
            bioPlaceholder.leadingAnchor.constraint(equalTo: bioTextView.leadingAnchor),
            bioPlaceholder.trailingAnchor.constraint(equalTo: bioTextView.trailingAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Populate

    private func populate() {
        nameRow.value = profile.fullName
        emailRow.value = profile.email
        bioTextView.text = profile.bio
        bioPlaceholder.isHidden = !(profile.bio?.isEmpty ?? true)

        // Avatar — cache shared evita di ri-scaricare la stessa immagine
        // ad ogni apertura della pagina.
        guard let s = profile.photoURL, !s.isEmpty, let url = URL(string: s) else { return }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarImageView.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let image = image else { return }
            self?.avatarImageView.image = image
        }
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func handleChangePhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    @objc private func handleSave() {
        view.endEditing(true)
        setLoading(true)
        let trimmedBio = bioTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        AuthService.shared.updateProfile(
            bio: trimmedBio.isEmpty ? nil : trimmedBio,
            newPhoto: pickedImage
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success:
                    // Aggiorno il profilo locale e lo passo al caller. Per la
                    // photoURL non possiamo conoscere l'URL caricato senza
                    // rifetchare: chiediamo a AuthService di rileggere.
                    AuthService.shared.fetchCurrentUserProfile { fetched in
                        DispatchQueue.main.async {
                            if case let .success(p) = fetched {
                                self.profile = p
                                self.onSave(p)
                            } else {
                                // Fallback: aggiorna almeno la bio in locale.
                                self.profile.bio = trimmedBio.isEmpty ? nil : trimmedBio
                                self.onSave(self.profile)
                            }
                            self.dismiss(animated: true)
                        }
                    }
                case .failure(let error):
                    let alert = UIAlertController(title: "Errore",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        if loading { activityIndicator.startAnimating() } else { activityIndicator.stopAnimating() }
        saveButton.isEnabled = !loading
        cancelButton.isEnabled = !loading
        bioTextView.isEditable = !loading
        changePhotoButton.isEnabled = !loading
    }
}

// MARK: - UITextViewDelegate

extension EditProfileViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        bioPlaceholder.isHidden = !textView.text.isEmpty
    }
}

// MARK: - UIImagePickerControllerDelegate

extension EditProfileViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let chosen = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        if let img = chosen {
            pickedImage = img
            avatarImageView.image = img
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - ReadOnlyRow

/// Riga "label : value" in sola lettura per i campi nome/email che per
/// ora non sono modificabili dall'app.
private final class ReadOnlyRow: UIView {

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textColor = .label
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    var value: String? {
        get { valueLabel.text }
        set { valueLabel.text = newValue }
    }

    init(label: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = label
        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(separator)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            separator.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 8),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
