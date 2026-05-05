//
//  LikersListViewController.swift
//  Flotip
//
//  Sheet presentato dal Feed quando l'utente tappa il contatore "like"
//  sotto il cuore di un post. Mostra la lista di chi ha messo like, con
//  avatar + nome + bottone Segui/Seguito (riusa FollowService).
//
//  Presentazione:
//    - UISheetPresentationController con detents [.medium, .large]
//    - grabber visibile, corner radius 24
//    - tap su una riga → push del profilo pubblico (PublicProfileViewController)
//
//  Lo sheet nasconde la tab bar dell'app sottostante (è modale).
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let likersLog = OSLog(subsystem: "com.mattiaponcini.project", category: "LikersListVC")

final class LikersListViewController: UIViewController {

    // MARK: - Input

    private let postId: String

    // MARK: - State

    private var likers: [UserProfile] = []
    private var isLoading: Bool = false {
        didSet { updateUIState() }
    }
    private var loadError: String? {
        didSet { updateUIState() }
    }

    // MARK: - UI

    /// Header con titolo "Mi piace" e contatore (es. "12 mi piace").
    private let headerView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Mi piace"
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
        l.text = "Nessun like ancora."
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    init(postId: String) {
        self.postId = postId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        setupUI()
        loadLikers()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(separator)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(emptyLabel)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LikerCell.self, forCellReuseIdentifier: LikerCell.reuseID)

        NSLayoutConstraint.activate([
            // Header in alto, sotto il grabber dello sheet (12pt di margine).
            headerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 32),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func updateUIState() {
        if isLoading {
            activityIndicator.startAnimating()
            emptyLabel.isHidden = true
        } else {
            activityIndicator.stopAnimating()
            if let err = loadError {
                emptyLabel.text = err
                emptyLabel.isHidden = false
            } else if likers.isEmpty {
                emptyLabel.text = "Nessun like ancora."
                emptyLabel.isHidden = false
            } else {
                emptyLabel.isHidden = true
            }
        }
    }

    private func updateTitleForCount(_ count: Int) {
        titleLabel.text = count == 0 ? "Mi piace" : "\(count) mi piace"
    }

    // MARK: - Data

    private func loadLikers() {
        isLoading = true
        loadError = nil
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let profiles = try await PostService.shared.fetchLikers(postId: self.postId)
                await MainActor.run {
                    self.likers = profiles
                    self.isLoading = false
                    self.updateTitleForCount(profiles.count)
                    self.tableView.reloadData()
                }
            } catch {
                os_log("fetchLikers: %{public}@",
                       log: likersLog, type: .error, error.localizedDescription)
                await MainActor.run {
                    self.loadError = "Impossibile caricare la lista."
                    self.isLoading = false
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - Open profile

    fileprivate func openProfile(_ profile: UserProfile) {
        // Per non infilare il push dentro lo sheet (che diventerebbe troppo
        // claustrofobico), dismissiamo lo sheet e lasciamo che il presenter
        // (FeedViewController) presenti il PublicProfileViewController dopo.
        let presenter = self.presentingViewController
        dismiss(animated: true) {
            guard let presenter = presenter else { return }
            let publicProfile = PublicProfileViewController(profile: profile)
            publicProfile.modalPresentationStyle = .fullScreen
            if let window = presenter.view.window {
                let transition = CATransition()
                transition.duration = 0.30
                transition.type = .push
                transition.subtype = .fromRight
                transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.layer.add(transition, forKey: kCATransition)
            }
            presenter.present(publicProfile, animated: false)
        }
    }
}

// MARK: - Table data source / delegate

extension LikersListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return likers.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: LikerCell.reuseID, for: indexPath
        ) as! LikerCell
        cell.configure(profile: likers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let profile = likers[indexPath.row]
        // Niente push se l'id manca: per sicurezza.
        guard profile.id != nil else { return }
        openProfile(profile)
    }
}

// MARK: - Liker cell

/// Riga della lista likers: avatar (circolare 44pt), nome, bottone Segui.
/// Il bottone Segui è nascosto se la riga rappresenta l'utente corrente.
final class LikerCell: UITableViewCell {
    static let reuseID = "LikerCell"

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

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Bottone Segui / Seguito. Compatto, gold per "Segui", outline per "Seguito".
    private let followButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.layer.cornerRadius = 14
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var loadedAvatarURL: String?
    private var profileUid: String?
    private var isFollowingState: Bool = false {
        didSet { applyFollowState() }
    }
    private var followInFlight: Bool = false
    private var followListener: ListenerRegistration?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .systemBackground

        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(followButton)

