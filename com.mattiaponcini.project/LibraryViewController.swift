//
//  LibraryViewController.swift
//  Flotip
//
//  Schermata "Libreria". Mostra una lista verticale di categorie:
//  News, Sport, Salvati e Post pubblicati. Ogni categoria è una riga
//  con un titolo grosso (stile Apple Books / Library) e sotto un
//  carosello orizzontale di celle stile copertina libro.
//
//  Da quando esiste `LibraryHostViewController` (container TikTok-style
//  con tab Notifiche/Libreria), la sezione "Notifiche" non vive più qui:
//  è il tab fratello a tutta schermata `NotificationsViewController`.
//
//  Modi di presentazione:
//  - Standalone fullscreen: la VC presenta la propria top bar con un
//    bottone dismiss in alto a sinistra. (Modalità storica usata in
//    eventuali entry point legacy.)
//  - Embedded in `LibraryHostViewController`: il container fornisce la
//    top bar con i tab e il bottone close, quindi qui nascondiamo la
//    nostra top bar. Si attiva con `embedsInHostContainer = true`
//    *prima* di `viewDidLoad` (al momento della costruzione).
//
//  - News/Sport/Salvati leggono in real-time la collection `libraryItems`
//    filtrata per ownerId + category. Supportano il drag&drop tra le
//    righe per spostare un item da una categoria all'altra.
//  - Post pubblicati legge i documenti `posts` con authorId == utente
//    loggato, ordinati per createdAt discendente.
//
//  Nessuna libreria esterna: caching immagini in-memory via NSCache.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - LibraryViewController

final class LibraryViewController: UIViewController {

    /// Categorie nella libreria, nell'ordine richiesto dal prodotto.
    /// `news`/`sport`/`saved` sono righe basate su LibraryItem (con drag&drop
    /// tra di loro, sia cross-categoria sia intra-categoria reorder).
    /// `publishedPosts` è una riga read-only basata su Post; il drag&drop
    /// non può atterrare lì né partire da lì.
    private enum Category: Int, CaseIterable {
        case news, sport, saved, publishedPosts

        var title: String {
            switch self {
            case .news:           return "News"
            case .sport:          return "Sport"
            case .saved:          return "Salvati"
            case .publishedPosts: return "Post pubblicati"
            }
        }
    }

    // MARK: - Embed flag

