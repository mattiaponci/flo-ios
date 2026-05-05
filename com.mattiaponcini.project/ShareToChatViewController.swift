//
//  ShareToChatViewController.swift
//  Flotip
//
//  Sheet di condivisione attivato dal paperplane sul feed.
//  Layout (richiesto UX):
//    - top bar bianca: titolo "Invia a" + chiusura
//    - search field per filtrare la lista
//    - lista delle persone che SEGUI (multi-select con checkbox)
//    - bottone "Invia (N)" in fondo, abilitato quando N ≥ 1
//
//  Al tap su Invia: per ogni utente selezionato, find-or-create della
//  conversazione 1-a-1 e share del post. Chiude lo sheet e mostra un
//  toast "Tip inviato". Il destinatario lo trova nella propria chat.
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let shareLog = OSLog(subsystem: "com.mattiaponcini.project", category: "ShareToChat")

final class ShareToChatViewController: UIViewController {

    // MARK: - Input

    private let postToShare: Post

    // MARK: - State

    /// Lista di profili che l'utente segue (cache locale).
    private var following: [UserProfile] = []
    /// Subset filtrato in base al testo della search bar.
    private var filtered: [UserProfile] = []
    /// UIDs attualmente selezionati per l'invio.
    private var selectedUids: Set<String> = []

