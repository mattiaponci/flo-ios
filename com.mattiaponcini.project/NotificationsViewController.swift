//
//  NotificationsViewController.swift
//  Flotip
//
//  Tab "Notifiche" del LibraryHostViewController. Mostra full-screen la
//  lista verticale delle richieste di follow ricevute pending. Ogni
//  riga è una card con avatar + nome + sottotitolo "vuole seguirti" +
//  due bottoni inline Accetta / Rifiuta.
//
//  Quando la lista è vuota mostra un placeholder centrato "Nessuna nuova
//  notifica" (stesso wording usato in `FollowRequestsRowView`).
//
//  Listener real-time su `FollowService.observePendingRequestProfiles`.
//  Tap sull'area avatar/nome → apre `PublicProfileViewController` con la
//  stessa transizione push-da-destra usata nel resto dell'app.
//
//  Logica di accept/reject identica a quella già usata in
//  `LibraryViewController` quando le richieste vivevano dentro il carosello
//  Notifiche: optimistic UI + rollback su errore + toast.
//

import UIKit
import FirebaseFirestore
import UserNotifications

final class NotificationsViewController: UIViewController {

    // MARK: - Data

    private var profiles: [UserProfile] = []
    private var listener: ListenerRegistration?

    // MARK: - UI

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.separatorStyle = .none
        t.backgroundColor = .clear
        t.rowHeight = UITableView.automaticDimension
        t.estimatedRowHeight = 96
        t.translatesAutoresizingMaskIntoConstraints = false
        t.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        return t
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "Nessuna nuova notifica"
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    private let refreshControl = UIRefreshControl()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(NotificationFollowRequestCell.self,
                           forCellReuseIdentifier: NotificationFollowRequestCell.reuseID)

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observeRequests()
        clearBadge()
    }

    /// Azzera il badge sull'icona dell'app. Rimuove anche le notifiche
    /// già consegnate dal Notification Center (quelle visibili nel cassetto
    /// delle notifiche di iOS) di tipo "followRequest", così l'utente
    /// non le rivede dopo averle già gestite qui.
    private func clearBadge() {
        // Rimuove tutte le notifiche deliverate dalla categoria followRequest.
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let ids = notifications
                .filter { ($0.request.content.userInfo["type"] as? String) == "followRequest" }
                .map { $0.request.identifier }
            if !ids.isEmpty {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            }
        }
        // Azzera il badge numerico sull'icona.
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
        listener = nil
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Data

    private func observeRequests() {
        listener?.remove()
        listener = FollowService.shared.observePendingRequestProfiles { [weak self] profiles in
            guard let self = self else { return }
            // Callback già su main.
            self.profiles = profiles
            self.tableView.reloadData()
            self.updateEmptyState()
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
    }

    @objc private func handleRefresh() {
        // Riavvia il listener: arriverà un nuovo snapshot.
        observeRequests()
        // Safety: se il listener non emette nuovamente entro 4s chiudiamo lo
        // spinner per non lasciarlo girare.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self else { return }
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
    }

    private func updateEmptyState() {
        emptyLabel.isHidden = !profiles.isEmpty
    }

    // MARK: - Actions

    private func handleAccept(_ profile: UserProfile) {
        guard let uid = profile.id, !uid.isEmpty else { return }
        let snapshot = profiles
        profiles.removeAll { $0.id == uid }
        tableView.reloadData()
        updateEmptyState()

        FollowService.shared.acceptFollowRequest(from: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case let .failure(err) = result {
                    self.profiles = snapshot
                    self.tableView.reloadData()
                    self.updateEmptyState()
                    if let window = self.view.window {
                        ToastView.show(message: "Impossibile accettare: \(err.localizedDescription)",
                                       in: window)
                    }
                }
            }
        }
    }

    private func handleReject(_ profile: UserProfile) {
        guard let uid = profile.id, !uid.isEmpty else { return }
        let snapshot = profiles
        profiles.removeAll { $0.id == uid }
        tableView.reloadData()
        updateEmptyState()

        FollowService.shared.rejectFollowRequest(from: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case let .failure(err) = result {
                    self.profiles = snapshot
                    self.tableView.reloadData()
                    self.updateEmptyState()
                    if let window = self.view.window {
                        ToastView.show(message: "Impossibile rifiutare: \(err.localizedDescription)",
                                       in: window)
                    }
                }
            }
        }
    }

    private func openPublicProfile(_ profile: UserProfile) {
        let vc = PublicProfileViewController(profile: profile)
        vc.modalPresentationStyle = .fullScreen
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(vc, animated: false)
    }
}

