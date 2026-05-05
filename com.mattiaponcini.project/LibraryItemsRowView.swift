//
//  LibraryItemsRowView.swift
//  Flotip
//
//  Riga di una categoria "personale" della Libreria (News o Sport).
//  Visivamente simile a `LibraryCategoryRowView` (titolo + carosello orizzontale
//  di copertine) ma:
//  - i dati sono `LibraryItem` invece di `Post`
//  - supporta drag&drop tra News e Sport via UICollectionViewDragDelegate /
//    UICollectionViewDropDelegate
//
//  Il drop effettivo (cambio categoria su Firestore) è delegato al view
//  controller padre tramite `LibraryDragDropCoordinator`, così entrambe le
//  righe condividono lo stesso "router" e il listener real-time aggiornerà
//  in automatico la riga sorgente e quella destinazione.
//

import UIKit

// MARK: - Coordinator protocol

/// Implementato dal view controller che ospita le due righe News/Sport.
/// Riceve il drop e si occupa di scrivere `position` (e opzionalmente
/// `category`) sul documento Firestore.
protocol LibraryDragDropCoordinator: AnyObject {
    /// Chiamato quando un item è stato droppato in una riga di categoria.
    /// - `destinationIndex` è l'indice di inserimento *visivo* nella collection
    ///   destinazione (può valere `items.count` per il drop in coda).
    /// - `targetCategory` è la categoria della riga ricevente, che può
    ///   coincidere con `item.category` (in tal caso si tratta di un puro
    ///   reorder dentro la stessa categoria).
    func libraryRow(_ row: LibraryItemsRowView,
                    didDrop item: LibraryItem,
                    at destinationIndex: Int,
                    in targetCategory: LibraryCategory)
}

// MARK: - LibraryItemsRowView