    /// Quando `true`, la VC è figlia di `LibraryHostViewController`: la top
    /// bar (titolo "Libreria" + bottone dismiss) viene nascosta perché il
    /// container fornisce già le tab + il bottone close. Va settato PRIMA
    /// che la view venga caricata (di solito subito dopo l'init).
    var embedsInHostContainer: Bool = false

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.alwaysBounceVertical = true
        sv.showsVerticalScrollIndicator = true
        return sv
    }()

    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 32
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Libreria"
        l.font = .systemFont(ofSize: 34, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let dismissBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.left",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                   for: .normal)
        b.tintColor = .label
        b.backgroundColor = UIColor.systemGray5
        b.layer.cornerRadius = 16
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    /// Riga "Post pubblicati" (basata su Post).
    private var publishedRow: LibraryCategoryRowView?

    /// Righe News/Sport, basate su LibraryItem (con drag&drop).
    private var libraryRows: [LibraryCategory: LibraryItemsRowView] = [:]

    /// Pull-to-refresh sulla scrollView verticale che contiene le righe.
    /// Riapre i listener Firestore (Post + categorie libreria) per forzare
    /// un re-fetch on-demand. Si nasconde quando arrivano gli snapshot di
    /// tutte le sezioni o, in difetto, dopo un timeout di safety.
    private let refreshControl = UIRefreshControl()

    /// Set di chiavi di sezione ancora in attesa del primo snapshot dopo
    /// l'ultimo pull-to-refresh. Quando si svuota nascondiamo lo spinner.
    /// Le chiavi sono raw value di `LibraryCategory` per le righe libreria,
    /// più la costante `Self.publishedKey` per la riga "Post pubblicati".
    private var pendingRefreshSections: Set<String> = []
    private static let publishedKey = "__publishedPosts"

    /// Timer di safety: anche se uno snapshot non arriva (es. listener fallito
    /// in modo silenzioso) chiudiamo lo spinner dopo qualche secondo per non
    /// lasciarlo girare all'infinito.
    private weak var refreshSafetyTimer: Timer?

    // MARK: - Data

    private var publishedPosts: [Post] = []
    private var firestoreListener: ListenerRegistration?
    private var libraryListeners: [LibraryCategory: ListenerRegistration] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    /// Avviamo i listener Firestore in `viewWillAppear` (e li rimuoviamo in
    /// `viewWillDisappear`) invece che in `viewDidLoad`. Motivo: in
    /// `viewDidLoad` il primo snapshot poteva arrivare PRIMA che le row
    /// avessero misurato la propria collectionView, dando un primo
    /// `reloadData` su una view a dimensione zero. Le celle non venivano
    /// renderizzate finché l'utente non faceva un pull-to-refresh manuale,
    /// che nuovamente ricreava i listener — questa volta su view già
    /// dimensionata. Spostando lo start in `viewWillAppear` la prima
    /// snapshot arriva quando la view è già a schermo e laid-out.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observePublishedPosts()
        observeLibraryItems()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        firestoreListener?.remove(); firestoreListener = nil
        libraryListeners.values.forEach { $0.remove() }
        libraryListeners.removeAll()
        refreshSafetyTimer?.invalidate()
        refreshSafetyTimer = nil
    }

    deinit {
        firestoreListener?.remove()
        libraryListeners.values.forEach { $0.remove() }
        refreshSafetyTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupLayout() {
        // Top bar standalone: visibile SOLO quando la VC non è dentro al
        // LibraryHostViewController. Il container fratello fornisce già le
        // tab + il bottone close, quindi in modalità "embed" qui la top bar
        // non serve e la nascondiamo per non sprecare 56pt verticali.
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.isHidden = embedsInHostContainer
        view.addSubview(topBar)

        topBar.addSubview(dismissBtn)
        dismissBtn.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        // Pull-to-refresh sulla scrollView verticale: tirando giù dalla testa
        // della Libreria si riavviano i listener delle righe. Lo spinner
        // sparisce non appena tutte le sezioni hanno ricevuto un nuovo
        // snapshot (o dopo un timeout di safety, vedi `handleRefresh`).
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl.tintColor = .label
        scrollView.refreshControl = refreshControl
        scrollView.alwaysBounceVertical = true     // necessario per innescare il pull anche con poco contenuto

        // Header con il titolo "Libreria". In modalità embed lo nascondiamo
        // perché il tab "Libreria" del container già fa da titolo: avere un
        // secondo "Libreria" gigante sotto sarebbe ridondante e ruberebbe
        // verticale al carosello.
        if !embedsInHostContainer {
            let header = UIView()
            header.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(titleLabel)
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: header.topAnchor),
                titleLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
                titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: header.trailingAnchor, constant: -20),
                titleLabel.bottomAnchor.constraint(equalTo: header.bottomAnchor)
            ])
            stackView.addArrangedSubview(header)
        }

        // Crea una riga per ogni categoria, nell'ordine fissato dall'enum.
        for cat in Category.allCases {
            switch cat {
            case .news:
                let row = makeLibraryItemsRow(category: .news)
                libraryRows[.news] = row
                stackView.addArrangedSubview(row)
            case .sport:
                let row = makeLibraryItemsRow(category: .sport)
                libraryRows[.sport] = row
                stackView.addArrangedSubview(row)
            case .saved:
                let row = makeLibraryItemsRow(category: .saved)
                libraryRows[.saved] = row
                stackView.addArrangedSubview(row)
            case .publishedPosts:
                let row = LibraryCategoryRowView(title: cat.title)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.showEmptyState(message: "Nessun post pubblicato")
                row.onSelectPost = { [weak self] post in
                    self?.openPostDetail(post)
                }
                row.onDoubleTapPost = { [weak self] post in
                    self?.openSourceInCapture(post)
                }
                publishedRow = row
                stackView.addArrangedSubview(row)
            }
        }

        let safe = view.safeAreaLayoutGuide
        // In modalità embed la top bar è hidden: la scrollView parte dal
        // top della safe area (la host top bar è sopra la safe area del
        // child). Senza questa diramazione la scrollView si ancorava al
        // bottom di una topBar nascosta a height 56 → 56pt morti in cima.
        let scrollTopAnchor: NSLayoutYAxisAnchor =
            embedsInHostContainer ? safe.topAnchor : topBar.bottomAnchor

        var constraints: [NSLayoutConstraint] = [
            scrollView.topAnchor.constraint(equalTo: scrollTopAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ]

        if !embedsInHostContainer {
            constraints.append(contentsOf: [
                topBar.topAnchor.constraint(equalTo: safe.topAnchor),
                topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topBar.heightAnchor.constraint(equalToConstant: 56),

                dismissBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                dismissBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
                dismissBtn.widthAnchor.constraint(equalToConstant: 32),
                dismissBtn.heightAnchor.constraint(equalToConstant: 32)
            ])
        } else {
            // In embed la topBar resta nello stack ma a zero height/hidden:
            // basta ancorarla per evitare warning di vincoli ambigui.
            constraints.append(contentsOf: [
                topBar.topAnchor.constraint(equalTo: safe.topAnchor),
                topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                topBar.heightAnchor.constraint(equalToConstant: 0)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Data

    /// Listener Firestore sui post dell'utente loggato. Aggiorna la riga
    /// "Post pubblicati" ogni volta che ricevo nuovi snapshot.
    private func observePublishedPosts() {
        // Sempre rimuoviamo l'eventuale listener precedente prima di
        // ricrearlo: questo metodo viene chiamato sia in viewDidLoad sia
        // dal pull-to-refresh, e non vogliamo registrare due listener.
        firestoreListener?.remove()
        firestoreListener = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            // Nessun utente loggato: la riga resta nello stato vuoto.
            // Liberiamo subito lo spinner di refresh per questa sezione,
            // altrimenti resterebbe in attesa di uno snapshot che non arriva.
            markSectionRefreshed(Self.publishedKey)
            return
        }
        let db = Firestore.firestore()
        firestoreListener = db.collection("posts")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    NSLog("[LibraryViewController] errore listener: \(error.localizedDescription)")
                    // Anche su errore liberiamo lo spinner, altrimenti resta a girare.
                    self.markSectionRefreshed(Self.publishedKey)
                    return
                }
                let posts: [Post] = snapshot?.documents.compactMap {
                    try? $0.data(as: Post.self)
                } ?? []
                self.publishedPosts = posts
                self.publishedRow?.setPosts(
                    posts,
                    emptyMessage: "Nessun post pubblicato"
                )
                self.markSectionRefreshed(Self.publishedKey)
            }
    }

    /// Listener real-time sugli item di libreria per categoria. Ogni snapshot
    /// aggiorna la rispettiva riga; il drag&drop muove documenti tra le due
    /// query, per cui la UI delle due righe si aggiorna automaticamente.
    private func observeLibraryItems() {
        for category in LibraryCategory.allCases {
            libraryListeners[category]?.remove()
            let listener = LibraryService.shared.observe(category: category) {
                [weak self] items in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.libraryRows[category]?.setItems(items)
                    self.markSectionRefreshed(category.rawValue)
                }
            }
            libraryListeners[category] = listener
            // Se observe restituisce nil (utente non loggato) la callback
            // non verrà MAI chiamata: liberiamo subito lo spinner per
            // questa sezione così il pull-to-refresh non rimane in stallo.
            if listener == nil {
                markSectionRefreshed(category.rawValue)
            }
        }
    }

    /// Crea una riga "News" o "Sport" basata su `LibraryItem`, con drag&drop
    /// abilitato. Le due righe condividono il delegate del view controller
    /// così il drop su una riga può tirare via dall'altra cambiando categoria.
    private func makeLibraryItemsRow(category: LibraryCategory) -> LibraryItemsRowView {
        let row = LibraryItemsRowView(title: category.displayName, category: category)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.dragDropCoordinator = self
        row.onSelectItem = { [weak self] item in
            self?.openLibraryItemDetail(item)
        }
        row.onDoubleTapItem = { [weak self] item in
            self?.openLibraryItemSource(item)
        }
        row.onDeleteItem = { [weak self] item in
            self?.deleteLibraryItem(item)
        }
        return row
    }

    private func openLibraryItemDetail(_ item: LibraryItem) {
        // Riusa PostDetailViewController convertendo l'item in un Post leggibile.
        let pseudoPost = Post(
            id: item.id,
            imageURL: item.imageURL,
            sourceURL: item.sourceURL,
            caption: item.caption ?? "",
            authorId: item.ownerId,
            authorName: "",
            authorPhotoURL: nil,
            createdAt: item.createdAt
        )
        let vc = PostDetailViewController(post: pseudoPost)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    private func openLibraryItemSource(_ item: LibraryItem) {
        guard let urlString = item.sourceURL,
              let url = URL(string: urlString) else { return }
        let window = view.window
        if let w = window {
            let transition = CATransition()
            transition.duration = 0.35
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            w.layer.add(transition, forKey: kCATransition)
        }
        // `dismiss` su un VC figlio risale automaticamente la catena dei
        // parent fino a trovare il VC presentato (Apple docs: "the system
        // forwards the message to the receiver's nearest ancestor that
        // did"). Quindi funziona sia in standalone (self è il presented)
        // sia in embed (è il LibraryHostViewController a essere stato
        // presentato).
        dismiss(animated: false) {
            guard let tab = window?.rootViewController as? MainTabBarController,
                  let vcs = tab.viewControllers, vcs.count > 1 else { return }
            tab.selectedIndex = 1
            if let screenshotVC = vcs[1] as? ScreenshotViewController {
                screenshotVC.loadURL(url)
            }
        }
    }

    private func deleteLibraryItem(_ item: LibraryItem) {
        guard let itemId = item.id else { return }
        LibraryService.shared.delete(itemId: itemId) { [weak self] result in
            DispatchQueue.main.async {
                if case let .failure(error) = result, let window = self?.view.window {
                    ToastView.show(message: "Eliminazione non riuscita: \(error.localizedDescription)",
                                   in: window)
                }
            }
        }
    }

    // MARK: - Actions

    /// Pull-to-refresh: riavvia tutti i listener (Post pubblicati + le righe
    /// di libreria) e tiene attivo lo spinner finché tutte le sezioni non
    /// hanno restituito un nuovo snapshot. Un timer di safety chiude
    /// comunque lo spinner dopo qualche secondo per evitare loop.
    @objc private func handleRefresh() {
        // Reset del set: dichiariamo "in attesa" tutte le sezioni.
        var pending: Set<String> = [Self.publishedKey]
        for cat in LibraryCategory.allCases {
            pending.insert(cat.rawValue)
        }
        pendingRefreshSections = pending

        // Riavviamo i listener: ognuno chiama markSectionRefreshed alla
        // ricezione del primo snapshot (o subito su errore / utente non loggato).
        observePublishedPosts()
        observeLibraryItems()

        // Safety timer: in casi limite (rete molto lenta, listener che non
        // emettono) chiudiamo lo spinner dopo 5s comunque.
        refreshSafetyTimer?.invalidate()
        refreshSafetyTimer = Timer.scheduledTimer(withTimeInterval: 5.0,
                                                  repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.pendingRefreshSections.removeAll()
            self.endRefreshingIfReady()
        }
    }

    /// Chiamato da ogni listener quando ha aggiornato la propria sezione
    /// dopo un pull-to-refresh. Quando tutte le sezioni hanno risposto,
    /// nascondiamo lo spinner.
    private func markSectionRefreshed(_ key: String) {
        guard !pendingRefreshSections.isEmpty else { return }
        pendingRefreshSections.remove(key)
        endRefreshingIfReady()
    }

    /// Se non c'è più nessuna sezione "in attesa", chiude lo spinner di
    /// refresh. Idempotente: si può chiamare anche se lo spinner non è
    /// attivo. Garantisce esecuzione su main (i listener di LibraryService
    /// callback su main, ma quello di Firestore "posts" callback su una
    /// queue interna del SDK).
    private func endRefreshingIfReady() {
        let action: () -> Void = { [weak self] in
            guard let self = self else { return }
            guard self.pendingRefreshSections.isEmpty else { return }
            self.refreshSafetyTimer?.invalidate()
            self.refreshSafetyTimer = nil
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
        }
        if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
    }

    @objc private func handleDismiss() {
        // Animazione personalizzata: slide verso destra (inverso dell'ingresso).
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.35
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        dismiss(animated: false)
    }

    private func openPostDetail(_ post: Post) {
        let vc = PostDetailViewController(post: post)
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }

    /// Doppio tap su una copertina: chiude la libreria con animazione
    /// inversa (slide a destra) e carica la pagina sorgente nella tab Cattura.
    private func openSourceInCapture(_ post: Post) {
        guard let urlString = post.sourceURL,
              let url = URL(string: urlString) else {
            // Post legacy senza sourceURL: niente da fare.
            return
        }
        // Catturo la window prima del dismiss, perché dopo view.window è nil.
        let window = view.window
        if let w = window {
            let transition = CATransition()
            transition.duration = 0.35
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            w.layer.add(transition, forKey: kCATransition)
        }
        // `dismiss` risale al VC presentato (in embed = host container;
        // in standalone = self) in entrambi i casi.
        dismiss(animated: false) {
            guard let tab = window?.rootViewController as? MainTabBarController,
                  let vcs = tab.viewControllers, vcs.count > 1 else { return }
            tab.selectedIndex = 1
            if let screenshotVC = vcs[1] as? ScreenshotViewController {
                screenshotVC.loadURL(url)
            }
        }
    }
}

