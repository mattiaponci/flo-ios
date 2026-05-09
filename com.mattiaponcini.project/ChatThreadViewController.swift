//
//  ChatThreadViewController.swift
//  Flotip
//
//  Singolo thread di chat 1-a-1: lista messaggi (bolle, mie a destra,
//  altro utente a sinistra) + input bar in basso. I messaggi che
//  contengono un "post condiviso" mostrano una preview compatta
//  cliccabile che apre PostDetailViewController.
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let chatThreadLog = OSLog(subsystem: "com.mattiaponcini.project", category: "ChatThreadVC")

final class ChatThreadViewController: UIViewController {

    // MARK: - Input

    private var conversation: Conversation
    private let myUid: String

    // MARK: - State

    private var messages: [ChatMessage] = []
    private var listener: ListenerRegistration?

    /// Stato della paginazione "scroll-up per messaggi più vecchi".
    /// `isLoadingOlder` evita più richieste sovrapposte mentre stiamo
    /// fetchando una pagina precedente. `hasReachedTop` viene impostato
    /// quando una pagina torna vuota (= storia esaurita) così smettiamo
    /// di chiamare Firestore ad ogni piccolo scroll vicino allo zero.
    private var isLoadingOlder = false
    private var hasReachedTop = false

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
        t.estimatedRowHeight = 60
        t.rowHeight = UITableView.automaticDimension
        t.keyboardDismissMode = .interactive
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let inputBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let inputContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamSurface
        v.layer.cornerRadius = 18
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let inputField: UITextField = {
        let t = UITextField()
        t.placeholder = "Scrivi un messaggio…"
        t.font = .systemFont(ofSize: 15)
        t.returnKeyType = .send
        t.translatesAutoresizingMaskIntoConstraints = false
        return t
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        b.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: cfg),
                   for: .normal)
        b.tintColor = .Brand.goldPrimary
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var inputBarBottomConstraint: NSLayoutConstraint!

    // MARK: - Init

    init(conversation: Conversation) {
        self.conversation = conversation
        self.myUid = Auth.auth().currentUser?.uid ?? ""
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        wireActions()
        observeKeyboard()
        startListening()

        titleLabel.text = conversation.otherName(currentUserId: myUid)
    }

    deinit {
        listener?.remove()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        view.addSubview(separator)

        view.addSubview(tableView)
        view.addSubview(inputBar)
        inputBar.addSubview(inputContainer)
        inputContainer.addSubview(inputField)
        inputBar.addSubview(sendButton)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChatTextCell.self,
                           forCellReuseIdentifier: ChatTextCell.reuseID)
        tableView.register(ChatSharedPostCell.self,
                           forCellReuseIdentifier: ChatSharedPostCell.reuseID)

        let safe = view.safeAreaLayoutGuide
        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(
            equalTo: safe.bottomAnchor)

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
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),

            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottomConstraint,
            inputBar.heightAnchor.constraint(equalToConstant: 56),

            inputContainer.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 16),
            inputContainer.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            inputContainer.heightAnchor.constraint(equalToConstant: 36),
            inputContainer.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            inputField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 14),
            inputField.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -14),
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),

            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func wireActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)
        inputField.addTarget(self, action: #selector(handleSend), for: .editingDidEndOnExit)
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                       name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(_:)),
                       name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                           as? NSValue)?.cgRectValue else { return }
        let overlap = max(0, view.bounds.height - frame.origin.y)
        let safeBottom = view.safeAreaInsets.bottom
        inputBarBottomConstraint.constant = overlap > 0 ? -(overlap - safeBottom) : 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        inputBarBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Listener

    private func startListening() {
        listener?.remove()
        guard let cid = conversation.id else { return }
        listener = ChatService.shared.observeMessages(conversationId: cid) {
            [weak self] msgs in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Il listener torna sempre l'ULTIMA pagina (limit toLast 50).
                // Se l'utente ha già scrollato indietro caricando pagine più
                // vecchie, queste vivono in `self.messages` PRIMA dei msgs
                // del listener. Le preserviamo facendo merge per id.
                self.mergeListenerPage(msgs)
                self.tableView.reloadData()
                self.scrollToBottom(animated: true)
            }
        }
    }

    /// Merge della pagina in arrivo dal listener (ultima pagina) con i
    /// messaggi più vecchi già caricati via `loadOlderMessages`. Dedup per
    /// id, ordinamento per createdAt crescente. Gestisce anche il caso
    /// "il messaggio era ottimistico" se in futuro lo aggiungiamo: l'id
    /// del server vince comunque sull'eventuale duplicato locale.
    private func mergeListenerPage(_ latestPage: [ChatMessage]) {
        // Copia la storia precedente (messaggi più vecchi del primo della
        // nuova pagina). Per identificare la cesura usiamo il createdAt
        // del primo msg della pagina; tutto ciò che è strettamente
        // precedente resta dalla cache locale.
        guard let firstNew = latestPage.first else {
            // Nessun messaggio dal listener: niente da fare (tieni la
            // cache così com'è). Non azzeriamo per evitare flicker.
            return
        }
        let older = self.messages.filter { $0.createdAt < firstNew.createdAt }
        var byId: [String: ChatMessage] = [:]
        for m in older + latestPage {
            if let id = m.id { byId[id] = m }
        }
        self.messages = byId.values.sorted { $0.createdAt < $1.createdAt }
    }

    /// Carica una pagina di messaggi più vecchi del primo attualmente in
    /// lista. Triggerato dallo scroll vicino al top in `scrollViewDidScroll`.
    /// Mantiene il content offset stabile post-prepend così l'utente non
    /// vede uno "scatto" quando le righe vecchie arrivano.
    private func loadOlderMessagesIfNeeded() {
        guard !isLoadingOlder, !hasReachedTop,
              let cid = conversation.id,
              let oldest = messages.first else { return }
        isLoadingOlder = true
        let oldestDate = oldest.createdAt

        ChatService.shared.loadOlderMessages(
            conversationId: cid,
            olderThan: oldestDate
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoadingOlder = false
                guard case .success(let older) = result, !older.isEmpty else {
                    if case .success(let older) = result, older.isEmpty {
                        self.hasReachedTop = true
                    }
                    return
                }
                // Salva l'offset corrente per ripristinarlo dopo l'insert.
                let oldContentHeight = self.tableView.contentSize.height
                let oldOffsetY = self.tableView.contentOffset.y

                self.messages = older + self.messages
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()

                // Ripristina la posizione visiva (offset = nuovo content
                // height - vecchio content height + offset precedente).
                let newContentHeight = self.tableView.contentSize.height
                self.tableView.setContentOffset(
                    CGPoint(x: 0, y: newContentHeight - oldContentHeight + oldOffsetY),
                    animated: false
                )
            }
        }
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let last = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    // MARK: - Actions

    @objc private func handleBack() {
        // Mirror della transizione di apertura (push iOS standard): in
        // uscita il thread scivola fuori verso destra, riportando in
        // primo piano da sinistra la lista chat (o il profilo pubblico).
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

    @objc private func handleSend() {
        guard let text = inputField.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let toSend = text
        inputField.text = ""
        ChatService.shared.sendText(toSend, in: conversation) { result in
            DispatchQueue.main.async {
                if case .failure(let error) = result {
                    os_log("sendText: %{public}@",
                           log: chatThreadLog, type: .error, error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Open shared post

    /// Single tap sulla card: apre il post a tutto schermo nel
    /// `PostDetailViewController` (stessa vista usata da feed/libreria, con
    /// chevron di dismiss in alto). Propaga la `sourceURL` dal payload
    /// così il fullscreen ha l'URL originale (anche se al momento il
    /// detail non lo usa, lo conserviamo per coerenza).
    fileprivate func openSharedPost(_ shared: SharedPostPayload) {
        let pseudo = Post(
            id: shared.postId,
            imageURL: shared.imageURL,
            sourceURL: shared.sourceURL,
            caption: shared.caption,
            authorId: shared.authorId,
            authorName: shared.authorName,
            authorPhotoURL: nil,
            createdAt: Date()
        )
        let detail = PostDetailViewController(post: pseudo)
        detail.modalPresentationStyle = .fullScreen
        present(detail, animated: true)
    }

    /// Double tap sulla card: cambia tab a Cattura e carica la `sourceURL`
    /// del messaggio nella WKWebView (stesso pattern di
    /// `FeedViewController.openSourceInCapture(post:)` e di
    /// `ProfileViewController.openSourceInCapture(post:)`). Se il payload
    /// non ha sourceURL (post legacy o messaggio condiviso prima
    /// dell'introduzione del campo) mostriamo un toast informativo.
    fileprivate func openSourceInCapture(_ shared: SharedPostPayload) {
        guard let urlString = shared.sourceURL,
              let url = URL(string: urlString) else {
            if let window = view.window {
                ToastView.show(message: "Nessuna sorgente disponibile",
                               in: window)
            }
            return
        }
        // Il thread è presentato modal-fullscreen, quindi non ha un
        // tabBarController in catena. Risaliamo direttamente al root
        // del window (lo stesso shortcut usato da PostViewController e
        // LibraryViewController per la stessa azione).
        guard let tab = view.window?.rootViewController as? MainTabBarController,
              let vcs = tab.viewControllers,
              vcs.count > 1,
              let screenshotVC = vcs[1] as? ScreenshotViewController else {
            return
        }
        // Chiudiamo il thread e poi facciamo selezionare la tab Cattura +
        // load dell'URL: in questo modo l'utente vede la pagina caricata,
        // non il fullscreen di chat sopra.
        dismiss(animated: true) {
            tab.selectedIndex = 1
            screenshotVC.loadURL(url)
        }
    }
}

// MARK: - Table delegate/data source

extension ChatThreadViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Threshold: quando il top dei contenuti è entro 200pt dal top del
        // viewport, chiediamo la pagina precedente. Soglia conservativa per
        // pre-fetchare prima che l'utente raggiunga lo zero assoluto.
        if scrollView.contentOffset.y < 200 {
            loadOlderMessagesIfNeeded()
        }
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let msg = messages[indexPath.row]
        let mine = msg.isMine(currentUserId: myUid)
        if let shared = msg.sharedPost {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatSharedPostCell.reuseID, for: indexPath
            ) as! ChatSharedPostCell
            cell.configure(shared: shared, mine: mine)
            // Single tap → fullscreen (PostDetailViewController).
            // Double tap → riapre la sourceURL nella tab Cattura.
            // La cella gestisce internamente `singleTap.require(toFail:
            // doubleTap)` per evitare che il single scatti prematuramente.
            cell.onSingleTap = { [weak self] in
                self?.openSharedPost(shared)
            }
            cell.onDoubleTap = { [weak self] in
                self?.openSourceInCapture(shared)
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: ChatTextCell.reuseID, for: indexPath
            ) as! ChatTextCell
            cell.configure(text: msg.text ?? "", mine: mine)
            return cell
        }
    }
}

// MARK: - ChatTextCell

final class ChatTextCell: UITableViewCell {
    static let reuseID = "ChatTextCell"

    private let bubble: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var leadingC: NSLayoutConstraint!
    private var trailingC: NSLayoutConstraint!
    private var leadingMineFar: NSLayoutConstraint!
    private var trailingTheirFar: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(bubble)
        bubble.addSubview(textLbl)

        leadingC = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingC = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        leadingMineFar = bubble.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
        trailingTheirFar = bubble.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            textLbl.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            textLbl.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
            textLbl.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            textLbl.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String, mine: Bool) {
        textLbl.text = text
        if mine {
            bubble.backgroundColor = .Brand.goldPrimary
            textLbl.textColor = .white
            NSLayoutConstraint.deactivate([leadingC, trailingTheirFar])
            NSLayoutConstraint.activate([leadingMineFar, trailingC])
        } else {
            bubble.backgroundColor = .Brand.creamSurface
            textLbl.textColor = .label
            NSLayoutConstraint.deactivate([leadingMineFar, trailingC])
            NSLayoutConstraint.activate([leadingC, trailingTheirFar])
        }
    }
}

// MARK: - ChatSharedPostCell

final class ChatSharedPostCell: UITableViewCell {
    static let reuseID = "ChatSharedPostCell"

    /// Single tap sulla card → handler "apri fullscreen". Il single
    /// recognizer è configurato con `require(toFail:)` sul double, così
    /// non scatta finché iOS non ha escluso il secondo tap.
    var onSingleTap: (() -> Void)?
    /// Double tap → handler "apri sourceURL in Cattura".
    var onDoubleTap: (() -> Void)?

    // La card era una UIControl con target .touchUpInside; ora che ci
    // serve distinguere single vs double tap usiamo direttamente i
    // gesture recognizer (UIControl + gesture coesistono male:
    // touchUpInside scatta sempre al primo release, ignorando il
    // require(toFail:) tra recognizer). Resta una UIView normale.
    private let card: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        v.clipsToBounds = true
        v.isUserInteractionEnabled = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let thumb: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .Brand.creamSurface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let authorLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let captionLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var leadingC: NSLayoutConstraint!
    private var trailingC: NSLayoutConstraint!
    private var leadingMineFar: NSLayoutConstraint!
    private var trailingTheirFar: NSLayoutConstraint!

    private var loadedURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(card)
        card.addSubview(thumb)
        card.addSubview(authorLbl)
        card.addSubview(captionLbl)

        leadingC = card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingC = card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        leadingMineFar = card.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 60)
        trailingTheirFar = card.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -60)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 260),

            thumb.topAnchor.constraint(equalTo: card.topAnchor),
            thumb.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            thumb.heightAnchor.constraint(equalToConstant: 160),

            authorLbl.topAnchor.constraint(equalTo: thumb.bottomAnchor, constant: 8),
            authorLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            authorLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),

            captionLbl.topAnchor.constraint(equalTo: authorLbl.bottomAnchor, constant: 2),
            captionLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            captionLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            captionLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)
        ])

        // Tap gestures: single (fullscreen) e double (apri sourceURL in
        // Cattura). Stesso pattern di Profile/Library: single deve
        // attendere il fail del double per non scattare prematuramente.
        let singleTap = UITapGestureRecognizer(
            target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        let doubleTap = UITapGestureRecognizer(
            target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        card.addGestureRecognizer(singleTap)
        card.addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumb.image = nil
        loadedURL = nil
        onSingleTap = nil
        onDoubleTap = nil
    }

    @objc private func handleSingleTap() { onSingleTap?() }
    @objc private func handleDoubleTap() { onDoubleTap?() }

    func configure(shared: SharedPostPayload, mine: Bool) {
        authorLbl.text = "@\(shared.authorName)"
        captionLbl.text = shared.caption.isEmpty ? "—" : shared.caption

        if mine {
            card.backgroundColor = .Brand.goldPrimary.withAlphaComponent(0.15)
            authorLbl.textColor = .label
            captionLbl.textColor = .secondaryLabel
            NSLayoutConstraint.deactivate([leadingC, trailingTheirFar])
            NSLayoutConstraint.activate([leadingMineFar, trailingC])
        } else {
            card.backgroundColor = .Brand.creamSurface
            authorLbl.textColor = .label
            captionLbl.textColor = .secondaryLabel
            NSLayoutConstraint.deactivate([leadingMineFar, trailingC])
            NSLayoutConstraint.activate([leadingC, trailingTheirFar])
        }
        loadThumb(from: shared.imageURL)
    }

    private func loadThumb(from urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        loadedURL = urlString
        if let cached = ImageCache.shared.cachedImage(for: url) {
            thumb.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.loadedURL == urlString,
                  let image = image else { return }
            self.thumb.image = image
        }
    }
}
