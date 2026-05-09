//
//  FeedViewController.swift
//  Flotip
//
//  Feed verticale stile TikTok: cella full-screen immersiva, testo e
//  pulsanti azione in overlay direttamente sopra la foto, tab bar
//  trasparente che "fluttua" sopra il contenuto.
//
//  Layout di una cella:
//    - foto a tutto schermo (aspect fill, edge to edge)
//    - gradiente nero leggero in alto e in basso per leggibilità
//    - in basso a SINISTRA: nome autore (semibold) + caption (max 3 righe)
//    - in basso, in riga orizzontale sotto la caption: save (square.and.arrow.down)
//      / heart / paperplane. Solo heart ha una label contatore sotto l'icona
//      (mostra i like reali); save e paperplane sono solo icone.
//
//  Top bar rimossa (niente più scritta "Esplora"). Resta solo una piccola
//  lente fluttuante in alto a destra che apre il SearchDrawerViewController
//  per cercare utenti e iniziare una chat. La libreria si apre dal Profilo
//  o dalla tab Cattura, non più da qui.
//
//  Doppio tap sulla foto: apre la pagina sorgente nella tab Cattura
//  (comportamento mantenuto dalla versione precedente).
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

final class FeedViewController: UIViewController,
                                UICollectionViewDataSource,
                                UICollectionViewDelegateFlowLayout {

    // MARK: - Layout constants

    /// Altezza visibile della cella adiacente (peek sopra/sotto).
    private let peek: CGFloat = 80
    /// Spazio tra una cella e l'altra: piccolo, le celle sono già full-screen.
    private let interItemSpacing: CGFloat = 6

    // MARK: - UI

    private var collectionView: UICollectionView!
    /// Container dell'empty state: icona + titolo + sottotitolo + bottone
    /// "Vai a Esplora". Mostrato quando AppStore.shared.posts è vuoto
    /// (es. utente non segue nessuno o nessun followed ha ancora postato).
    private var emptyStateView: UIView!
    private let refreshControl = UIRefreshControl()

    /// Lente fluttuante in alto a destra del feed: apre il SearchDrawer
    /// per cercare utenti. Senza top bar di sfondo, ha shadow forte per
    /// stagliarsi sulle immagini sottostanti.
    private let searchButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        b.setImage(UIImage(systemName: "magnifyingglass", withConfiguration: cfg),
                   for: .normal)
        b.tintColor = .white
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.55
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.layer.shadowRadius = 4
        b.layer.masksToBounds = false
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Status bar

    /// Le immagini occupano tutto lo schermo: testo bianco è sempre più
    /// leggibile in cima (il gradiente lo aiuta sui contenuti chiari).
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupCollectionView()
        setupSearchButton()
        setupEmptyStateView()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(feedUpdated),
            name: AppStore.feedUpdatedNotification,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Riallinea la UI con la cache ogni volta che arriviamo qui:
        // copre il caso in cui il listener Firestore abbia ricevuto post
        // PRIMA che questa view fosse mai caricata.
        collectionView.reloadData()
        updateEmptyState()
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ricalcolo insets/cella ogni volta che cambia bounds (rotation,
        // safe area iniziale non ancora nota in viewDidLoad, ecc.).
        applyInsetsAndInvalidateLayout()
        // La lente fluttuante deve restare sopra le celle nello z-order:
        // le celle vengono ricreate dal collection view e potrebbero
        // finire sopra altrimenti.
        view.bringSubviewToFront(searchButton)
        // Le celle dequeuate prima del primo layout potrebbero aver
        // calcolato `bottomOverlayInset` senza safeArea: aggiorniamo
        // i loro overlay ora che il valore è preciso.
        let inset = bottomOverlayInset
        for case let cell as FeedCell in collectionView.visibleCells {
            cell.updateBottomOverlayInset(inset)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = interItemSpacing
        layout.minimumInteritemSpacing = 0

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        // Snap "manuale": niente paging nativo, gestiamo lo snap nello
        // scrollViewWillEndDragging così possiamo accomodare la peek.
        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast
        collectionView.backgroundColor = .black
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: FeedCell.reuseID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        // Pull-to-refresh (rotellina chiara su sfondo nero)
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        collectionView.alwaysBounceVertical = true

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// Lente in alto a destra del feed (no top bar, è un bottone "fluttuante"
    /// direttamente sopra le foto). Apre il SearchDrawer per cercare utenti
    /// con cui iniziare una chat.
    private func setupSearchButton() {
        view.addSubview(searchButton)
        searchButton.addTarget(self, action: #selector(openSearch), for: .touchUpInside)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            searchButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchButton.widthAnchor.constraint(equalToConstant: 36),
            searchButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    @objc private func openSearch() {
        // Drawer di ricerca: scivola dentro dal bordo destro (push iOS standard).
        let search = SearchDrawerViewController()
        search.modalPresentationStyle = .fullScreen
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(search, animated: false)
    }

    @objc private func handleRefresh() {
        PostService.shared.refreshFeed { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshControl.endRefreshing()
                // setPosts notifica e fa già reloadData; mettiamo il safety net
                self?.collectionView.reloadData()
                self?.updateEmptyState()
            }
        }
    }

    /// Empty state mostrato quando il feed (filtrato per "following")
    /// è vuoto. Layout: icona grigia ~48pt + titolo bold + sottotitolo
    /// + bottone "Vai a Esplora" oro brand. Il bottone apre il
    /// SearchDrawer (lo stesso che si apre dalla lente in alto a destra)
    /// — è il punto di accesso alla ricerca utenti, equivalente di
    /// "Esplora" in questa app che non ha una tab dedicata.
    private func setupEmptyStateView() {
        emptyStateView = UIView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        view.addSubview(emptyStateView)

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        let iconView = UIImageView(image: UIImage(
            systemName: "person.2.crop.square.stack",
            withConfiguration: iconConfig
        ))
        iconView.tintColor = UIColor.white.withAlphaComponent(0.55)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Nessun post nel feed"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        // Shadow per leggibilità (anche se sfondo cella nero, può
        // sovrapporsi a un loader/transient).
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.5
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.shadowRadius = 3
        titleLabel.layer.masksToBounds = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Segui qualcuno da Esplora per vedere i suoi post qui"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let exploreButton = UIButton(type: .system)
        exploreButton.setTitle("Vai a Esplora", for: .normal)
        exploreButton.setTitleColor(.black, for: .normal)
        exploreButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        exploreButton.backgroundColor = .Brand.goldOnDark
        exploreButton.layer.cornerRadius = 22
        exploreButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 22, bottom: 10, right: 22)
        exploreButton.translatesAutoresizingMaskIntoConstraints = false
        exploreButton.addTarget(self, action: #selector(openSearch), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel, subtitleLabel, exploreButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.setCustomSpacing(6, after: titleLabel)
        stack.setCustomSpacing(20, after: subtitleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.addSubview(stack)

        NSLayoutConstraint.activate([
            // Container empty state: centrato, con padding orizzontale.
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            // Stack riempie il container.
            stack.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            // Icona ~48pt: dimensione fissa, separata dal layout testo.
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),

            // Bottone almeno 200pt di larghezza per leggibilità.
            exploreButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        updateEmptyState()
    }

    // MARK: - Data

    @objc private func feedUpdated() {
        collectionView.reloadData()
        updateEmptyState()
    }

    private func updateEmptyState() {
        let isEmpty = AppStore.shared.posts.isEmpty
        emptyStateView?.isHidden = !isEmpty
        // Quando il feed è vuoto, l'empty state deve restare sopra
        // qualsiasi cella residua durante lo scroll bouncing.
        if isEmpty, let v = emptyStateView {
            view.bringSubviewToFront(v)
            view.bringSubviewToFront(searchButton)
        }
    }

    // MARK: - Insets & cell sizing

    /// Altezza di una cella TikTok-style: l'intero schermo meno la peek
    /// sopra e sotto (così si vede sempre un assaggio del post adiacente).
    /// La cella "scorre" sotto la top bar e la tab bar trasparenti.
    private var cellHeight: CGFloat {
        let h = view.bounds.height - 2 * peek
        return max(h, 200)
    }

    /// Inset top/bottom della collection view: lasciano lo spazio per la
    /// peek sopra (post precedente) e sotto (post successivo). Il primo
    /// post è centrato verticalmente, con `peek` di margine sopra.
    private func applyInsetsAndInvalidateLayout() {
        let topInset = peek
        let bottomInset = peek

        if collectionView.contentInset.top != topInset
            || collectionView.contentInset.bottom != bottomInset {
            collectionView.contentInset = UIEdgeInsets(
                top: topInset, left: 0, bottom: bottomInset, right: 0
            )
            // Allinea il primo montaggio: parto dal primo post.
            if collectionView.contentOffset.y < -topInset + 1 {
                collectionView.setContentOffset(CGPoint(x: 0, y: -topInset),
                                                animated: false)
            }
        }
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let target = CGSize(width: collectionView.bounds.width, height: cellHeight)
            if layout.itemSize != target {
                layout.itemSize = target
                layout.invalidateLayout()
            }
        }
    }

    /// Quanto spazio dal fondo della cella tenere libero per gli overlay
    /// (nome + caption a sinistra, colonna azioni a destra), così non
    /// finiscano dietro la tab bar fluttuante. Con la tab bar translucida
    /// `view.safeAreaInsets.bottom` ne include già l'altezza; il `max`
    /// con `tabBar.bounds.height` è solo difesa nel caso safeArea non
    /// sia ancora aggiornata al primo layout.
    private var bottomOverlayInset: CGFloat {
        // La cella è già `peek` pt sopra il bordo schermo (80pt) per via
        // dello stile TikTok-snap. Sotto la cella si vede l'inizio della
        // cella successiva. La tab bar fluttuante translucida vive nella
        // safe area inferiore. Per posizionare nome/caption/icone APPENA
        // sopra la tab bar (non in mezzo alla cella) servono pochi pt di
        // inset, non l'intera altezza della tab bar — quella è già
        // compensata dal peek.
        let tabBarHeight = tabBarController?.tabBar.bounds.height ?? 49
        return max(8, tabBarHeight - peek + 8)
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return AppStore.shared.posts.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeedCell.reuseID, for: indexPath) as! FeedCell
        let post = AppStore.shared.posts[indexPath.item]
        cell.configure(with: post, bottomOverlayInset: bottomOverlayInset)
        // Doppio tap sulla foto: torna alla tab Cattura e riapre l'URL
        // della pagina sorgente del post (comportamento esistente).
        cell.onDoubleTap = { [weak self] in
            self?.openSourceInCapture(post: post)
        }
        // Tap sul paperplane (send): apre lo sheet "Invia in chat".
        cell.onSendTap = { [weak self] post in
            self?.openShareToChat(for: post)
        }
        // Tap sul contatore like (sotto il cuore): apre lo sheet con la
        // lista dei profili che hanno messo like al post.
        cell.onLikeCountTap = { [weak self] post in
            self?.openLikers(for: post)
        }
        return cell
    }

    // MARK: - Likers sheet

    private func openLikers(for post: Post) {
        guard let postId = post.id else { return }
        let likers = LikersListViewController(postId: postId)
        // Forziamo .pageSheet per essere sicuri che `sheetPresentationController`
        // sia non-nil quando configuriamo i detents qui sotto.
        likers.modalPresentationStyle = .pageSheet
        if let sheet = likers.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        present(likers, animated: true)
    }

    // MARK: - Invio in chat

    private func openShareToChat(for post: Post) {
        let share = ShareToChatViewController(post: post)
        share.modalPresentationStyle = .pageSheet
        present(share, animated: true)
    }

    // MARK: - Apertura sorgente in Cattura

    private func openSourceInCapture(post: Post) {
        guard let urlString = post.sourceURL,
              let url = URL(string: urlString) else {
            // Post legacy senza URL salvato: niente da fare.
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

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: cellHeight)
    }

    // MARK: - Snap (UIScrollViewDelegate)

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let step = cellHeight + interItemSpacing
        guard step > 0 else { return }

        // contentOffset.y "naturale" del post N: -contentInset.top + N*step
        let baseOffset = -collectionView.contentInset.top
        let proposed = targetContentOffset.pointee.y
        let raw = (proposed - baseOffset) / step

        // Scroll TikTok-style: la velocità sceglie la cella, ma snap
        // sempre cella per cella (mai più di una, se non con flick fortissimo).
        let index: CGFloat
        if velocity.y > 0.2 {
            index = ceil(raw)
        } else if velocity.y < -0.2 {
            index = floor(raw)
        } else {
            index = (raw - floor(raw)) > 0.5 ? ceil(raw) : floor(raw)
        }

        let count = CGFloat(AppStore.shared.posts.count)
        let clamped = min(max(index, 0), max(count - 1, 0))
        targetContentOffset.pointee.y = baseOffset + clamped * step
    }
}

// MARK: - User name cache

/// Cache molto leggera per i nomi degli autori: se il `Post` non li porta
/// già con sé (campo `authorName` vuoto), li recuperiamo da
/// Firestore `users/{uid}` una volta sola e li teniamo in memoria.
final class FeedAuthorNameCache {
    static let shared = FeedAuthorNameCache()
    private init() {}

    private var cache: [String: String] = [:]
    private var inflight: [String: [(String) -> Void]] = [:]

    func name(for uid: String, completion: @escaping (String) -> Void) {
        if let cached = cache[uid] {
            completion(cached)
            return
        }
        if inflight[uid] != nil {
            inflight[uid]?.append(completion)
            return
        }
        inflight[uid] = [completion]
        Firestore.firestore().collection("users").document(uid).getDocument {
            [weak self] snapshot, _ in
            let data = snapshot?.data() ?? [:]
            let first = (data["firstName"] as? String) ?? ""
            let last  = (data["lastName"] as? String) ?? ""
            let full  = [first, last].joined(separator: " ")
                                     .trimmingCharacters(in: .whitespaces)
            let resolved = full.isEmpty ? "Utente" : full
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.cache[uid] = resolved
                let waiters = self.inflight.removeValue(forKey: uid) ?? []
                waiters.forEach { $0(resolved) }
            }
        }
    }
}

// MARK: - FeedCell

/// Cella stile TikTok: foto a tutto schermo, nome+caption in basso a
/// sinistra, colonna azioni in basso a destra, gradienti per leggibilità.
final class FeedCell: UICollectionViewCell {
    static let reuseID = "FeedCell"

    /// Caption di fallback quando il Post non ne ha una.
    private static let placeholderCaption =
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit. " +
        "Sed do eiusmod tempor incididunt ut labore."

    // MARK: - UI

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .white
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    /// Gradiente in alto: aiuta a leggere la scritta "Esplora" della top bar
    /// quando la cella sta scrollando dietro.
    private let topGradient = CAGradientLayer()
    /// Gradiente in basso: scurisce la zona dove vivono autore + caption +
    /// colonna azioni, per renderli leggibili anche su immagini chiare.
    private let bottomGradient = CAGradientLayer()

    // Bottom-left: nome + caption
    private let infoStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .leading
        s.spacing = 4
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let authorLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .white
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let captionLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = UIColor.white.withAlphaComponent(0.95)
        l.numberOfLines = 3
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Riga orizzontale sotto la caption: save (square.and.arrow.down) +
    /// heart (like) + paperplane (send). Spostati qui per richiesta UX:
    /// vivono vicino al testo invece che in colonna sulla destra.
    /// Allineamento `.top` così tutte le icone restano sulla stessa
    /// linea anche se il save (senza counter) è più basso degli altri due.
    private let actionsRow: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .top
        s.spacing = 18
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // Save: freccia verso il basso dentro un quadrato (segnale "salva
    // nella tua libreria"). Niente counter sotto.
    private let saveButton = FeedCell.makeActionButton(systemName: "square.and.arrow.down")
    private let likeButton = FeedCell.makeActionButton(systemName: "heart")
    private let sendButton = FeedCell.makeActionButton(systemName: "paperplane")

    private let likeCount = FeedCell.makeCountLabel()

    /// Posizione verticale degli overlay: bisogna alzarli sopra la
    /// tab bar fluttuante. Settati da `configure(with:bottomOverlayInset:)`.
    private var infoBottomConstraint: NSLayoutConstraint!

    /// Stato visivo dei toggle.
    /// `isLiked` è alimentato dal listener Firestore (observeIsLiked) e/o
    /// aggiornato ottimisticamente al tap.
    /// `isSaved` è alimentato da `LibraryService.observeIsPostSaved` per i
    /// post di altri utenti (per i propri post il bottone Save è nascosto).
    private var isLiked = false
    private var isSaved = false

    /// Conteggio like real-time (proveniente dal listener observeLikeCount).
    private var likeCountValue: Int = 0

    /// Listener registrations sulla subcollection likes del post corrente.
    /// Vanno rimossi in `prepareForReuse` per evitare leak quando la cella
    /// viene riutilizzata per un altro post.
    private var likeCountListener: ListenerRegistration?
    private var isLikedListener: ListenerRegistration?
    /// Listener Firestore che osserva se il post corrente è già nei salvati
    /// dell'utente loggato (collection `libraryItems` con
    /// `ownerId == uid AND originalPostId == post.id`).
    private var isSavedListener: ListenerRegistration?

    /// Task del download immagine corrente: lo cancelliamo in `prepareForReuse`
    /// per evitare di assegnare un'immagine a una cella ormai riusata per un
    /// altro post (causa flicker visivo durante lo scroll veloce).
    private var imageLoadTask: URLSessionDataTask?

    /// Flag per evitare race condition: se l'utente ri-tappa il cuore mentre
    /// la chiamata precedente è ancora in volo, ignoriamo i tap successivi.
    private var likeToggleInFlight = false

    /// Idem per il bottone Save: evitiamo doppi tap che generano write
    /// contraddittorie su `libraryItems`.
    private var saveToggleInFlight = false

    private var currentLoadURL: URL?

    /// Callback invocata al doppio tap sulla foto. Settata da FeedViewController.
    var onDoubleTap: (() -> Void)?

    /// Tap sul paperplane: il FeedViewController presenta il sheet
    /// "Invia in chat" per il post correntemente mostrato.
    var onSendTap: ((Post) -> Void)?

    /// Tap sul contatore like (label sotto il cuore): apre la lista likers.
    var onLikeCountTap: ((Post) -> Void)?

    /// Post corrente (serve a `onSendTap`).
    private var currentPost: Post?

    /// UID dell'autore correntemente mostrato (per evitare race condition
    /// se la cella viene riusata mentre il fetch del nome è in volo).
    private var currentAuthorId: String?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        contentView.backgroundColor = .black

        // 1) Foto a tutto schermo (più sotto in z-order).
        contentView.addSubview(imageView)
        contentView.addSubview(spinner)

        // 2) Gradienti come sublayer DIRETTI di contentView.layer:
        //    aggiunti dopo i due subview, finiscono SOPRA la foto ma SOTTO
        //    le label/pulsanti (che vengono aggiunti come subview dopo).
        topGradient.colors = [
            UIColor.black.withAlphaComponent(0.30).cgColor,
            UIColor.black.withAlphaComponent(0.00).cgColor
        ]
        topGradient.locations = [0.0, 1.0]
        contentView.layer.addSublayer(topGradient)

        bottomGradient.colors = [
            UIColor.black.withAlphaComponent(0.00).cgColor,
            UIColor.black.withAlphaComponent(0.55).cgColor
        ]
        bottomGradient.locations = [0.0, 1.0]
        contentView.layer.addSublayer(bottomGradient)

        // 3) Overlay testo (in alto allo z-order) + riga azioni save/like/send
        //    APPENA SOTTO la caption (lorem ipsum). actionsRow è il terzo
        //    arranged subview di infoStack, così segue automaticamente la
        //    fine del testo senza sovrapporsi.
        applyTextShadow(authorLabel)
        applyTextShadow(captionLabel)
        infoStack.addArrangedSubview(authorLabel)
        infoStack.addArrangedSubview(captionLabel)

        // Save: solo l'icona, niente counter sotto. Aggiungiamo il bottone
        // direttamente alla row e fissiamo a mano la stessa size dei wrapper
        // di heart/send (36x30) per mantenere la spaziatura coerente.
        actionsRow.addArrangedSubview(saveButton)
        NSLayoutConstraint.activate([
            saveButton.widthAnchor.constraint(equalToConstant: 36),
            saveButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        actionsRow.addArrangedSubview(makeActionItem(button: likeButton, count: likeCount))
        // Send (paperplane): solo icona, NESSUN counter sotto (parità con
        // save). Aggiungiamo il bottone diretto e fissiamo le size come per
        // save così le tre icone restano allineate.
        actionsRow.addArrangedSubview(sendButton)
        NSLayoutConstraint.activate([
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        infoStack.addArrangedSubview(actionsRow)
        // Un filo di respiro extra fra la caption e la riga di icone.
        infoStack.setCustomSpacing(8, after: captionLabel)

        contentView.addSubview(infoStack)

        // Doppio tap sulla foto: riapre la pagina sorgente nella tab Cattura.
        contentView.isUserInteractionEnabled = true
        let doubleTap = UITapGestureRecognizer(target: self,
                                               action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        contentView.addGestureRecognizer(doubleTap)

        // Wiring dei pulsanti azione.
        saveButton.addTarget(self, action: #selector(toggleSave), for: .touchUpInside)
        likeButton.addTarget(self, action: #selector(toggleLike), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(handleSend), for: .touchUpInside)

        // Tap sul label conteggio like → apre lista likers.
        likeCount.isUserInteractionEnabled = true
        let likeCountTap = UITapGestureRecognizer(target: self,
                                                  action: #selector(handleLikeCountTap))
        likeCount.addGestureRecognizer(likeCountTap)

        // Constraint mutevole: la posizione verticale dell'overlay (info
        // + riga icone) viene ricalcolata ogni configure() in base alla
        // tab bar.
        infoBottomConstraint = infoStack.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor, constant: -100)

        NSLayoutConstraint.activate([
            // Foto edge-to-edge
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Info (nome + caption + riga azioni) in basso a sinistra
            infoStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            infoBottomConstraint
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // I gradienti sono CALayer puri: niente Auto Layout, dimensiono a mano.
        let topH = min(140, max(0, bounds.height * 0.22))
        let botH = min(260, max(0, bounds.height * 0.34))
        // CATransaction senza animazione: evita transizioni durante lo scroll.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        topGradient.frame = CGRect(x: 0, y: 0, width: bounds.width, height: topH)
        bottomGradient.frame = CGRect(x: 0, y: bounds.height - botH,
                                      width: bounds.width, height: botH)
        CATransaction.commit()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        currentLoadURL = nil
        currentAuthorId = nil
        currentPost = nil
        onDoubleTap = nil
        onSendTap = nil
        onLikeCountTap = nil
        isLiked = false
        isSaved = false
        likeCountValue = 0
        likeCount.text = "0"
        likeToggleInFlight = false
        saveToggleInFlight = false
        // Cancellare il task di download in volo evita di assegnare l'immagine
        // del post precedente alla cella appena riusata per un nuovo post.
        imageLoadTask?.cancel()
        imageLoadTask = nil
        // CRITICO: rimuovere i listener Firestore prima di riusare la cella
        // per un altro post, altrimenti riceviamo update del post precedente.
        likeCountListener?.remove()
        likeCountListener = nil
        isLikedListener?.remove()
        isLikedListener = nil
        isSavedListener?.remove()
        isSavedListener = nil
        // Reset visivo del save: visibile finché configure() non decide
        // diversamente (è nascosto solo per i post dell'utente loggato).
        saveButton.isHidden = false
        applyToggleState(button: likeButton, on: false,
                         iconOn: "heart.fill", iconOff: "heart")
        applyToggleState(button: saveButton, on: false,
                         iconOn: "square.and.arrow.down.fill",
                         iconOff: "square.and.arrow.down")
        spinner.stopAnimating()
        captionLabel.text = nil
        authorLabel.text = nil
    }

    deinit {
        likeCountListener?.remove()
        isLikedListener?.remove()
        isSavedListener?.remove()
        imageLoadTask?.cancel()
    }

    // MARK: - Actions

    @objc private func handleDoubleTap() {
        onDoubleTap?()
    }

    @objc private func toggleLike() {
        guard let post = currentPost, let postId = post.id else { return }
        guard !likeToggleInFlight else { return }
        likeToggleInFlight = true

        // 1) Aggiornamento ottimistico: l'icona reagisce subito, e il
        //    contatore viene aggiustato di ±1 senza aspettare il network.
        let previousIsLiked = isLiked
        let previousCount = likeCountValue
        let newIsLiked = !previousIsLiked
        isLiked = newIsLiked
        likeCountValue = max(0, previousCount + (newIsLiked ? 1 : -1))
        applyToggleState(button: likeButton, on: isLiked,
                         iconOn: "heart.fill", iconOff: "heart")
        likeCount.text = Self.formatCount(likeCountValue)

        // 2) Chiamata Firestore. Su errore reverte UI e mostra alert.
        Task { [weak self] in
            do {
                _ = try await PostService.shared.toggleLike(postId: postId)
                await MainActor.run {
                    self?.likeToggleInFlight = false
                }
            } catch {
                await MainActor.run {
                    guard let self = self,
                          self.currentPost?.id == postId else { return }
                    // Revert visivo: il listener Firestore corregge
                    // comunque entro pochi ms, ma evitiamo lo "scatto".
                    self.isLiked = previousIsLiked
                    self.likeCountValue = previousCount
                    self.applyToggleState(button: self.likeButton,
                                          on: previousIsLiked,
                                          iconOn: "heart.fill",
                                          iconOff: "heart")
                    self.likeCount.text = Self.formatCount(previousCount)
                    self.likeToggleInFlight = false
                    self.presentLikeError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func handleLikeCountTap() {
        guard let post = currentPost else { return }
        onLikeCountTap?(post)
    }

    /// Mostra un alert effimero per errori sul like. Il VC presentante
    /// è recuperato risalendo la responder chain.
    private func presentLikeError(_ message: String) {
        guard let vc = self.findOwningViewController() else { return }
        let alert = UIAlertController(title: "Mi piace non riuscito",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        vc.present(alert, animated: true)
    }

    /// Risale la responder chain fino a trovare un UIViewController.
    private func findOwningViewController() -> UIViewController? {
        var responder: UIResponder? = self.next
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }

    @objc private func toggleSave() {
        guard let post = currentPost, let postId = post.id else { return }
        // Difesa anti doppio-tap: se la chiamata precedente è ancora in volo,
        // ignoriamo il nuovo tap. Il listener Firestore ricondurrà comunque
        // l'icona nello stato giusto.
        guard !saveToggleInFlight else { return }
        // Salvare un proprio post non ha senso e per spec non è un'azione
        // ammessa. Il bottone è già nascosto via configure(), ma teniamo
        // un guard difensivo qui (es. cella riusata mid-update).
        guard let uid = Auth.auth().currentUser?.uid,
              post.authorId != uid else {
            return
        }
        saveToggleInFlight = true

        // Aggiornamento ottimistico: l'icona reagisce subito.
        let previousIsSaved = isSaved
        let newIsSaved = !previousIsSaved
        isSaved = newIsSaved
        applyToggleState(button: saveButton, on: newIsSaved,
                         iconOn: "square.and.arrow.down.fill",
                         iconOff: "square.and.arrow.down")

        let onComplete: (Result<Void, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.saveToggleInFlight = false
                if case let .failure(error) = result {
                    // Revert visivo: il listener Firestore ricondurrà comunque
                    // lo stato corretto, ma evitiamo lo "scatto".
                    guard self.currentPost?.id == postId else { return }
                    self.isSaved = previousIsSaved
                    self.applyToggleState(button: self.saveButton, on: previousIsSaved,
                                          iconOn: "square.and.arrow.down.fill",
                                          iconOff: "square.and.arrow.down")
                    if let window = self.window {
                        ToastView.show(message: "Salvataggio non riuscito: \(error.localizedDescription)",
                                       in: window)
                    }
                }
            }
        }

        if newIsSaved {
            LibraryService.shared.savePost(post) { result in
                switch result {
                case .success:           onComplete(.success(()))
                case .failure(let err):  onComplete(.failure(err))
                }
            }
        } else {
            LibraryService.shared.unsavePost(postId: postId, completion: onComplete)
        }
    }

    @objc private func handleSend() {
        // Apre lo sheet "Invia in chat" per il post correntemente mostrato.
        // La presentazione effettiva avviene nel FeedViewController via callback,
        // perché la cella non ha accesso diretto al view controller.
        guard let post = currentPost else { return }
        onSendTap?(post)
    }

    // MARK: - Configure

    /// Aggiornamento "fuori configure" della distanza dal fondo: serve a
    /// FeedViewController quando, al primo layout, scopre la safeArea
    /// reale dopo che le celle sono già state dequeuate.
    func updateBottomOverlayInset(_ inset: CGFloat) {
        guard infoBottomConstraint.constant != -inset else { return }
        infoBottomConstraint.constant = -inset
        layoutIfNeeded()
    }

    /// `bottomOverlayInset`: distanza dal fondo della cella sopra la quale
    /// posizionare nome/caption/riga icone (così non finiscano dietro la
    /// tab bar fluttuante).
    func configure(with post: Post, bottomOverlayInset: CGFloat) {
        currentPost = post
        infoBottomConstraint.constant = -bottomOverlayInset

        // 1) Nome autore. Se il post lo porta già, lo usiamo subito; in
        //    fallback chiediamo al cache che legge users/{uid} una volta.
        let initial = post.authorName.trimmingCharacters(in: .whitespaces)
        currentAuthorId = post.authorId
        if !initial.isEmpty {
            authorLabel.text = initial
        } else {
            authorLabel.text = " "
            FeedAuthorNameCache.shared.name(for: post.authorId) { [weak self] name in
                guard let self = self,
                      self.currentAuthorId == post.authorId else { return }
                self.authorLabel.text = name
            }
        }

        // 2) Caption: lorem ipsum se vuota.
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        captionLabel.text = trimmed.isEmpty ? Self.placeholderCaption : trimmed

        // 3) Foto. Usa `previewImageURL`: la thumb 1080px generata dalla
        //    Cloud Function `onPostImageFinalized` se disponibile,
        //    altrimenti fallback all'originale (post legacy o pochi
        //    secondi tra upload e completamento CF).
        if let url = URL(string: post.previewImageURL) {
            loadImage(from: url)
        }

        // 4) Likes / saved: avvia i listener real-time sulla subcollection
        //    posts/{postId}/likes e sulla query libraryItems del save.
        //    Pulisce eventuali listener precedenti (per sicurezza, anche se
        //    prepareForReuse dovrebbe averli già rimossi).
        likeCountListener?.remove()
        likeCountListener = nil
        isLikedListener?.remove()
        isLikedListener = nil
        isSavedListener?.remove()
        isSavedListener = nil

        // Bottone Save: visibile solo se il post è di un altro utente. Sui
        // propri post non ha senso "salvare nei tuoi salvati", quindi lo
        // nascondiamo del tutto. Reset visivo unconditional così, anche se
        // un toggle precedente era in volo, il prossimo configure() parte
        // dallo stato "non salvato" finché il listener non porta il vero.
        let currentUid = Auth.auth().currentUser?.uid
        let isOwnPost = (currentUid != nil && currentUid == post.authorId)
        saveButton.isHidden = isOwnPost
        isSaved = false
        applyToggleState(button: saveButton, on: false,
                         iconOn: "square.and.arrow.down.fill",
                         iconOff: "square.and.arrow.down")

        guard let postId = post.id else {
            // Post senza ID (caso teorico, non dovrebbe accadere lato feed):
            // mostriamo 0 e cuore vuoto, niente listener.
            isLiked = false
            likeCountValue = 0
            likeCount.text = "0"
            applyToggleState(button: likeButton, on: false,
                             iconOn: "heart.fill", iconOff: "heart")
            return
        }

        // Listener "isSaved": valido solo se il post è di un altro utente
        // (per i propri post il bottone è già nascosto e l'azione è no-op).
        if !isOwnPost {
            isSavedListener = LibraryService.shared.observeIsPostSaved(
                postId: postId
            ) { [weak self] saved in
                DispatchQueue.main.async {
                    guard let self = self,
                          self.currentPost?.id == postId else { return }
                    if !self.saveToggleInFlight {
                        self.isSaved = saved
                        self.applyToggleState(button: self.saveButton,
                                              on: saved,
                                              iconOn: "square.and.arrow.down.fill",
                                              iconOff: "square.and.arrow.down")
                    }
                }
            }
        }

        // Reset visivo finché il primo snapshot non arriva.
        likeCountValue = 0
        likeCount.text = "0"
        isLiked = false
        applyToggleState(button: likeButton, on: false,
                         iconOn: "heart.fill", iconOff: "heart")

        likeCountListener = PostService.shared.observeLikeCount(
            postId: postId
        ) { [weak self] count in
            guard let self = self,
                  self.currentPost?.id == postId else { return }
            DispatchQueue.main.async {
                self.likeCountValue = count
                // Se un toggle è in volo, lascio che il revert/persistenza
                // gestisca il count (evita scatti). Il listener riallinea
                // appena il toggle finisce comunque.
                if !self.likeToggleInFlight {
                    self.likeCount.text = Self.formatCount(count)
                }
            }
        }

        isLikedListener = PostService.shared.observeIsLiked(
            postId: postId
        ) { [weak self] isLiked in
            guard let self = self,
                  self.currentPost?.id == postId else { return }
            DispatchQueue.main.async {
                if !self.likeToggleInFlight {
                    self.isLiked = isLiked
                    self.applyToggleState(button: self.likeButton,
                                          on: isLiked,
                                          iconOn: "heart.fill",
                                          iconOff: "heart")
                }
            }
        }
    }

    /// Formatta il contatore like in stile compatto: "999", "1.2k", "12.3k", "1.2M".
    static func formatCount(_ n: Int) -> String {
        if n < 1000 {
            return "\(n)"
        }
        if n < 1_000_000 {
            let v = Double(n) / 1000.0
            return String(format: "%.1fk", v).replacingOccurrences(of: ".0k", with: "k")
        }
        let v = Double(n) / 1_000_000.0
        return String(format: "%.1fM", v).replacingOccurrences(of: ".0M", with: "M")
    }

    private func loadImage(from url: URL) {
        // Cancella un eventuale download in corso (cella riusata mid-flight).
        imageLoadTask?.cancel()
        imageLoadTask = nil

        // Hit sincrono: nessuno spinner, niente flicker.
        if let cached = ImageCache.shared.cachedImage(for: url) {
            imageView.image = cached
            spinner.stopAnimating()
            currentLoadURL = url
            return
        }
        currentLoadURL = url
        spinner.startAnimating()
        imageLoadTask = ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.currentLoadURL == url else { return }
            self.spinner.stopAnimating()
            if let image = image {
                self.imageView.image = image
            }
        }
    }

    // MARK: - Helpers

    /// Pulsante azione TikTok-style: icona bianca con shadow per leggibilità
    /// anche su immagini chiare. Dimensione contenuta (22pt) su richiesta UX
    /// per ridurre l'ingombro visivo della riga azioni.
    private static func makeActionButton(systemName: String) -> UIButton {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
        b.setImage(UIImage(systemName: systemName, withConfiguration: cfg), for: .normal)
        b.tintColor = .white
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.55
        b.layer.shadowOffset = CGSize(width: 0, height: 1)
        b.layer.shadowRadius = 3
        b.layer.masksToBounds = false
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    /// Etichetta contatore sotto ogni icona azione.
    private static func makeCountLabel() -> UILabel {
        let l = UILabel()
        l.text = "0"
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.5
        l.layer.shadowOffset = CGSize(width: 0, height: 1)
        l.layer.shadowRadius = 2
        l.layer.masksToBounds = false
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    /// Wrapper verticale icona + contatore, da inserire nella colonna azioni.
    private func makeActionItem(button: UIButton, count: UILabel) -> UIView {
        let stack = UIStackView(arrangedSubviews: [button, count])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 36),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        return stack
    }

    /// Applica stato attivo/inattivo al toggle: cambia simbolo e colore.
    /// - heart attivo → rosso sistema
    /// - save (square.and.arrow.down) attivo → oro brand (`goldOnDark`)
    private func applyToggleState(button: UIButton, on: Bool,
                                  iconOn: String, iconOff: String) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 22,
                                              weight: on ? .bold : .semibold)
        button.setImage(UIImage(systemName: on ? iconOn : iconOff,
                                withConfiguration: cfg),
                        for: .normal)
        if on {
            switch iconOn {
            case "heart.fill":
                button.tintColor = .systemRed
            case "square.and.arrow.down.fill":
                button.tintColor = .Brand.goldOnDark
            default:
                button.tintColor = .white
            }
        } else {
            button.tintColor = .white
        }
    }

    /// Shadow sul layer della label per leggibilità su qualsiasi sfondo.
    private func applyTextShadow(_ label: UILabel) {
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOpacity = 0.6
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 3
        label.layer.masksToBounds = false
    }
}
