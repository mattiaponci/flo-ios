//
//  SearchDrawerViewController.swift
//  Flotip
//
//  Drawer di ricerca presentato dal feed (bottone lente affiancato a
//  "Esplora"). Full-screen con push iOS standard (entra da destra).
//
//  UI:
//    - top bar bianca con titolo "Cerca" + chiusura
//    - search field (live, debounce ~250ms)
//    - lista utenti (max 5 risultati) appena scrivi una lettera
//
//  Tap su un utente → apre PublicProfileViewController (con la stessa
//  transizione push iOS standard della famiglia chat/profilo).
//

import UIKit
import os.log

private let searchDrawerLog = OSLog(subsystem: "com.mattiaponcini.project", category: "SearchDrawerVC")

final class SearchDrawerViewController: UIViewController {

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

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.left",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
                   for: .normal)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Cerca"
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

    private let sectionLabel: UILabel = {
        let l = UILabel()
        l.text = "Utenti"
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
        l.text = "Scrivi un nome per cercare un utente."
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
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        view.addSubview(separator)

        view.addSubview(searchContainer)
        searchContainer.addSubview(searchIcon)
        searchContainer.addSubview(searchField)

        view.addSubview(sectionLabel)
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

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),

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

            sectionLabel.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 16),
            sectionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sectionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 4),
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
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(searchChanged),
                              for: .editingChanged)
    }

    // MARK: - Actions

    @objc private func handleBack() {
        // Mirror del push standard iOS: la VC sottostante riappare da sinistra,
        // mentre il drawer scivola FUORI verso destra.
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        dismiss(animated: false)
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
            updateEmptyState(active: false)
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
                    self.updateEmptyState(active: true)
                case .failure(let error):
                    os_log("searchUsers failed: %{public}@",
                           log: searchDrawerLog, type: .error, error.localizedDescription)
                    self.results = []
                    self.tableView.reloadData()
                    self.updateEmptyState(active: true)
                }
            }
        }
    }

    private func updateEmptyState(active: Bool) {
        if !active {
            emptyLabel.text = "Scrivi un nome per cercare un utente."
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

    // MARK: - Open public profile

    private func openPublicProfile(_ profile: UserProfile) {
        searchField.resignFirstResponder()
        let publicProfile = PublicProfileViewController(profile: profile)
        publicProfile.modalPresentationStyle = .fullScreen
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(publicProfile, animated: false)
    }
}

// MARK: - Table delegate/data source

extension SearchDrawerViewController: UITableViewDataSource, UITableViewDelegate {
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
        openPublicProfile(results[indexPath.row])
    }
}