// MARK: - LibraryDragDropCoordinator

extension LibraryViewController: LibraryDragDropCoordinator {

    func libraryRow(_ row: LibraryItemsRowView,
                    didDrop item: LibraryItem,
                    at destinationIndex: Int,
                    in targetCategory: LibraryCategory) {
        guard let itemId = item.id else { return }

        // Snapshot della riga di destinazione (cache locale alimentata dal
        // listener real-time). Da questa lista calcoliamo la `position` da
        // assegnare al documento droppato.
        let destItems = libraryRows[targetCategory]?.currentItems ?? []
        let isSameCategoryReorder = (item.category == targetCategory)

        // Per il reorder same-category dobbiamo escludere l'item draggato
        // dal calcolo degli adiacenti, altrimenti l'interpolazione userebbe
        // la sua stessa `position` come riferimento (no-op o jitter).
        var adjacent = destItems
        if isSameCategoryReorder {
            adjacent.removeAll { $0.id == itemId }
        }

        // Aggiusto l'indice destinazione quando si trascina nella STESSA
        // categoria spostandosi *verso il basso*: rimuovendo l'item dalla
        // sua posizione corrente, tutti gli indici successivi scalano di -1.
        // Senza questa correzione un drop "subito dopo me stesso" finirebbe
        // due slot più in là di quanto l'utente vede sull'indicatore UIKit.
        var adjustedIndex = destinationIndex
        if isSameCategoryReorder,
           let currentIndex = destItems.firstIndex(where: { $0.id == itemId }),
           destinationIndex > currentIndex {
            adjustedIndex = max(0, destinationIndex - 1)
        }
        adjustedIndex = min(max(adjustedIndex, 0), adjacent.count)

        let newPosition = LibraryService.shared.computePosition(at: adjustedIndex, in: adjacent)
        // Passiamo la category solo se cambia: evita updateData inutili e
        // mantiene il documento "più fermo" possibile per i listener.
        let newCategory: LibraryCategory? = isSameCategoryReorder ? nil : targetCategory

        // OPTIMISTIC UI: applichiamo localmente la mossa SUBITO, prima di
        // attendere la risposta Firestore. Senza questo, un drop cross-row
        // mostrava la cella ferma nella riga sorgente finché il listener
        // non riceveva il nuovo snapshot dal server (a volte secondi),
        // dando la sensazione che il drag non avesse fatto nulla. Salviamo
        // gli stati pre-update per poter fare rollback se Firestore rifiuta.
        let previousSourceItems = libraryRows[item.category]?.currentItems ?? []
        let previousDestItems = destItems

        var movedItem = item
        movedItem.position = newPosition
        if !isSameCategoryReorder {
            movedItem.category = targetCategory
        }

        if !isSameCategoryReorder {
            // Cross-category: rimuoviamo dalla riga sorgente.
            let newSource = previousSourceItems.filter { $0.id != itemId }
            libraryRows[item.category]?.setItems(newSource)
        }
        // In ogni caso reinseriamo l'item nella destinazione all'indice
        // corretto. (filter è no-op per cross-category, rimuove il
        // duplicato per same-category-reorder.)
        var newDest = previousDestItems.filter { $0.id != itemId }
        let insertIndex = min(max(adjustedIndex, 0), newDest.count)
        newDest.insert(movedItem, at: insertIndex)
        libraryRows[targetCategory]?.setItems(newDest)

        LibraryService.shared.reorder(itemId: itemId,
                                       to: newPosition,
                                       category: newCategory) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if case let .failure(error) = result {
                    // Rollback all'ultimo stato visivo noto.
                    self.libraryRows[item.category]?.setItems(previousSourceItems)
                    self.libraryRows[targetCategory]?.setItems(previousDestItems)
                    if let window = self.view.window {
                        ToastView.show(message: "Spostamento non riuscito: \(error.localizedDescription)",
                                       in: window)
                    }
                }
                // Successo: il listener real-time eventualmente conferma
                // con gli stessi dati che abbiamo già messo localmente,
                // setItems sarà chiamato di nuovo ma con lo stesso ordine
                // → reloadData no-op visivo.
            }
        }
    }
}