// MARK: - UITableView delegate/data source

extension NotificationsViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return profiles.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: NotificationFollowRequestCell.reuseID, for: indexPath
        ) as! NotificationFollowRequestCell
        let profile = profiles[indexPath.row]
        cell.configure(with: profile)
        cell.onAccept = { [weak self] in self?.handleAccept(profile) }
        cell.onReject = { [weak self] in self?.handleReject(profile) }
        // L'apertura del profilo è gestita da `didSelectRowAt`: UIKit
        // riconosce automaticamente quando il tap finisce su un UIButton
        // (Accetta/Rifiuta) e in quel caso NON chiama `didSelectRowAt`.
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openPublicProfile(profiles[indexPath.row])
    }
}

// MARK: - NotificationFollowRequestCell

/// Cella full-width con avatar + nome + sottotitolo + due bottoni inline.
/// Layout:
///   ┌──────────────────────────────────────────────────────────┐
///   │  ⚪⚪   Mattia Poncini                                     │
///   │  ⚪⚪   vuole seguirti                                     │
///   │                                                          │
///   │       [ Accetta ]    [ Rifiuta ]                         │
///   └──────────────────────────────────────────────────────────┘
final class NotificationFollowRequestCell: UITableViewCell {

    static let reuseID = "NotificationFollowRequestCell"

    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamBorder
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "vuole seguirti"
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let acceptButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Accetta", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.tintColor = .white
        b.backgroundColor = .Brand.goldPrimary
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let rejectButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Rifiuta", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(.label, for: .normal)
        b.tintColor = .label
        b.backgroundColor = .systemBackground
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private static let avatarSize: CGFloat = 52

    private var currentAvatarURL: URL?
    private var avatarTask: URLSessionDataTask?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        // Highlight grigio chiaro di default sul tap della cella: dà
        // feedback al tap su avatar/nome (apre il profilo via
        // `tableView(_:didSelectRowAt:)`). Quando si tocca un bottone
        // UIKit consuma il touch nel UIButton e `didSelectRowAt` NON
        // viene chiamato, quindi non c'è conflitto.
        selectionStyle = .default
        let bg = UIView()
        bg.backgroundColor = UIColor.label.withAlphaComponent(0.06)
        selectedBackgroundView = bg

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(acceptButton)
        contentView.addSubview(rejectButton)

        acceptButton.addTarget(self, action: #selector(handleAccept), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(handleReject), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 4),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            acceptButton.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            acceptButton.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12),
            acceptButton.heightAnchor.constraint(equalToConstant: 34),
            acceptButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            acceptButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),

            rejectButton.leadingAnchor.constraint(equalTo: acceptButton.trailingAnchor, constant: 10),
            rejectButton.centerYAnchor.constraint(equalTo: acceptButton.centerYAnchor),
            rejectButton.heightAnchor.constraint(equalToConstant: 34),
            rejectButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
            rejectButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
        ])

        avatarImageView.layer.cornerRadius = Self.avatarSize / 2
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .Brand.goldSecondary
        currentAvatarURL = nil
        avatarTask?.cancel()
        avatarTask = nil
        onAccept = nil
        onReject = nil
    }

    func configure(with profile: UserProfile) {
        let displayName = profile.fullName.trimmingCharacters(in: .whitespaces)
        nameLabel.text = displayName.isEmpty
            ? "@\(ProfileHandle.handle(for: profile))"
            : displayName
        loadAvatar(from: profile.photoURL)
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .Brand.goldSecondary
            currentAvatarURL = nil
            return
        }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarImageView.image = cached
            currentAvatarURL = url
            return
        }
        currentAvatarURL = url
        avatarTask = ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.currentAvatarURL == url,
                  let image = image else { return }
            self.avatarImageView.image = image
        }
    }

    @objc private func handleAccept() { onAccept?() }
    @objc private func handleReject() { onReject?() }
}
