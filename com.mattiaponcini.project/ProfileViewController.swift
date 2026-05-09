//
//  ProfileViewController.swift
//  com.mattiaponcini.project
//
//  Schermata Profilo riprogettata in stile TikTok:
//
//   ┌────────────────────────────────────────────────┐
//   │ [⚙]                                  [💬]      │  custom nav bar
//   │                                                │
//   │                  ⚪⚪⚪                         │  avatar centrato (anello oro)
//   │                  ⚪⚪⚪
//   │                                                │
//   │                @mattiap                        │  handle
//   │             Mattia Poncini                     │  nome completo
//   │           bio del profilo, multi-line          │  bio centrata
//   │                                                │
//   │     12        4         128                    │  3 stat row
//   │  Following  Followers  Likes                   │
//   │                                                │
//   │  [ Modifica profilo ] [ Condividi ] [+]        │  CTA primary + secondary + add
//   │                                                │
//   │  ┌──┬──┬──┐                                    │
//   │  │9 │16│  │   griglia 3 colonne, gap 1pt       │
//   │  │: │  │  │   ratio 9:16 (TikTok-style)        │
//   │  ├──┼──┼──┤                                    │
//   │  │ ▶       │                                   │  copertina dei salvati
//   │  └──┴──┴──┘                                    │
//   └────────────────────────────────────────────────┘
//
//  Composizione: UICollectionViewCompositionalLayout con due sezioni:
//    - Sezione 0: header info (avatar/handle/nome/bio/stat/CTA), 0 items.
//    - Sezione 1: griglia 3 colonne 9:16 dei POST pubblicati dall'utente
//      (collection `posts` filtrata per `authorId == currentUid`, ordine
//      `createdAt desc`). Le copertine sono i post che l'utente ha
//      condiviso sul feed, mirror di quanto mostrato nel profilo pubblico.
//      Il tab segmented (post / privati / salvati) è stato rimosso: i
//      contenuti privati / salvati restano accessibili dalla Libreria.
//
//  Tap sulla griglia:
//    - Single tap → apre il `PostDetailViewController` con il post
//      selezionato (push da destra con CATransition).
//    - Double tap → apre la `sourceURL` del post nella tab Cattura
//      (riusa il pattern di FeedViewController: cambia tab e chiama
//      `screenshotVC.loadURL(...)`).
//
//  Listener real-time: posts dell'utente loggato (Firestore listener su
//  `posts where authorId == uid`), follower/following count
//  (via FollowService.observeFollowersCount / observeFollowingCount).
//  Total likes: lettura one-shot al `viewWillAppear` e al pull-to-refresh.
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let profileLog = OSLog(subsystem: "com.mattiaponcini.project", category: "ProfileVC")

// MARK: - Helper: handle TikTok-style

/// Genera un "@handle" TikTok-style a partire dal profilo. Per ora la fonte
/// è l'email (parte prima della @) oppure firstName.lastName lowercased se
/// l'email non c'è. Ogni carattere non `[a-z0-9._]` viene rimosso.
enum ProfileHandle {
    static func handle(for profile: UserProfile) -> String {
        let raw: String
        let emailLocal = profile.email.split(separator: "@").first.map(String.init) ?? ""
        if !emailLocal.isEmpty {
            raw = emailLocal
        } else {
            let f = profile.firstName.trimmingCharacters(in: .whitespaces)
            let l = profile.lastName.trimmingCharacters(in: .whitespaces)
            if f.isEmpty && l.isEmpty {
                raw = "utente"
            } else if l.isEmpty {
                raw = f
            } else {
                raw = "\(f).\(l)"
            }
        }
        let lowered = raw.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._")
        let scrubbed = lowered.unicodeScalars
            .filter { allowed.contains($0) }
            .map { String($0) }
            .joined()
        return scrubbed.isEmpty ? "utente" : scrubbed
    }

    /// Formatta un contatore in forma compatta ("1.2k", "12.3k", "1.5M").
    static func compactCount(_ n: Int) -> String {
        if n < 1_000 { return "\(n)" }
        if n < 1_000_000 {
            let v = Double(n) / 1_000.0
            return String(format: v < 10 ? "%.1fk" : "%.0fk", v)
        }
        let v = Double(n) / 1_000_000.0
        return String(format: v < 10 ? "%.1fM" : "%.0fM", v)
    }
}

// MARK: - ProfileViewController

final class ProfileViewController: UIViewController {

    // MARK: - State

