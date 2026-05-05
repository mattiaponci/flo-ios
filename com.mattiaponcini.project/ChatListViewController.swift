//
//  ChatListViewController.swift
//  Flotip
//
//  Schermata "Chat" presentata in modale full-screen con transizione
//  push iOS standard (la lista scivola dentro dal lato destro dello
//  schermo). Apribile sia dal Profilo (bottone in alto a destra) sia
//  dal bottone "Messaggia" sul profilo pubblico di un'altra persona
//  che si segue.
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let chatListLog = OSLog(subsystem: "com.mattiaponcini.project",
                                category: "ChatListVC")

final class ChatListViewController: UIViewController {

    // MARK: - State

    private var conversations: [Conversation] = []
    private var listener: ListenerRegistration?

    /// Conversation id che l'utente ha appena "eliminato" via swipe ma per
    /// cui il nostro filtro client su `hiddenFor` potrebbe non aver ancora
    /// visto lo snapshot aggiornato. Vengono escluse manualmente in
    /// `applySnapshot(...)` finché Firestore non conferma.
    private var pendingDeletions: Set<String> = []

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var myProfile: UserProfile?

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
        l.text = "Chat"
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

    private let tableView: UITableView = {
        let t = UITableView(frame: .zero, style: .plain)
        t.separatorStyle = .none
        t.rowHeight = 72
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "Nessuna conversazione.\nTorna al feed e tocca la 🔍 in alto a destra per cercare un utente e iniziare una chat."
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.numberOfLines = 0
        l.textAlignment = .center
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        wireActions()
        startListening()
        loadMyProfile()
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        view.addSubview(separator)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ConversationCell.self,
                           forCellReuseIdentifier: ConversationCell.reuseID)

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

            tableView.topAnchor.constraint(equalTo: separator.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func wireActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }

    // MARK: - Data

    private func loadMyProfile() {
        AuthService.shared.fetchCurrentUserProfile { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let p) = result { self?.myProfile = p }
            }
        }
    }

    private func startListening() {
        listener?.remove()
        listener = ChatService.shared.observeConversations { [weak self] convs in
            DispatchQueue.main.async {
                self?.applySnapshot(convs)
            }
        }
    }

    /// Applica uno snapshot del listener filtrando le conversazioni
    /// ancora in stato di "cancellazione optimistic in corso", così il
    /// toggle visivo non viene annullato da un eventuale snapshot in
    /// arrivo prima che Firestore confermi la write su `hiddenFor`.
    /// Idempotente: chiamarlo ripetutamente con lo stesso input non
    /// produce flicker visibile (è un `reloadData`).
    private func applySnapshot(_ convs: [Conversation]) {
        let visible = convs.filter { conv in
            guard let id = conv.id, !id.isEmpty else { return true }
            return !pendingDeletions.contains(id)
        }
        conversations = visible
        tableView.reloadData()
        emptyLabel.isHidden = !conversations.isEmpty
    }

    // MARK: - Actions

    @objc private func handleBack() {
        // Mirror della transizione di apertura (push iOS standard): in
        // uscita la lista scivola fuori verso destra mentre la VC
        // sottostante rientra da sinistra.
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

}

// MARK: - Table delegate/data source