    private var myProfile: UserProfile?
    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }

    // MARK: - UI

    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Annulla", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Invia a"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Wrapper "pillola crema" attorno alla search field.
    private let searchContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamSurface
        v.layer.cornerRadius = 10
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let searchIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iv.tintColor = .secondaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let searchField: UITextField = {
        let t = UITextField()
        t.placeholder = "Cerca tra chi segui"
        t.font = .systemFont(ofSize: 15)
        t.autocapitalizationType = .none
        t.autocorrectionType = .no
        t.clearButtonMode = .whileEditing
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.separatorStyle = .none
        t.rowHeight = 64
        t.keyboardDismissMode = .onDrag
        t.allowsMultipleSelection = true
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Invia", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = .Brand.goldPrimary
        b.setTitleColor(.white, for: .normal)
        b.tintColor = .white
        b.layer.cornerRadius = 12
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let sendActivity: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.color = .white
        a.hidesWhenStopped = true
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    // MARK: - Init

    init(post: Post) {
        self.postToShare = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        wireActions()
        loadMyProfile()
        loadFollowing()
        updateSendButton()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(topBar)
        topBar.addSubview(cancelButton)
        topBar.addSubview(titleLabel)
        view.addSubview(separator)

        view.addSubview(searchContainer)
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchField)

        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        view.addSubview(sendButton)
        sendButton.addSubview(sendActivity)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FollowingPickCell.self,
                           forCellReuseIdentifier: FollowingPickCell.reuseID)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // Top bar
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            cancelButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            cancelButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            separator.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            // Search
            searchContainer.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            searchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 40),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 12),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 16),
            searchIcon.heightAnchor.constraint(equalToConstant: 16),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            // Lista
            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: sendButton.topAnchor, constant: -12),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // Send button
            sendButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sendButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            sendButton.heightAnchor.constraint(equalToConstant: 50),

            sendActivity.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            sendActivity.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])
    }

    private func wireActions() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(handleSendAll), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(searchChanged),
                              for: .editingChanged)
    }

    // MARK: - Data load

    private func loadMyProfile() {
        AuthService.shared.fetchCurrentUserProfile { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let p) = result { self?.myProfile = p }
            }
        }
    }

    private func loadFollowing() {
        FollowService.shared.fetchMyFollowingProfiles { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let profiles):
                    self.following = profiles
                    self.applyFilter()
                case .failure(let error):
                    os_log("loadFollowing: %{public}@",
                           log: shareLog, type: .error, error.localizedDescription)
                    self.following = []
                    self.applyFilter()
                }
            }
        }
    }

    // MARK: - Search filter

    @objc private func searchChanged() {
        applyFilter()
    }

    private func applyFilter() {
        let q = (searchField.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if q.isEmpty {
            filtered = following
        } else {
            filtered = following.filter { p in
                p.fullName.lowercased().contains(q)
                    || p.firstName.lowercased().hasPrefix(q)
                    || p.lastName.lowercased().hasPrefix(q)
                    || p.email.lowercased().hasPrefix(q)
            }
        }
        tableView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        if following.isEmpty {
            emptyLabel.text = "Non segui ancora nessuno.\nApri Esplora → 🔍 e cerca una persona."
            emptyLabel.isHidden = false
        } else if filtered.isEmpty {
            emptyLabel.text = "Nessun risultato per \"\(searchField.text ?? "")\"."
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true
        }
    }

    // MARK: - Selection / Send button state

    private func updateSendButton() {
        let n = selectedUids.count
        let title = n == 0 ? "Invia" : "Invia (\(n))"
        sendButton.setTitle(title, for: .normal)
        sendButton.isEnabled = n > 0
        sendButton.alpha = n > 0 ? 1.0 : 0.45
    }

    // MARK: - Actions

    @objc private func handleCancel() { dismiss(animated: true) }

    /// Invia il post a tutti gli utenti selezionati. Per ognuno:
    /// find-or-create della conversazione 1-a-1 e share del post.
    @objc private func handleSendAll() {
        let recipients = following.filter { p in
            guard let id = p.id else { return false }
            return selectedUids.contains(id)
        }
        guard !recipients.isEmpty else { return }

        guard let me = myProfile else {
            // Profile non ancora caricato — fetch e riprova.
            AuthService.shared.fetchCurrentUserProfile { [weak self] result in
                DispatchQueue.main.async {
                    if case .success(let p) = result {
                        self?.myProfile = p
                        self?.handleSendAll()
                    }
                }
            }
            return
        }

        setSending(true)

        let group = DispatchGroup()
        var firstError: Error?
        let lock = NSLock()

        for recipient in recipients {
            group.enter()
            ChatService.shared.findOrCreateConversation(with: recipient, myProfile: me) {
                [weak self] result in
                switch result {
                case .failure(let err):
                    lock.lock(); if firstError == nil { firstError = err }; lock.unlock()
                    group.leave()
                case .success(let conv):
                    self?.shareTo(conv: conv) { shareResult in
                        if case .failure(let err) = shareResult {
                            lock.lock(); if firstError == nil { firstError = err }; lock.unlock()
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.setSending(false)
            if let err = firstError {
                os_log("share batch failed: %{public}@",
                       log: shareLog, type: .error, err.localizedDescription)
                let alert = UIAlertController(
                    title: "Errore",
                    message: "Alcuni invii non sono andati a buon fine.\n\n\(err.localizedDescription)",
                    preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else {
                let window = self.view.window
                self.dismiss(animated: true) {
                    if let window = window {
                        let n = recipients.count
                        let msg = n == 1 ? "Tip inviato" : "Tip inviato a \(n) persone"
                        ToastView.show(message: msg, in: window)
                    }
                }
            }
        }
    }

    private func shareTo(conv: Conversation,
                         completion: @escaping (Result<Void, Error>) -> Void) {
        ChatService.shared.share(post: postToShare, in: conv, completion: completion)
    }

    private func setSending(_ sending: Bool) {
        sendButton.isEnabled = !sending && !selectedUids.isEmpty
        sendButton.alpha = sendButton.isEnabled ? 1.0 : 0.45
        cancelButton.isEnabled = !sending
        searchField.isEnabled = !sending
        tableView.isUserInteractionEnabled = !sending
        if sending {
            sendButton.setTitle(nil, for: .normal)
            sendActivity.startAnimating()
        } else {
            sendActivity.stopAnimating()
            updateSendButton()
        }
    }
}

// MARK: - Table delegate/data source

extension ShareToChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return filtered.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: FollowingPickCell.reuseID, for: indexPath
        ) as! FollowingPickCell
        let profile = filtered[indexPath.row]
        let isSelected = profile.id.map { selectedUids.contains($0) } ?? false
        cell.configure(profile: profile, selected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        let profile = filtered[indexPath.row]
        guard let uid = profile.id else { return }
        if selectedUids.contains(uid) {
            selectedUids.remove(uid)
        } else {
            selectedUids.insert(uid)
        }
        tableView.reloadRows(at: [indexPath], with: .none)
        updateSendButton()
    }
}

// MARK: - FollowingPickCell

/// Riga "destinatario": avatar + nome + checkbox a destra (multi-select).
final class FollowingPickCell: UITableViewCell {
    static let reuseID = "FollowingPickCell"

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 22
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .Brand.creamSurface
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let checkbox: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private var loadedURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkbox)
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: checkbox.leadingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            checkbox.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkbox.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 26),
            checkbox.heightAnchor.constraint(equalToConstant: 26)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = .Brand.goldSecondary
        loadedURL = nil
    }

    func configure(profile: UserProfile, selected: Bool) {
        nameLabel.text = profile.fullName
        let cfg = UIImage.SymbolConfiguration(pointSize: 22,
                                              weight: selected ? .semibold : .regular)
        let symbol = selected ? "checkmark.circle.fill" : "circle"
        checkbox.image = UIImage(systemName: symbol, withConfiguration: cfg)
        checkbox.tintColor = selected ? .Brand.goldPrimary : .Brand.creamBorder
        loadAvatar(from: profile.photoURL)
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else { return }
        if loadedURL == s { return }
        loadedURL = s
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarView.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.loadedURL == s,
                  let image = image else { return }
            self.avatarView.image = image
        }
    }
}