// MARK: - LibraryCategoryRowView

/// Riga di una categoria: titolo grande + carosello orizzontale di copertine.
/// Se non ci sono post da mostrare, espone un placeholder testuale al centro.
final class LibraryCategoryRowView: UIView,
                                    UICollectionViewDataSource,
                                    UICollectionViewDelegate,
                                    UICollectionViewDelegateFlowLayout {

    /// Callback invocata al tap singolo su una cella post.
    var onSelectPost: ((Post) -> Void)?
    /// Callback invocata al doppio tap su una cella post.
    var onDoubleTapPost: ((Post) -> Void)?

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let collectionView: UICollectionView

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .medium)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    // MARK: - Data

    private var posts: [Post] = []

    // MARK: - Init

    init(title: String) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal           // scroll orizzontale sx → dx
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: .zero)
        self.titleLabel.text = title

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(LibraryCoverCell.self,
                                forCellWithReuseIdentifier: LibraryCoverCell.reuseID)

        addSubview(titleLabel)
        addSubview(collectionView)
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 240),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - API

    /// Sostituisce il dataset; mostra il placeholder se vuoto.
    func setPosts(_ posts: [Post], emptyMessage: String) {
        self.posts = posts
        if posts.isEmpty {
            showEmptyState(message: emptyMessage)
        } else {
            emptyLabel.isHidden = true
            collectionView.isHidden = false
            collectionView.reloadData()
        }
    }

    /// Forza lo stato vuoto con il messaggio fornito.
    func showEmptyState(message: String) {
        posts = []
        emptyLabel.text = message
        emptyLabel.isHidden = false
        collectionView.isHidden = false   // resta visibile per mantenere altezza
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryCoverCell.reuseID,
            for: indexPath) as! LibraryCoverCell
        let post = posts[indexPath.item]
        cell.configure(with: post)
        cell.onSingleTap = { [weak self] in
            self?.onSelectPost?(post)
        }
        cell.onDoubleTap = { [weak self] in
            self?.onDoubleTapPost?(post)
        }
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Cella stile copertina libro: altezza fissa, larghezza ratio 2:3.
        let height: CGFloat = 240
        let width: CGFloat = height * (2.0 / 3.0)
        return CGSize(width: width, height: height)
    }
}