    private var profile: UserProfile?
    /// Post pubblicati dall'utente loggato (collection `posts` filtrata per
    /// `authorId == currentUid`, ordinati `createdAt desc`). Sono ciò che
    /// la griglia mostra: i propri post sul feed.
    private var posts: [Post] = []
    private var followersCount: Int? = nil
    private var followingCount: Int? = nil
    private var totalLikes: Int? = nil

    private var postsListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?

    private var profileLoadToken: UUID?
    private var likesLoadToken: UUID?

    // MARK: - UI

    /// Custom nav bar: chat a sinistra, "Profilo" centrato, gear a destra.
    private let topBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        return v
    }()

    private let topBarTitle: UILabel = {
        let l = UILabel()
        l.text = "Profilo"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let chatButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "bubble.left.and.bubble.right",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)),
                   for: .normal)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let settingsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "gearshape",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular)),
                   for: .normal)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let topBarSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Collection view con due sezioni:
    /// - sezione 0: solo l'info header (0 items)
    /// - sezione 1: griglia 9:16 + tab bar sticky come supplementary header
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .Brand.goldPrimary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let errorContainer: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.alignment = .center
        s.isHidden = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let errorLabel: UILabel = {
        let lbl = UILabel()
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = .Brand.danger
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let retryButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Riprova", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        btn.tintColor = .Brand.goldPrimary
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    /// Empty state overlay mostrato in centro quando l'utente non ha
    /// ancora alcun contenuto salvato. Vive sopra la collection view in
    /// foreground, così non si scrolla via.
    private let emptyOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let emptyIcon: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyTitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptySubtitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Layout kinds

    static let infoHeaderKind = "ProfileInfoHeaderKind"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTopBar()
        setupCollectionView()
        setupErrorViews()
        setupEmptyOverlay()
        setupRefreshControl()
        chatButton.addTarget(self, action: #selector(handleChat), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(handleSettings), for: .touchUpInside)
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProfile()
        startObservingPosts()
        startObservingFollow()
        refreshTotalLikes()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Chiudiamo i listener Firestore quando l'utente lascia la tab.
        postsListener?.remove(); postsListener = nil
        followersListener?.remove(); followersListener = nil
        followingListener?.remove(); followingListener = nil
    }

    deinit {
        postsListener?.remove()
        followersListener?.remove()
        followingListener?.remove()
    }

    // MARK: - Layout

    private func setupTopBar() {
        view.addSubview(topBar)
        topBar.addSubview(topBarTitle)
        topBar.addSubview(chatButton)
        topBar.addSubview(settingsButton)
        view.addSubview(topBarSeparator)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            topBarTitle.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            topBarTitle.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            // Swap intenzionale: ingranaggio (impostazioni) a SINISTRA,
            // chat a DESTRA. Cambia rispetto al vecchio layout TikTok-like
            // ma è il pattern desiderato per Flotip.
            settingsButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            settingsButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),

            chatButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            chatButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            chatButton.widthAnchor.constraint(equalToConstant: 32),
            chatButton.heightAnchor.constraint(equalToConstant: 32),

            topBarSeparator.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            topBarSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarSeparator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    private func setupCollectionView() {
        let layout = makeCompositionalLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ProfileTikTokGridCell.self,
                                forCellWithReuseIdentifier: ProfileTikTokGridCell.reuseID)
        collectionView.register(ProfileInfoHeaderView.self,
                                forSupplementaryViewOfKind: Self.infoHeaderKind,
                                withReuseIdentifier: ProfileInfoHeaderView.reuseID)
        collectionView.contentInsetAdjustmentBehavior = .never
        view.addSubview(collectionView)

        // Tap gestures: distinguiamo single tap (apre PostDetail fullscreen)
        // da double tap (apre la sourceURL nella tab Cattura). Il single
        // aspetta il fail del double per non scattare prematuramente.
        // `cancelsTouchesInView = false` lascia funzionare scroll/refresh.
        let singleTap = UITapGestureRecognizer(target: self,
                                               action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.cancelsTouchesInView = false
        let doubleTap = UITapGestureRecognizer(target: self,
                                               action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        singleTap.require(toFail: doubleTap)
        collectionView.addGestureRecognizer(singleTap)
        collectionView.addGestureRecognizer(doubleTap)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topBarSeparator.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// Layout: section 0 → info header (estimated ~480pt),
    /// section 1 → griglia 3-cols 9:16 dei post pubblicati dall'utente.
    /// Il vecchio tab bar segmented è stato rimosso: il profilo mostra
    /// solo i propri post; privati e salvati vivono nella Libreria.
    private func makeCompositionalLayout() -> UICollectionViewLayout {
        let infoHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(480)
            ),
            elementKind: Self.infoHeaderKind,
            alignment: .top
        )

        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            if sectionIndex == 0 {
                // Sezione info header: 0 items reali; teniamo un item "fantasma"
                // di altezza minima 0.0001 (UICollectionView richiede un group
                // valido anche se il datasource ritorna 0 items).
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(0.0001)
                ))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(0.0001)
                    ),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [infoHeader]
                return section
            } else {
                // Sezione griglia: 3 colonne, ratio 9:16 verticale.
                // Cell width = 1/3 del totale; cell height = width * 16/9.
                // Group height in fraction of width = (1/3) * (16/9) = 16/27.
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0/3.0),
                    heightDimension: .fractionalHeight(1.0)
                ))
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 0.5, leading: 0.5, bottom: 0.5, trailing: 0.5
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .fractionalWidth(16.0/27.0)
                    ),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
    }

    private func setupErrorViews() {
        view.addSubview(activityIndicator)
        view.addSubview(errorContainer)
        errorContainer.addArrangedSubview(errorLabel)
        errorContainer.addArrangedSubview(retryButton)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 24),

            errorContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupEmptyOverlay() {
        view.addSubview(emptyOverlay)
        emptyOverlay.addSubview(emptyIcon)
        emptyOverlay.addSubview(emptyTitle)
        emptyOverlay.addSubview(emptySubtitle)
        emptyOverlay.isHidden = true

        NSLayoutConstraint.activate([
            // L'overlay copre l'area sotto la barra (più o meno il punto in cui
            // la tab bar pinata si è fermata). Lo posizioniamo grossolanamente
            // a metà schermo: per la tab "Privati" è il pattern desiderato.
            emptyOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emptyOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),

            emptyIcon.topAnchor.constraint(equalTo: emptyOverlay.topAnchor),
            emptyIcon.centerXAnchor.constraint(equalTo: emptyOverlay.centerXAnchor),
            emptyIcon.widthAnchor.constraint(equalToConstant: 56),
            emptyIcon.heightAnchor.constraint(equalToConstant: 56),

            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 16),
            emptyTitle.leadingAnchor.constraint(equalTo: emptyOverlay.leadingAnchor),
            emptyTitle.trailingAnchor.constraint(equalTo: emptyOverlay.trailingAnchor),

            emptySubtitle.topAnchor.constraint(equalTo: emptyTitle.bottomAnchor, constant: 6),
            emptySubtitle.leadingAnchor.constraint(equalTo: emptyOverlay.leadingAnchor),
            emptySubtitle.trailingAnchor.constraint(equalTo: emptyOverlay.trailingAnchor),
            emptySubtitle.bottomAnchor.constraint(equalTo: emptyOverlay.bottomAnchor)
        ])
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = .Brand.goldPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    // MARK: - Profile load

    private func loadProfile() {
        if profile == nil {
            activityIndicator.startAnimating()
        }
        errorContainer.isHidden = true

        let token = UUID()
        profileLoadToken = token

        // Watchdog 15s: spinner si ferma sempre.
        let loadTimeout: TimeInterval = 15
        DispatchQueue.main.asyncAfter(deadline: .now() + loadTimeout) { [weak self] in
            guard let self = self,
                  self.profileLoadToken == token,
                  self.activityIndicator.isAnimating else { return }
            os_log("loadProfile: timeout %f s", log: profileLog, type: .error, loadTimeout)
            self.activityIndicator.stopAnimating()
            self.showLoadError("Caricamento profilo troppo lento. Verifica la connessione e che Firestore sia attivo.")
        }

        AuthService.shared.fetchCurrentUserProfile { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.profileLoadToken == token else { return }
                self.activityIndicator.stopAnimating()
                switch result {
                case .success(let p):
                    self.profile = p
                    self.errorContainer.isHidden = true
                    self.reloadHeader()
                case .failure(let error):
                    os_log("loadProfile: %{public}@",
                           log: profileLog, type: .error, error.localizedDescription)
                    self.showLoadError("Impossibile caricare il profilo: \(error.localizedDescription)")
                }
            }
        }
    }

    private func showLoadError(_ message: String) {
        errorLabel.text = message
        errorContainer.isHidden = false
    }

    @objc private func retryTapped() { loadProfile() }

    @objc private func handleRefresh() {
        loadProfile()
        refreshTotalLikes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    // MARK: - Listener real-time

    /// Listener real-time sui post pubblicati dall'utente loggato. Filtra
    /// `posts where authorId == currentUid` e ordina `createdAt desc`. Le
    /// copertine alimentate da questo snapshot vanno nella griglia.
    /// Stessa query usata da `PublicProfileViewController.startObservingPosts`,
    /// solo che qui l'`authorId` è il proprio uid.
    private func startObservingPosts() {
        postsListener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else {
            posts = []
            reloadAll()
            return
        }
        let db = Firestore.firestore()
        postsListener = db.collection("posts")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    os_log("posts listener error: %{public}@",
                           log: profileLog, type: .error, error.localizedDescription)
                    DispatchQueue.main.async {
                        self.posts = []
                        self.reloadAll()
                    }
                    return
                }
                let parsed: [Post] = snapshot?.documents.compactMap {
                    try? $0.data(as: Post.self)
                } ?? []
                DispatchQueue.main.async {
                    self.posts = parsed
                    self.reloadAll()
                }
            }
    }

    private func startObservingFollow() {
        followersListener?.remove()
        followingListener?.remove()
        guard let uid = Auth.auth().currentUser?.uid else { return }
        followersListener = FollowService.shared.observeFollowersCount(for: uid) { [weak self] n in
            DispatchQueue.main.async {
                self?.followersCount = n
                self?.reloadHeader()
            }
        }
        followingListener = FollowService.shared.observeFollowingCount(for: uid) { [weak self] n in
            DispatchQueue.main.async {
                self?.followingCount = n
                self?.reloadHeader()
            }
        }
    }

    /// Refresh manuale del totale like (somma su tutti i miei post).
    /// Lo lasciamo come one-shot per non aprire N listener; viene rifatto
    /// al pull-to-refresh e al `viewWillAppear`.
    private func refreshTotalLikes() {
        guard let uid = Auth.auth().currentUser?.uid else {
            totalLikes = 0
            reloadHeader()
            return
        }
        let token = UUID()
        likesLoadToken = token
        // "—" durante il loading (totalLikes nil)
        totalLikes = nil
        reloadHeader()

        PostService.shared.fetchTotalLikesCount(for: uid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.likesLoadToken == token else { return }
                switch result {
                case .success(let n):
                    self.totalLikes = n
                case .failure(let err):
                    NSLog("[ProfileVC] fetchTotalLikesCount error: \(err.localizedDescription)")
                    self.totalLikes = 0
                }
                self.reloadHeader()
            }
        }
    }

    // MARK: - Reload helpers

    private func reloadHeader() {
        // Aggiorniamo solo l'header info: l'invalidate fa ricalcolare l'altezza
        // estimata.
        if collectionView.numberOfSections > 0 {
            let visibleInfo = collectionView.supplementaryView(
                forElementKind: Self.infoHeaderKind,
                at: IndexPath(item: 0, section: 0)
            ) as? ProfileInfoHeaderView
            visibleInfo?.configure(with: makeHeaderModel())
        }
        // Reload soft per le tab (se mostriamo "Privati", la sezione 1 è vuota
        // ma serve comunque per la pinned tab bar).
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        updateEmptyOverlay()
    }

    private func reloadAll() {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        updateEmptyOverlay()
    }

    private func currentItems() -> Int {
        return posts.count
    }

    private func updateEmptyOverlay() {
        let isEmpty = currentItems() == 0
        emptyOverlay.isHidden = !isEmpty
        guard isEmpty else { return }
        // Unica sezione: post pubblicati. L'empty state riflette quella semantica.
        emptyIcon.image = UIImage(systemName: "square.grid.3x3",
                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .light))
        emptyTitle.text = "Nessun post pubblicato"
        emptySubtitle.text = "Pubblica uno screenshot dalla tab Cattura per vederlo qui."
    }

    private func makeHeaderModel() -> ProfileInfoHeaderView.Model {
        let p = profile
        let handle = p.map { ProfileHandle.handle(for: $0) } ?? "—"
        return ProfileInfoHeaderView.Model(
            profile: p,
            handle: handle,
            followingCount: followingCount,
            followersCount: followersCount,
            totalLikes: totalLikes
        )
    }

    // MARK: - Actions

    @objc private func handleChat() {
        let chat = ChatListViewController()
        chat.modalPresentationStyle = .fullScreen
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(chat, animated: false)
    }

    @objc private func handleSettings() {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Modifica profilo", style: .default) { [weak self] _ in
            self?.openEditProfile()
        })
        sheet.addAction(UIAlertAction(title: "Privacy", style: .default) { _ in
            // Placeholder
        })
        sheet.addAction(UIAlertAction(title: "Notifiche", style: .default) { _ in
            // Placeholder
        })
        sheet.addAction(UIAlertAction(title: "Esci dall'account", style: .destructive) { [weak self] _ in
            self?.confirmLogout()
        })
        sheet.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = settingsButton
            pop.sourceRect = settingsButton.bounds
        }
        present(sheet, animated: true)
    }

    private func confirmLogout() {
        let alert = UIAlertController(title: "Esci",
                                      message: "Vuoi davvero uscire dall'account?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        alert.addAction(UIAlertAction(title: "Esci", style: .destructive) { _ in
            try? AuthService.shared.logout()
        })
        present(alert, animated: true)
    }

    private func openEditProfile() {
        guard let profile = profile else { return }
        let vc = EditProfileViewController(profile: profile) { [weak self] updated in
            self?.profile = updated
            self?.reloadHeader()
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    // MARK: - Header callbacks

    fileprivate func handleFollowingTap() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let vc = FollowListViewController(title: "Seguiti") { completion in
            FollowService.shared.fetchFollowingProfiles(for: uid, completion: completion)
        }
        present(vc, animated: true)
    }

    fileprivate func handleFollowersTap() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let vc = FollowListViewController(title: "Follower") { completion in
            FollowService.shared.fetchFollowersProfiles(for: uid, completion: completion)
        }
        present(vc, animated: true)
    }

    fileprivate func handleLikesTap() {
        // Statico per ora: nessuna azione richiesta.
    }

    fileprivate func handleEditTap() { openEditProfile() }

    fileprivate func handleShareTap() {
        guard let p = profile else { return }
        let handle = ProfileHandle.handle(for: p)
        let text = "Seguimi su Flotip: @\(handle)"
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let pop = activity.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        present(activity, animated: true)
    }

    fileprivate func handleAddFriendsTap() {
        // Riusa la search utenti esistente; alla selezione apre il profilo pubblico.
        let search = UserSearchViewController()
        search.onUserSelected = { [weak self] picked in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                let publicVC = PublicProfileViewController(profile: picked)
                publicVC.modalPresentationStyle = .fullScreen
                if let window = self.view.window {
                    let transition = CATransition()
                    transition.duration = 0.30
                    transition.type = .push
                    transition.subtype = .fromRight
                    transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    window.layer.add(transition, forKey: kCATransition)
                }
                self.present(publicVC, animated: false)
            }
        }
        let nav = UINavigationController(rootViewController: search)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    // MARK: - Item open (single / double tap)

    /// Single tap su una cella della griglia: apre il post a tutto schermo
    /// in `PostDetailViewController`. Animazione di push da destra come
    /// fanno le altre apertura full-screen del profilo (es. handleChat).
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              indexPath.section == 1,
              indexPath.item < posts.count else { return }
        openPostDetail(posts[indexPath.item])
    }

    /// Double tap su una cella della griglia: cambia tab a Cattura e apre
    /// la `sourceURL` del post (stesso pattern di `FeedViewController.
    /// openSourceInCapture(post:)`). Se il post non ha una sorgente
    /// disponibile (legacy), mostriamo un toast di feedback.
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              indexPath.section == 1,
              indexPath.item < posts.count else { return }
        openSourceInCapture(post: posts[indexPath.item])
    }

    private func openPostDetail(_ post: Post) {
        let detail = PostDetailViewController(post: post)
        detail.modalPresentationStyle = .fullScreen
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(detail, animated: false)
    }

    private func openSourceInCapture(post: Post) {
        guard let urlString = post.sourceURL,
              let url = URL(string: urlString) else {
            // Post legacy senza URL salvato: feedback discreto.
            if let window = view.window {
                ToastView.show(message: "Nessuna sorgente disponibile", in: window)
            }
            return
        }
        guard let tab = self.tabBarController as? MainTabBarController,
              let vcs = tab.viewControllers,
              vcs.count > 1 else { return }
        tab.selectedIndex = 1
        if let screenshotVC = vcs[1] as? ScreenshotViewController {
            screenshotVC.loadURL(url)
        }
    }
}

