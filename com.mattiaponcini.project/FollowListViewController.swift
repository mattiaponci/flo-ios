//
//  FollowListViewController.swift
//  Flotip
//
//  Sheet presentato dal Profilo quando si tappa "Following" o "Followers".
//  Mostra la lista di profili (avatar + nome + handle) con tap → push del
//  profilo pubblico. Detent .medium / .large come gli altri sheet.
//
//  È volutamente semplice: i dati vengono passati pre-fetchati dal caller
//  oppure caricati una tantum chiamando `loader`. Nessun listener real-time
//  per evitare costi di lettura su liste potenzialmente lunghe.
//

import UIKit
import os.log

private let followListLog = OSLog(subsystem: "com.mattiaponcini.project", category: "FollowListVC")

final class FollowListViewController: UIViewController {

    // MARK: - Input

    /// Funzione async di caricamento: il VC la invoca al `viewDidLoad`
    /// e mostra spinner finché non ritorna.
    typealias Loader = (@escaping (Result<[UserProfile], Error>) -> Void) -> Void

    private let titleText: String
    private let loader: Loader

    // MARK: - State

    private var profiles: [UserProfile] = []
    private var isLoading: Bool = false { didSet { updateUIState() } }
    private var loadError: String? { didSet { updateUIState() } }

    // MARK: - UI

    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let separator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.separatorStyle = .none
        t.rowHeight = 64
        t.backgroundColor = .systemBackground
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .Brand.goldPrimary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    init(title: String, loader: @escaping Loader) {
        self.titleText = title
        self.loader = loader
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        titleLabel.text = titleText
        setupLayout()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FollowListCell.self, forCellReuseIdentifier: FollowListCell.reuseID)
        load()
    }

    private func setupLayout() {
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        view.addSubview(separator)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12),

            separator.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 24),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func load() {
        isLoading = true
        loadError = nil
        loader { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let profiles):
                    self.profiles = profiles
                    self.tableView.reloadData()
                    self.loadError = nil
                case .failure(let err):
                    os_log("FollowListVC load: %{public}@",
                           log: followListLog, type: .error, err.localizedDescription)
                    self.loadError = "Errore nel caricamento. Riprova più tardi."
                }
            }
        }
    }

    private func updateUIState() {
        if isLoading {
            activityIndicator.startAnimating()
            emptyLabel.isHidden = true
            return
        }
        activityIndicator.stopAnimating()
        if let err = loadError {
            emptyLabel.text = err
            emptyLabel.isHidden = false
            return
        }
        emptyLabel.isHidden = !profiles.isEmpty
        emptyLabel.text = "Nessun utente da mostrare."
    }
}

// MARK: - Data source / delegate

extension FollowListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profiles.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FollowListCell.reuseID,
                                                 for: indexPath) as! FollowListCell
        cell.configure(with: profiles[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let p = profiles[indexPath.row]
        let publicVC = PublicProfileViewController(profile: p)
        publicVC.modalPresentationStyle = .fullScreen
        // Dismiss del sheet, poi presentazione del profilo pubblico dal
        // root presenter, così la transizione push da destra è fluida.
        let presenter = self.presentingViewController
        self.dismiss(animated: true) {
            if let presenter = presenter, let window = presenter.view.window {
                let transition = CATransition()
                transition.duration = 0.30
                transition.type = .push
                transition.subtype = .fromRight
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.layer.add(transition, forKey: kCATransition)
            }
            presenter?.present(publicVC, animated: false)
        }
    }
}

// MARK: - FollowListCell

private final class FollowListCell: UITableViewCell {
    static let reuseID = "FollowListCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamSurface
        iv.layer.cornerRadius = 22
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
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

    private let handleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var lastPhotoURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(handleLabel)
        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -2),

            handleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            handleLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            handleLabel.topAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .Brand.goldSecondary
        lastPhotoURL = nil
    }

    func configure(with profile: UserProfile) {
        nameLabel.text = profile.fullName
        handleLabel.text = "@\(ProfileHandle.handle(for: profile))"
        loadAvatar(from: profile.photoURL)
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else { return }
        if lastPhotoURL == s, avatarImageView.image != nil { return }
        lastPhotoURL = s
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarImageView.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.lastPhotoURL == s,
                  let image = image else { return }
            self.avatarImageView.image = image
        }
    }
}
