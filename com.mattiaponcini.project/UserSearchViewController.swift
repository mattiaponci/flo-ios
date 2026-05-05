//
//  UserSearchViewController.swift
//  Flotip
//
//  Modale di ricerca utenti generica. Top bar con search field, sotto
//  fino a 5 risultati live aggiornati ad ogni digitazione (debounce ~250ms).
//  Il chiamante riceve il `UserProfile` selezionato via `onUserSelected`
//  e decide cosa farne (creare chat, visitare profilo, ecc.).
//

import UIKit
import os.log

private let userSearchLog = OSLog(subsystem: "com.mattiaponcini.project", category: "UserSearchVC")

final class UserSearchViewController: UIViewController {

    // MARK: - Output

    var onUserSelected: ((UserProfile) -> Void)?

    // MARK: - State

    private var results: [UserProfile] = []
    private var pendingQueryWorkItem: DispatchWorkItem?
    private var lastIssuedQuery: String = ""

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
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Cerca utenti"
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
        t.placeholder = "Cerca un utente"
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
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "Cerca un nome per iniziare."
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        wireActions()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()
    }

    // MARK: - Layout

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

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UserSearchCell.self,
                           forCellReuseIdentifier: UserSearchCell.reuseID)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
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

            tableView.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 32),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func wireActions() {
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(searchChanged),
                              for: .editingChanged)
    }

    // MARK: - Actions

    @objc private func handleCancel() {
        dismiss(animated: true)
    }

    @objc private func searchChanged() {
        pendingQueryWorkItem?.cancel()
        let q = searchField.text ?? ""
        let work = DispatchWorkItem { [weak self] in
            self?.runSearch(query: q)
        }
        pendingQueryWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func runSearch(query: String) {
        lastIssuedQuery = query
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            tableView.reloadData()
            updateEmptyState(forActiveSearch: false)
            return
        }
        ChatService.shared.searchUsers(query: trimmed, limit: 5) {
            [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      self.lastIssuedQuery == query else { return }
                switch result {
                case .success(let users):
                    self.results = users
                    self.tableView.reloadData()
                    self.updateEmptyState(forActiveSearch: true)
                case .failure(let error):
                    os_log("searchUsers failed: %{public}@",
                           log: userSearchLog, type: .error, error.localizedDescription)
                    self.results = []
                    self.tableView.reloadData()
                    self.updateEmptyState(forActiveSearch: true)
                }
            }
        }
    }

    private func updateEmptyState(forActiveSearch active: Bool) {
        if !active {
            emptyLabel.text = "Cerca un nome per iniziare."
            emptyLabel.isHidden = false
            return
        }
        if results.isEmpty {
            emptyLabel.text = "Nessun utente trovato."
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true
        }
    }
}

// MARK: - Table delegate/data source

extension UserSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return results.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: UserSearchCell.reuseID, for: indexPath
        ) as! UserSearchCell
        cell.configure(profile: results[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let user = results[indexPath.row]
        onUserSelected?(user)
    }
}

// MARK: - UserSearchCell

final class UserSearchCell: UITableViewCell {
    static let reuseID = "UserSearchCell"

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

    private let emailLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var loadedURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(emailLabel)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            emailLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            emailLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = .Brand.goldSecondary
        loadedURL = nil
    }

    func configure(profile: UserProfile) {
        nameLabel.text = profile.fullName
        emailLabel.text = profile.email
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