// MARK: - DataSource / Delegate

extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return 0 }
        return currentItems()
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ProfileTikTokGridCell.reuseID,
            for: indexPath) as! ProfileTikTokGridCell
        // Unica sezione: griglia dei post pubblicati. Mostriamo l'overlay
        // play (stesso comportamento del profilo pubblico); il counter
        // like è nil per ora (caricarlo per ogni cella richiederebbe N
        // listener aggiuntivi).
        let post = posts[indexPath.item]
        // Grid 3-colonne: la thumb 1080px è abbondantemente sufficiente
        // (cella ~120pt × 3x = 360px richiesti). Risparmia banda Storage
        // sulle visite al profilo.
        cell.configure(imageURL: post.previewImageURL,
                       likesCount: nil,
                       showOverlay: true)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        // Solo l'info header rimane: il vecchio tab bar segmented è stato
        // rimosso, quindi non c'è più una seconda kind di supplementary.
        let view = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: ProfileInfoHeaderView.reuseID,
            for: indexPath) as! ProfileInfoHeaderView
        view.configure(with: makeHeaderModel())
        view.onFollowingTap = { [weak self] in self?.handleFollowingTap() }
        view.onFollowersTap = { [weak self] in self?.handleFollowersTap() }
        view.onLikesTap = { [weak self] in self?.handleLikesTap() }
        view.onEditTap = { [weak self] in self?.handleEditTap() }
        view.onShareTap = { [weak self] in self?.handleShareTap() }
        view.onAddFriendsTap = { [weak self] in self?.handleAddFriendsTap() }
        return view
    }

    // NB: `didSelectItemAt` è stato rimosso. Le selezioni sulla griglia
    // sono gestite dai due `UITapGestureRecognizer` aggiunti in
    // `setupCollectionView()` (single tap → PostDetail, double tap →
    // sorgente in Cattura).
}