extension ChatListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: ConversationCell.reuseID, for: indexPath
        ) as! ConversationCell
        let conv = conversations[indexPath.row]
        cell.configure(conversation: conv, currentUid: myUid)
        return cell
    }

    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conv = conversations[indexPath.row]
        let thread = ChatThreadViewController(conversation: conv)
        thread.modalPresentationStyle = .fullScreen
        // Apertura ChatThread con transizione push iOS standard (la VC
        // scivola dentro dal lato destro dello schermo), coerente con
        // il resto della navigazione (es. search dal feed). Senza questo
        // CATransition `present(...)` userebbe il default `.coverVertical`
        // facendo entrare la chat dal basso. Lo specchio in uscita è
        // gestito da ChatThreadViewController.handleBack (push fromLeft).
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(thread, animated: false)
    }

    // MARK: - Swipe-to-delete

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        guard indexPath.row < conversations.count else { return nil }
        let conv = conversations[indexPath.row]

        let action = UIContextualAction(style: .destructive,
                                        title: "Elimina") { [weak self] _, _, done in
            self?.confirmDelete(conversation: conv, completion: done)
        }
        action.backgroundColor = .systemRed
        action.image = UIImage(systemName: "trash")

        let cfg = UISwipeActionsConfiguration(actions: [action])
        cfg.performsFirstActionWithFullSwipe = false
        return cfg
    }

    /// Mostra l'alert di conferma. Alla conferma rimuove **subito** la
    /// riga dalla tableView (cancellazione ottimistica) e poi scrive
    /// `hiddenFor` su Firestore in background. Se il write fallisce
    /// re-inserisce la riga e mostra un alert d'errore. Lo snapshot
    /// successivo del listener resta idempotente perché `applySnapshot`
    /// filtra i `pendingDeletions`.
    private func confirmDelete(conversation conv: Conversation,
                                completion: @escaping (Bool) -> Void) {
        let name = conv.otherName(currentUserId: myUid)
        let alert = UIAlertController(
            title: "Eliminare la chat con \(name)?",
            message: "L'operazione non si può annullare.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel) { _ in
            completion(false)
        })
        let delete = UIAlertAction(title: "Elimina", style: .destructive) {
            [weak self] _ in
            guard let self = self, let cid = conv.id, !cid.isEmpty else {
                completion(false)
                return
            }

            // 1) Optimistic UI: rimuovi subito la riga dal modello e dalla
            //    table view. Senza questa rimozione visiva l'utente
            //    vedrebbe la cella restare a schermo finché Firestore non
            //    rimanda lo snapshot (potenzialmente molti secondi su
            //    rete lenta), che è esattamente il bug riportato.
            guard let row = self.conversations.firstIndex(where: { $0.id == cid }) else {
                // La riga non è più nella nostra lista (es. snapshot già
                // arrivato): non c'è nulla di optimistico da fare, manda
                // la write e basta.
                completion(true)
                ChatService.shared.deleteConversation(cid: cid) { _ in }
                return
            }
            let snapshot = self.conversations[row]
            self.pendingDeletions.insert(cid)
            self.conversations.remove(at: row)
            self.tableView.deleteRows(
                at: [IndexPath(row: row, section: 0)],
                with: .left
            )
            self.emptyLabel.isHidden = !self.conversations.isEmpty
            // Chiudi subito lo swipe action.
            completion(true)

            // 2) Write Firestore in background. Rollback su errore.
            ChatService.shared.deleteConversation(cid: cid) {
                [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .success:
                        // Conferma. Lasciamo che il listener riallinei la
                        // lista al prossimo snapshot — `applySnapshot` è
                        // idempotente. Rimuoviamo da pendingDeletions per
                        // non far crescere il set indefinitamente.
                        self.pendingDeletions.remove(cid)
                    case .failure(let err):
                        os_log("deleteConversation: %{public}@",
                               log: chatListLog, type: .error,
                               err.localizedDescription)
                        // Rollback UI: re-inserisci la conversation se non
                        // è già tornata dallo snapshot listener.
                        self.pendingDeletions.remove(cid)
                        if !self.conversations.contains(where: { $0.id == cid }) {
                            let insertAt = min(row, self.conversations.count)
                            self.conversations.insert(snapshot, at: insertAt)
                            self.tableView.insertRows(
                                at: [IndexPath(row: insertAt, section: 0)],
                                with: .left
                            )
                            self.emptyLabel.isHidden = !self.conversations.isEmpty
                        }
                        let errAlert = UIAlertController(
                            title: "Errore",
                            message: "Impossibile eliminare la chat. Riprova.",
                            preferredStyle: .alert
                        )
                        errAlert.addAction(UIAlertAction(title: "OK",
                                                         style: .default))
                        self.present(errAlert, animated: true)
                    }
                }
            }
        }
        alert.addAction(delete)
        present(alert, animated: true)
    }
}

// MARK: - ConversationCell

final class ConversationCell: UITableViewCell {
    static let reuseID = "ConversationCell"

    private let avatarView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 26
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
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let lastMessageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .tertiaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var loadedURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lastMessageLabel)
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 52),
            avatarView.heightAnchor.constraint(equalToConstant: 52),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            lastMessageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            lastMessageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            lastMessageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarView.tintColor = .Brand.goldSecondary
        loadedURL = nil
    }

    func configure(conversation: Conversation, currentUid: String) {
        nameLabel.text = conversation.otherName(currentUserId: currentUid)
        let preview = conversation.lastMessage
        lastMessageLabel.text = preview.isEmpty ? "Inizia la conversazione…" : preview
        timeLabel.text = relativeTime(conversation.updatedAt)
        loadAvatar(from: conversation.otherPhotoURL(currentUserId: currentUid))
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "ora" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))g" }
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        return f.string(from: date)
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