final class LibraryItemsRowView: UIView,
                                 UICollectionViewDataSource,
                                 UICollectionViewDelegate,
                                 UICollectionViewDelegateFlowLayout,
                                 UICollectionViewDragDelegate,
                                 UICollectionViewDropDelegate {

    /// Categoria associata a questa riga (immutabile dopo init).
    let category: LibraryCategory

    /// Coordinator centrale per i drop cross-row. Weak per evitare retain cycle.
    weak var dragDropCoordinator: LibraryDragDropCoordinator?

    /// Tap singolo su una cella → apertura dettaglio.
    var onSelectItem: ((LibraryItem) -> Void)?
    /// Tap doppio → riapri sorgente nella tab Cattura.
    var onDoubleTapItem: ((LibraryItem) -> Void)?
    /// Tap sulla X → elimina l'item.
    var onDeleteItem: ((LibraryItem) -> Void)?

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

    /// Background usato per evidenziare la riga quando un drag passa sopra.
    /// Trasparente di default; si tinge di crema quando entra un drag.
    private let dropHighlightView: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0
        v.layer.borderColor = UIColor.Brand.goldSecondary.cgColor
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Data

    private var items: [LibraryItem] = []

    // MARK: - Init

    init(title: String, category: LibraryCategory) {
        self.category = category

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
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

        // Drag & drop nativi: il timing del long-press e la transizione
        // verso il drag session sono gestiti da UIKit, evitando conflitti
        // col single-tap sulla cella.
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dragInteractionEnabled = true

        addSubview(dropHighlightView)
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

            dropHighlightView.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: -4),
            dropHighlightView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            dropHighlightView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dropHighlightView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 4),

            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])

        // Testo dell'empty state pronto, ma label nascosta finché non
        // arriva il PRIMO snapshot del listener: evitiamo il flash
        // "Nessun salvataggio" durante il caricamento iniziale, che era
        // particolarmente fastidioso quando lo snapshot poi conteneva
        // delle copertine.
        // Per la categoria "Salvati" il messaggio è leggermente diverso
        // perché si riferisce ai post messi da parte dal feed, non ai
        // contenuti caricati dal composer.
        switch category {
        case .saved:
            emptyLabel.text = "Nessun post salvato"
        case .news, .sport:
            emptyLabel.text = "Nessun salvataggio in \(category.displayName)"
        }
        emptyLabel.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - API

    func setItems(_ items: [LibraryItem]) {
        self.items = items
        emptyLabel.isHidden = !items.isEmpty
        collectionView.reloadData()
    }

    /// Snapshot della lista corrente (read-only). Usato dal coordinator per
    /// calcolare la nuova `position` rispetto agli adiacenti senza dover
    /// duplicare la cache lato view controller.
    var currentItems: [LibraryItem] { items }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibraryCoverCell.reuseID,
            for: indexPath) as! LibraryCoverCell
        let item = items[indexPath.item]
        cell.configure(with: item)
        cell.onSingleTap = { [weak self] in
            self?.onSelectItem?(item)
        }
        cell.onDoubleTap = { [weak self] in
            self?.onDoubleTapItem?(item)
        }
        cell.onDelete = { [weak self] in
            self?.onDeleteItem?(item)
        }
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let height: CGFloat = 240
        let width: CGFloat = height * (2.0 / 3.0)
        return CGSize(width: width, height: height)
    }

    // MARK: - UICollectionViewDragDelegate

    /// Crea il drag item per la cella. Usiamo `localObject` per portarci
    /// dietro il `LibraryItem` originale: niente serializzazione, niente
    /// conversioni a tipi NS.
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        guard indexPath.item < items.count else { return [] }
        let item = items[indexPath.item]
        // L'item provider ha bisogno di qualcosa di trasportabile fuori app:
        // mettiamo l'id come stringa, ma il payload "vero" viaggia su localObject
        // (così non perdiamo la categoria e non dobbiamo fare round-trip Firestore).
        let provider = NSItemProvider(object: (item.id ?? "") as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = item
        return [dragItem]
    }

    /// Anteprima del drag (cella sollevata): usa la stessa cella con sfondo
    /// trasparente, così sembra "staccarsi" dalla riga senza salti visivi.
    func collectionView(_ collectionView: UICollectionView,
                        dragPreviewParametersForItemAt indexPath: IndexPath)
                        -> UIDragPreviewParameters? {
        let params = UIDragPreviewParameters()
        params.backgroundColor = .clear
        if let cell = collectionView.cellForItem(at: indexPath) {
            // Mantiene gli angoli arrotondati anche durante il drag.
            params.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 8)
        }
        return params
    }

    /// Permettiamo solo drag locali da quest'app: drop su News/Sport/Salvati.
    /// La riga "Post pubblicati" è gestita da `LibraryCategoryRowView` (read-only)
    /// e non passa da qui: non può quindi né originare né ricevere drop.
    func collectionView(_ collectionView: UICollectionView,
                        canHandle session: UIDropSession) -> Bool {
        return session.localDragSession != nil
    }

    // MARK: - UICollectionViewDropDelegate

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?)
                        -> UICollectionViewDropProposal {
        // Accettiamo solo drag locali (provenienti dalle nostre righe).
        guard let local = session.localDragSession,
              let dragItem = local.items.first,
              let libraryItem = dragItem.localObject as? LibraryItem else {
            return UICollectionViewDropProposal(operation: .forbidden)
        }
        // Same-category → reorder (.move): UIKit non duplica la cella.
        // Cross-category → .copy: l'item resta nella riga sorgente finché il
        // listener Firestore non rimuove il documento dalla query precedente,
        // evitando flicker visivi durante l'animazione.
        // In entrambi i casi `insertAtDestinationIndexPath` mostra l'indicatore
        // di inserimento (la classica "barra blu" tra due celle) così l'utente
        // vede esattamente dove andrà a finire l'item.
        let operation: UIDropOperation = (libraryItem.category == self.category) ? .move : .copy
        return UICollectionViewDropProposal(operation: operation,
                                            intent: .insertAtDestinationIndexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidEnter session: UIDropSession) {
        setDropHighlight(active: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidExit session: UIDropSession) {
        setDropHighlight(active: false)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidEnd session: UIDropSession) {
        setDropHighlight(active: false)
    }

    func collectionView(_ collectionView: UICollectionView,
                        performDropWith coordinator: UICollectionViewDropCoordinator) {
        setDropHighlight(active: false)

        // Se il coordinator non fornisce un destinationIndexPath (drop su area
        // vuota o oltre l'ultimo elemento) trattiamo l'inserimento come "in
        // coda": l'indice è pari al count corrente.
        let destinationIndexPath = coordinator.destinationIndexPath
            ?? IndexPath(item: items.count, section: 0)
        let destIndex = destinationIndexPath.item

        for dropItem in coordinator.items {
            guard let libraryItem = dropItem.dragItem.localObject as? LibraryItem else { continue }

            // Notifica il view controller padre: applica l'optimistic insert
            // (rimozione dalla riga sorgente per cross-category, insert qui)
            // e poi calcola la `position` interpolata + scrive su Firestore.
            // Al ritorno la cella di destinazione è già nel nostro data source
            // grazie al `setItems()` → `reloadData()` invocato dal coordinator.
            dragDropCoordinator?.libraryRow(self,
                                            didDrop: libraryItem,
                                            at: destIndex,
                                            in: self.category)

            // Forziamo un layout pass dopo il reloadData() dell'optimistic
            // insert: senza questo, `layoutAttributesForItem` può restituire
            // nil per un frame e mandava il vecchio fallback a (bounds.minX + 80,
            // midY) — il punto sulla SINISTRA della collection. È esattamente
            // lì che si vedeva la "copia" del preview scivolare via prima di
            // sparire. Dopo `layoutIfNeeded` le attrs sono pronte e UIKit può
            // animare verso la cella reale.
            collectionView.layoutIfNeeded()

            // L'indice "vero" del dropped item dopo l'optimistic insert può
            // differire dal `destIndex` ricevuto: per il same-category
            // drag-verso-il-basso il view controller scala l'indice di -1
            // (vedi `adjustedIndex` in `LibraryViewController.libraryRow`).
            // Cerchiamo quindi per id la posizione effettiva nella cache.
            let landingIndex = items.firstIndex(where: { $0.id == libraryItem.id })
                ?? min(destIndex, max(items.count - 1, 0))

            if landingIndex < items.count {
                // Lasciamo a UIKit il calcolo del landing point: `drop(toItemAt:)`
                // anima il preview esattamente sulla cella di destinazione,
                // niente più snap verso sinistra dovuto a layoutAttributes
                // ancora non pronte.
                let landingIndexPath = IndexPath(item: landingIndex, section: 0)
                coordinator.drop(dropItem.dragItem, toItemAt: landingIndexPath)
            } else {
                // Riga davvero vuota (caso limite: optimistic insert non andato
                // a buon fine). Atterriamo al centro della collection come
                // fallback sicuro, non più sul bordo sinistro.
                let target = UIDragPreviewTarget(
                    container: collectionView,
                    center: CGPoint(x: collectionView.bounds.midX,
                                    y: collectionView.bounds.midY)
                )
                coordinator.drop(dropItem.dragItem, to: target)
            }
        }
    }

    // MARK: - Helpers

    private func setDropHighlight(active: Bool) {
        UIView.animate(withDuration: 0.18) {
            self.dropHighlightView.backgroundColor = active
                ? UIColor.Brand.creamSurface.withAlphaComponent(0.7)
                : .clear
            self.dropHighlightView.layer.borderWidth = active ? 1.5 : 0
        }
    }
}