// MARK: - ProfileInfoHeaderView

/// Header centrato in stile TikTok: avatar + handle + nome + bio +
/// 3 stat (Following / Followers / Likes) + 2 CTA + add-friends.
final class ProfileInfoHeaderView: UICollectionReusableView {

    static let reuseID = "ProfileInfoHeaderView"

    struct Model {
        var profile: UserProfile?
        var handle: String
        var followingCount: Int?
        var followersCount: Int?
        var totalLikes: Int?
    }

    // Callbacks
    var onFollowingTap: (() -> Void)?
    var onFollowersTap: (() -> Void)?
    var onLikesTap: (() -> Void)?
    var onEditTap: (() -> Void)?
    var onShareTap: (() -> Void)?
    var onAddFriendsTap: (() -> Void)?

    // MARK: - UI

    /// Anello dorato attorno all'avatar (stile Instagram story).
    private let avatarRing: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.borderWidth = 2.5
        v.layer.borderColor = UIColor.Brand.goldPrimary.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamSurface
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let handleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .Brand.goldPrimary
        l.textAlignment = .center
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bioLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let followingStat = TikTokStatButton(label: "Following")
    private let followersStat = TikTokStatButton(label: "Followers")
    private let likesStat     = TikTokStatButton(label: "Likes")

    /// Separatore verticale fra le stat.
    private let statSep1: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let statSep2: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let editButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Modifica profilo", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.backgroundColor = .Brand.goldPrimary
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let shareButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Condividi profilo", for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.backgroundColor = .Brand.creamSurface
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let addFriendsButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "person.badge.plus",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)),
                   for: .normal)
        b.tintColor = .label
        b.backgroundColor = .Brand.creamSurface
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // Ultima URL avatar caricata, per evitare di rifare il load quando il
    // configure() viene chiamato più volte con lo stesso profilo.
    private var lastPhotoURL: String?
    /// Task del download avatar in volo: lo cancelliamo quando il configure
    /// arriva con un nuovo URL diverso.
    private var avatarLoadTask: URLSessionDataTask?

    private static let avatarSize: CGFloat = 96

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        setupLayout()

        editButton.addTarget(self, action: #selector(handleEdit), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(handleShare), for: .touchUpInside)
        addFriendsButton.addTarget(self, action: #selector(handleAddFriends), for: .touchUpInside)

        followingStat.addTarget(self, action: #selector(handleFollowing), for: .touchUpInside)
        followersStat.addTarget(self, action: #selector(handleFollowers), for: .touchUpInside)
        likesStat.addTarget(self, action: #selector(handleLikes), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        addSubview(avatarRing)
        avatarRing.addSubview(avatarImageView)
        addSubview(handleLabel)
        addSubview(nameLabel)
        addSubview(bioLabel)

        // Riga stat: 3 colonne uguali con separatori verticali sottili.
        let statsRow = UIView()
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        statsRow.addSubview(followingStat)
        statsRow.addSubview(statSep1)
        statsRow.addSubview(followersStat)
        statsRow.addSubview(statSep2)
        statsRow.addSubview(likesStat)
        addSubview(statsRow)

        // Riga azioni: edit + share + addFriends
        let actionsRow = UIStackView(arrangedSubviews: [editButton, shareButton, addFriendsButton])
        actionsRow.axis = .horizontal
        actionsRow.spacing = 8
        actionsRow.alignment = .fill
        actionsRow.distribution = .fill
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionsRow)

        let ringSize = Self.avatarSize + 8

        NSLayoutConstraint.activate([
            // Avatar ring
            avatarRing.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            avatarRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: ringSize),
            avatarRing.heightAnchor.constraint(equalToConstant: ringSize),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarRing.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarRing.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            // Handle
            handleLabel.topAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 12),
            handleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            handleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            // Name
            nameLabel.topAnchor.constraint(equalTo: handleLabel.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            // Bio
            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            bioLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            bioLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),

            // Stats row
            statsRow.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 16),
            statsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            statsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statsRow.heightAnchor.constraint(equalToConstant: 48),

            followingStat.leadingAnchor.constraint(equalTo: statsRow.leadingAnchor),
            followingStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            followingStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),

            statSep1.leadingAnchor.constraint(equalTo: followingStat.trailingAnchor),
            statSep1.centerYAnchor.constraint(equalTo: statsRow.centerYAnchor),
            statSep1.widthAnchor.constraint(equalToConstant: 0.5),
            statSep1.heightAnchor.constraint(equalToConstant: 28),

            followersStat.leadingAnchor.constraint(equalTo: statSep1.trailingAnchor),
            followersStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            followersStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),
            followersStat.widthAnchor.constraint(equalTo: followingStat.widthAnchor),

            statSep2.leadingAnchor.constraint(equalTo: followersStat.trailingAnchor),
            statSep2.centerYAnchor.constraint(equalTo: statsRow.centerYAnchor),
            statSep2.widthAnchor.constraint(equalToConstant: 0.5),
            statSep2.heightAnchor.constraint(equalToConstant: 28),

            likesStat.leadingAnchor.constraint(equalTo: statSep2.trailingAnchor),
            likesStat.trailingAnchor.constraint(equalTo: statsRow.trailingAnchor),
            likesStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            likesStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),
            likesStat.widthAnchor.constraint(equalTo: followingStat.widthAnchor),

            // Actions row
            actionsRow.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: 16),
            actionsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionsRow.heightAnchor.constraint(equalToConstant: 36),

            // Add friends ha larghezza fissa (icona quadrata).
            addFriendsButton.widthAnchor.constraint(equalToConstant: 44),

            // Bottom: chiude l'altezza estimated del header.
            actionsRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        // Avatar tondo: cornerRadius dipende dalla size.
        avatarRing.layer.cornerRadius = (Self.avatarSize + 8) / 2
        avatarImageView.layer.cornerRadius = Self.avatarSize / 2

        // Edit + Share equally distributed; addFriends fissa.
        editButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        shareButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        editButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        shareButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    // MARK: - Configure

    func configure(with model: Model) {
        // Handle
        handleLabel.text = "@\(model.handle)"

        // Nome completo / bio
        if let p = model.profile {
            let name = p.fullName.trimmingCharacters(in: .whitespaces)
            nameLabel.text = name.isEmpty ? "Profilo" : name
            if let bio = p.bio, !bio.trimmingCharacters(in: .whitespaces).isEmpty {
                bioLabel.text = bio
                bioLabel.isHidden = false
            } else {
                bioLabel.text = nil
                bioLabel.isHidden = true
            }
            loadAvatar(from: p.photoURL)
        } else {
            nameLabel.text = " "
            bioLabel.text = nil
            bioLabel.isHidden = true
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        }

        // Stats: "—" se ancora nil (loading), formato compatto se grandi.
        followingStat.setValueText(model.followingCount.map(ProfileHandle.compactCount) ?? "—")
        followersStat.setValueText(model.followersCount.map(ProfileHandle.compactCount) ?? "—")
        likesStat.setValueText(model.totalLikes.map(ProfileHandle.compactCount) ?? "—")
    }

    // MARK: - Avatar load

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else {
            avatarLoadTask?.cancel()
            avatarLoadTask = nil
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .Brand.goldSecondary
            lastPhotoURL = nil
            return
        }
        if lastPhotoURL == s, avatarImageView.image != nil { return }
        lastPhotoURL = s

        // Hit sincrono dalla memory cache: niente flicker.
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarLoadTask?.cancel()
            avatarLoadTask = nil
            avatarImageView.image = cached
            return
        }

        avatarLoadTask?.cancel()
        avatarLoadTask = ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self, self.lastPhotoURL == s else { return }
            if let image = image {
                self.avatarImageView.image = image
            }
        }
    }

    // MARK: - Actions

    @objc private func handleEdit() { onEditTap?() }
    @objc private func handleShare() { onShareTap?() }
    @objc private func handleAddFriends() { onAddFriendsTap?() }
    @objc private func handleFollowing() { onFollowingTap?() }
    @objc private func handleFollowers() { onFollowersTap?() }
    @objc private func handleLikes() { onLikesTap?() }
}