// MARK: - LibraryCoverCell

/// Cella stile copertina libro: immagine a tutta cella con angoli arrotondati
/// e ombra morbida. Mostra un pulsante "×" in alto a destra per eliminare l'item.
/// L'immagine è caricata async dall'URL Firebase Storage e memorizzata in cache.
final class LibraryCoverCell: UICollectionViewCell {
    static let reuseID = "LibraryCoverCell"

    /// Tap singolo sulla cella (apre il dettaglio).
    var onSingleTap: (() -> Void)?
    /// Tap doppio sulla cella (riapre la pagina sorgente nella tab Cattura).
    var onDoubleTap: (() -> Void)?
    /// Tap sulla X (elimina l'item dalla libreria).
    var onDelete: (() -> Void)?

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.layer.cornerCurve = .continuous
        iv.backgroundColor = .Brand.creamSurface
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .Brand.goldPrimary
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    /// Pulsante X in alto a destra per eliminare l'item.
    private let deleteButton: UIButton = {
        let b = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        b.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        b.tintColor = .white
        b.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        b.layer.cornerRadius = 12
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var currentLoadURL: URL?
    private var imageLoadTask: URLSessionDataTask?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // Ombra sulla cella per profondità "copertina".
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 8
        layer.masksToBounds = false

        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        contentView.addSubview(imageView)
        contentView.addSubview(spinner)
        contentView.addSubview(deleteButton)

        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            deleteButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            deleteButton.widthAnchor.constraint(equalToConstant: 24),
            deleteButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Gesti: single-tap apre il dettaglio, double-tap riapre la sorgente.
        // Single richiede che il double fallisca per evitare doppio fire.
        let single = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        single.numberOfTapsRequired = 1
        let double = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        double.numberOfTapsRequired = 2
        single.require(toFail: double)
        contentView.addGestureRecognizer(single)
        contentView.addGestureRecognizer(double)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        currentLoadURL = nil
        imageLoadTask?.cancel()
        imageLoadTask = nil
        onSingleTap = nil
        onDoubleTap = nil
        onDelete = nil
        spinner.stopAnimating()
    }

    @objc private func handleSingleTap() { onSingleTap?() }
    @objc private func handleDoubleTap() { onDoubleTap?() }
    @objc private func handleDelete() { onDelete?() }

    func configure(with post: Post) {
        deleteButton.isHidden = true   // i Post pubblicati non si eliminano da qui
        loadImage(from: post.imageURL)
    }

    /// Variante usata per gli item di libreria (News/Sport): mostra la X.
    func configure(with item: LibraryItem) {
        deleteButton.isHidden = false
        loadImage(from: item.imageURL)
    }

    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }

        imageLoadTask?.cancel()
        imageLoadTask = nil

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
}