        followButton.addTarget(self,
                               action: #selector(handleFollowTap),
                               for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: followButton.leadingAnchor, constant: -8),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            followButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            followButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            followButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = .Brand.goldSecondary
        loadedAvatarURL = nil
        profileUid = nil
        isFollowingState = false
        followInFlight = false
        followButton.isHidden = false
        followListener?.remove()
        followListener = nil
    }

    deinit {
        followListener?.remove()
    }

    func configure(profile: UserProfile) {
        nameLabel.text = profile.fullName
        let bio = profile.bio?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bio.isEmpty {
            subtitleLabel.text = bio
        } else if let handle = profile.email.split(separator: "@").first.map(String.init), !handle.isEmpty {
            subtitleLabel.text = "@" + handle.lowercased()
        } else {
            subtitleLabel.text = nil
        }
        loadAvatar(from: profile.photoURL)

        let uid = profile.id ?? ""
        profileUid = uid

        // Nascondi il bottone segui se è l'utente corrente.
        let myUid = Auth.auth().currentUser?.uid ?? ""
        if uid.isEmpty || uid == myUid {
            followButton.isHidden = true
            followListener?.remove()
            followListener = nil
            return
        }

        followButton.isHidden = false
        // Default visivo finché non arriva il primo snapshot.
        isFollowingState = false

        followListener?.remove()
        followListener = FollowService.shared.observeIsFollowing(uid) { [weak self] isFollowing in
            guard let self = self,
                  self.profileUid == uid else { return }
            DispatchQueue.main.async {
                if !self.followInFlight {
                    self.isFollowingState = isFollowing
                }
            }
        }
    }

    private func applyFollowState() {
        if isFollowingState {
            followButton.setTitle("Seguito", for: .normal)
            followButton.setTitleColor(.label, for: .normal)
            followButton.backgroundColor = .Brand.creamSurface
            followButton.layer.borderColor = UIColor.Brand.creamBorder.cgColor
            followButton.layer.borderWidth = 1
        } else {
            followButton.setTitle("Segui", for: .normal)
            followButton.setTitleColor(.white, for: .normal)
            followButton.backgroundColor = .Brand.goldPrimary
            followButton.layer.borderWidth = 0
        }
    }

    @objc private func handleFollowTap() {
        guard let uid = profileUid, !uid.isEmpty, !followInFlight else { return }
        followInFlight = true

        // Update ottimistico immediato.
        let previous = isFollowingState
        let next = !previous
        isFollowingState = next

        let onCompletion: (Result<Void, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      self.profileUid == uid else { return }
                self.followInFlight = false
                if case .failure = result {
                    // Revert visivo: il listener la corregge comunque entro
                    // pochi ms se arriva un altro snapshot.
                    self.isFollowingState = previous
                }
            }
        }

        if next {
            FollowService.shared.follow(uid, completion: onCompletion)
        } else {
            FollowService.shared.unfollow(uid, completion: onCompletion)
        }
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else { return }
        if loadedAvatarURL == s { return }
        loadedAvatarURL = s
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarView.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.loadedAvatarURL == s,
                  let image = image else { return }
            self.avatarView.image = image
        }
    }
}