// MARK: - TikTokStatButton

/// Singola colonna stat tappabile: numero in bold sopra, label minuscola sotto.
/// Estende UIControl così risponde a `addTarget`.
final class TikTokStatButton: UIControl {

    private let valueLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "—"
        return l
    }()

    private let textLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    init(label: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = label
        addSubview(valueLabel)
        addSubview(textLabel)
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            textLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            textLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setValueText(_ text: String) {
        valueLabel.text = text
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.5 : 1.0 }
    }
}

// MARK: - ProfileTikTokGridCell

/// Cella della griglia 9:16 verticale: immagine aspectFill + overlay
/// (icona play + numero like) in basso a sinistra con shadow.
final class ProfileTikTokGridCell: UICollectionViewCell {

    static let reuseID = "ProfileTikTokGridCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .Brand.creamSurface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let overlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Gradient sottile in basso per dare leggibilità all'overlay.
    private let gradientLayer: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [UIColor.clear.cgColor,
                    UIColor.black.withAlphaComponent(0.55).cgColor]
        g.locations = [0.5, 1.0]
        return g
    }()

    private let playIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "play.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        // Shadow per leggibilità su sfondi chiari.
        iv.layer.shadowColor = UIColor.black.cgColor
        iv.layer.shadowOffset = CGSize(width: 0, height: 0.5)
        iv.layer.shadowRadius = 1.0
        iv.layer.shadowOpacity = 0.6
        return iv
    }()

    private let likesLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOffset = CGSize(width: 0, height: 0.5)
        l.layer.shadowRadius = 1.0
        l.layer.shadowOpacity = 0.6
        return l
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .Brand.goldPrimary
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var currentURL: URL?
    private var imageLoadTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(overlay)
        overlay.layer.addSublayer(gradientLayer)
        overlay.addSubview(playIcon)
        overlay.addSubview(likesLabel)
        contentView.addSubview(spinner)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            playIcon.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 6),
            playIcon.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -6),
            playIcon.widthAnchor.constraint(equalToConstant: 12),
            playIcon.heightAnchor.constraint(equalToConstant: 12),

            likesLabel.leadingAnchor.constraint(equalTo: playIcon.trailingAnchor, constant: 4),
            likesLabel.centerYAnchor.constraint(equalTo: playIcon.centerYAnchor),
            likesLabel.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -6),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = overlay.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        currentURL = nil
        imageLoadTask?.cancel()
        imageLoadTask = nil
        spinner.stopAnimating()
        likesLabel.text = nil
        overlay.isHidden = true
    }

    func configure(imageURL: String, likesCount: Int?, showOverlay: Bool) {
        // Overlay (play + like): sempre visibile sui post. Il count può essere
        // nil → mostriamo solo l'icona play (TikTok-style).
        overlay.isHidden = !showOverlay
        if showOverlay {
            if let n = likesCount, n > 0 {
                likesLabel.text = ProfileHandle.compactCount(n)
                likesLabel.isHidden = false
            } else {
                likesLabel.text = nil
                likesLabel.isHidden = true
            }
        }

        guard let url = URL(string: imageURL) else { return }

        imageLoadTask?.cancel()
        imageLoadTask = nil

        if let cached = ImageCache.shared.cachedImage(for: url) {
            imageView.image = cached
            spinner.stopAnimating()
            currentURL = url
            return
        }
        currentURL = url
        spinner.startAnimating()
        imageLoadTask = ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.currentURL == url else { return }
            self.spinner.stopAnimating()
            if let image = image {
                self.imageView.image = image
            }
        }
    }
}
