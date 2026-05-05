//
//  LibraryService.swift
//  Flotip
//
//  Servizio Firebase per la "Libreria personale" (News / Sport).
//  - Upload immagine su Storage in `library/{uid}/{itemId}.jpg`
//  - Scrittura documento in Firestore collection `libraryItems`
//  - Listener real-time per categoria
//  - Cambio categoria (drag&drop tra News e Sport)
//
//  È deliberatamente separato da `PostService`: i contenuti salvati in
//  libreria NON finiscono nel feed pubblico.
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

private let libraryLog = OSLog(subsystem: "com.mattiaponcini.project", category: "LibraryService")

enum LibraryError: LocalizedError {
    case notLoggedIn
    case imageEncoding
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:       return "Devi essere loggato per salvare in libreria."
        case .imageEncoding:     return "Impossibile elaborare l'immagine."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

final class LibraryService {

    static let shared = LibraryService()
    private init() {}

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var collectionRef: CollectionReference {
        db.collection("libraryItems")
    }

    // MARK: - Salvataggio

    /// Carica l'immagine su Storage e crea il documento `LibraryItem`.
    /// `category` è scelta dall'utente nell'action sheet del composer.
    func save(image: UIImage,
              category: LibraryCategory,
              caption: String?,
              sourceURL: String?,
              completion: @escaping (Result<LibraryItem, Error>) -> Void) {

        // Guard esplicito: se per qualche motivo (logout silenzioso, token
        // scaduto, ecc.) l'utente non è autenticato al momento del save,
        // restituiamo subito un errore parlante invece di lasciar fallire
        // la write con un generico "permission denied" lato Firebase.
        guard let user = Auth.auth().currentUser else {
            os_log("save: utente non autenticato", log: libraryLog, type: .error)
            completion(.failure(LibraryError.notLoggedIn))
            return
        }
        let uid = user.uid
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            os_log("save: impossibile codificare immagine in JPEG", log: libraryLog, type: .error)
            completion(.failure(LibraryError.imageEncoding))
            return
        }

        // Pre-genera l'id del documento così possiamo riusarlo come nome file.
        let itemId = collectionRef.document().documentID
        let storagePath = "library/\(uid)/\(itemId).jpg"
        let ref = storage.reference().child(storagePath)

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        os_log("save: upload start uid=%{public}@ path=%{public}@", log: libraryLog, type: .info, uid, storagePath)

        ref.putData(data, metadata: metadata) { [weak self] _, error in
            if let error = error {
                let ns = error as NSError
                os_log("save: Storage upload FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                       log: libraryLog, type: .error,
                       ns.domain, ns.code, ns.localizedDescription)
                completion(.failure(LibraryError.underlying(error)))
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    let ns = error as NSError
                    os_log("save: Storage downloadURL FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                           log: libraryLog, type: .error,
                           ns.domain, ns.code, ns.localizedDescription)
                    completion(.failure(LibraryError.underlying(error)))
                    return
                }
                guard let urlString = url?.absoluteString else {
                    os_log("save: downloadURL returned nil URL", log: libraryLog, type: .error)
                    completion(.failure(LibraryError.underlying(NSError(
                        domain: "LibraryService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "URL immagine mancante."]
                    ))))
                    return
                }
                self?.writeDocument(
                    id: itemId,
                    ownerId: uid,
                    category: category,
                    imageURL: urlString,
                    sourceURL: sourceURL,
                    caption: caption,
                    completion: completion
                )
            }
        }
    }

    private func writeDocument(id: String,
                               ownerId: String,
                               category: LibraryCategory,
                               imageURL: String,
                               sourceURL: String?,
                               caption: String?,
                               originalPostId: String? = nil,
                               completion: @escaping (Result<LibraryItem, Error>) -> Void) {
        // Per default i nuovi item finiscono in cima alla riga della loro
        // categoria. Visto che l'ordinamento è `position asc`, "in cima"
        // significa avere la position più piccola: usiamo `-now` così ogni
        // nuovo salvataggio scivola davanti a quello immediatamente precedente
        // senza scontrarsi con le position dei vicini.
        let now = Date()
        var item = LibraryItem(
            id: nil,                  // gestito da @DocumentID lato lettura
            ownerId: ownerId,
            category: category,
            imageURL: imageURL,
            sourceURL: sourceURL,
            caption: (caption?.isEmpty == true) ? nil : caption,
            createdAt: now,
            position: -now.timeIntervalSince1970,
            originalPostId: originalPostId
        )
        do {
            try collectionRef.document(id).setData(from: item) { error in
                if let error = error {
                    let ns = error as NSError
                    os_log("writeDocument: Firestore setData FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                           log: libraryLog, type: .error,
                           ns.domain, ns.code, ns.localizedDescription)
                    completion(.failure(LibraryError.underlying(error)))
                } else {
                    os_log("writeDocument: success id=%{public}@", log: libraryLog, type: .info, id)
                    item.id = id
                    completion(.success(item))
                }
            }
        } catch {
            let ns = error as NSError
            os_log("writeDocument: encoding threw domain=%{public}@ code=%{public}d desc=%{public}@",
                   log: libraryLog, type: .error,
                   ns.domain, ns.code, ns.localizedDescription)
            completion(.failure(LibraryError.underlying(error)))
        }
    }

    // MARK: - Salvataggio "bookmark" di un Post altrui

    /// Salva nel "Salvati" dell'utente loggato un Post pubblicato da un altro
    /// utente. NON ricarica l'immagine su Storage: riusa l'`imageURL` del post
    /// originale (Storage è già pubblico/leggibile per gli URL canonici di
    /// download generati al momento della pubblicazione).
    ///
    /// È idempotente: se esiste già un LibraryItem con lo stesso
    /// `(ownerId, originalPostId)`, ritorna quel record invece di crearne
    /// un duplicato.
    func savePost(_ post: Post,
                  completion: @escaping (Result<LibraryItem, Error>) -> Void) {
        guard let user = Auth.auth().currentUser else {
            completion(.failure(LibraryError.notLoggedIn))
            return
        }
        guard let postId = post.id else {
            completion(.failure(LibraryError.underlying(NSError(
                domain: "LibraryService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Post senza ID, impossibile salvare."]
            ))))
            return
        }
        let uid = user.uid

        // Idempotenza: prima di scrivere controlliamo se esiste già il record.
        // Una query equality (ownerId + originalPostId) basta: nessun composite
        // index richiesto perché Firestore ammette fino a 2 equality filter
        // senza indice esplicito.
        collectionRef
            .whereField("ownerId", isEqualTo: uid)
            .whereField("originalPostId", isEqualTo: postId)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(LibraryError.underlying(error)))
                    return
                }
                if let doc = snapshot?.documents.first,
                   let existing = try? doc.data(as: LibraryItem.self) {
                    // Già salvato: ritorniamo direttamente.
                    completion(.success(existing))
                    return
                }
                // Non c'è nessun item esistente: creiamo il documento riusando
                // l'imageURL del post (no upload Storage).
                let itemId = self?.collectionRef.document().documentID
                    ?? UUID().uuidString
                self?.writeDocument(
                    id: itemId,
                    ownerId: uid,
                    category: .saved,
                    imageURL: post.imageURL,
                    sourceURL: post.sourceURL,
                    caption: post.caption,
                    originalPostId: postId,
                    completion: completion
                )
            }
    }

    /// Cancella tutti i LibraryItem dell'utente loggato che riferiscono il
    /// `postId` indicato. Tipicamente è 0 o 1 documento (l'idempotenza di
    /// `savePost` evita duplicati), ma facciamo un batch defensive per
    /// gestire eventuali residui.
    func unsavePost(postId: String,
                    completion: ((Result<Void, Error>) -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion?(.failure(LibraryError.notLoggedIn))
            return
        }
        collectionRef
            .whereField("ownerId", isEqualTo: uid)
            .whereField("originalPostId", isEqualTo: postId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion?(.failure(LibraryError.underlying(error)))
                    return
                }
                guard let self = self else {
                    completion?(.success(()))
                    return
                }
                let docs = snapshot?.documents ?? []
                if docs.isEmpty {
                    completion?(.success(()))
                    return
                }
                let batch = self.db.batch()
                for d in docs { batch.deleteDocument(d.reference) }
                batch.commit { err in
                    if let err = err {
                        completion?(.failure(LibraryError.underlying(err)))
                    } else {
                        completion?(.success(()))
                    }
                }
            }
    }

    /// Listener real-time sui salvataggi dell'utente loggato per uno specifico
    /// `originalPostId`. Restituisce `true` finché esiste almeno un documento
    /// che lega l'utente a quel post. Usato dal FeedCell per riflettere lo
    /// stato visivo del bottone "Salva" senza polling.
    @discardableResult
    func observeIsPostSaved(postId: String,
                            onChange: @escaping (Bool) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            // Nessun utente loggato: lo stato è "non salvato" e zero update.
            onChange(false)
            return nil
        }
        return collectionRef
            .whereField("ownerId", isEqualTo: uid)
            .whereField("originalPostId", isEqualTo: postId)
            .limit(to: 1)
            .addSnapshotListener { snapshot, _ in
                let isSaved = (snapshot?.documents.isEmpty == false)
                onChange(isSaved)
            }
    }

    // MARK: - Listener real-time per categoria

    /// Snapshot listener su tutti gli item dell'utente loggato in una data categoria.
    ///
    /// La query Firestore usa SOLO due equality filter (`ownerId` + `category`):
    /// niente `order(by:)` lato server. Ordiniamo client-side perché:
    ///   - evitiamo di richiedere un indice composito
    ///     (`ownerId asc, category asc, position asc`) che andrebbe creato a mano
    ///     in console Firebase;
    ///   - gli item legacy non hanno `position` e con `order(by: "position")`
    ///     verrebbero esclusi del tutto dal risultato (Firestore esclude i doc
    ///     a cui manca il campo di ordinamento, anche se passano i where).
    ///
    /// Sort applicato in memoria: `position asc` primario, con `createdAt desc`
    /// come tiebreak/fallback per gli item ancora senza `position`.
    /// Restituisce la `ListenerRegistration` per il dispose.
    @discardableResult
    func observe(category: LibraryCategory,
                 onChange: @escaping ([LibraryItem]) -> Void) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            os_log("observe(%{public}@): NO uid (utente non loggato), listener non attivato",
                   log: libraryLog, type: .error, category.rawValue)
            return nil
        }
        os_log("observe(%{public}@): attaching listener uid=%{public}@",
               log: libraryLog, type: .info, category.rawValue, uid)
        return collectionRef
            .whereField("ownerId", isEqualTo: uid)
            .whereField("category", isEqualTo: category.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    let ns = error as NSError
                    // Se Firestore richiede un indice composito, il messaggio
                    // contiene un URL https://console.firebase.google.com/...
                    // per crearlo con un click. Lo stampiamo intatto così
                    // l'utente lo può aprire dal Console.app filtrando per
                    // questo subsystem/category.
                    os_log("observe(%{public}@): listener FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                           log: libraryLog, type: .error,
                           category.rawValue, ns.domain, ns.code, ns.localizedDescription)
                    // NB: NON chiamiamo onChange([]) sull'errore, altrimenti
                    // un singolo errore transiente (rete che ballotta, token
                    // che si rinfresca) cancellerebbe le copertine già a
                    // schermo per poi rimetterle al prossimo snapshot —
                    // l'utente vede un flash "vuoto" sgradevole. Lasciamo
                    // l'ultima cache visibile e ci affidiamo al prossimo
                    // snapshot di successo per aggiornarla.
                    return
                }
                let docs = snapshot?.documents ?? []
                let raw: [LibraryItem] = docs.compactMap {
                    try? $0.data(as: LibraryItem.self)
                }
                os_log("observe(%{public}@): snapshot received docs=%{public}d decoded=%{public}d",
                       log: libraryLog, type: .info,
                       category.rawValue, docs.count, raw.count)

                // Soft-migration: per ogni item ancora privo di `position` scriviamo
                // `-createdAt.timeIntervalSince1970`. Negativo perché il sort è asc
                // ma l'ordine storico era newest-first: così il nuovo ordine "by
                // position" combacia con il vecchio "by createdAt desc". È
                // fire-and-forget; il prossimo snapshot vedrà il campo aggiornato.
                self?.migrateLegacyPositionsIfNeeded(raw)

                // Sort: position asc primario; fallback createdAt desc per gli
                // item che il listener vede subito prima che la migrazione abbia
                // committato (oppure se la write fallisce). A parità di position
                // (improbabile ma possibile) usiamo createdAt desc come tiebreak.
                let sorted = raw.sorted { lhs, rhs in
                    switch (lhs.position, rhs.position) {
                    case let (l?, r?):
                        if l == r { return lhs.createdAt > rhs.createdAt }
                        return l < r
                    case (_?, nil):
                        return true                       // chi ha position viene prima
                    case (nil, _?):
                        return false
                    case (nil, nil):
                        return lhs.createdAt > rhs.createdAt
                    }
                }
                onChange(sorted)
            }
    }

    /// Soft-migration delle position mancanti. Idempotente: se l'item ha già
    /// `position` non fa nulla. Le scritture sono indipendenti per documento
    /// e non bloccano il caller.
    private func migrateLegacyPositionsIfNeeded(_ items: [LibraryItem]) {
        for item in items where item.position == nil {
            guard let id = item.id else { continue }
            let migrated = -item.createdAt.timeIntervalSince1970
            collectionRef.document(id).updateData([
                "position": migrated
            ]) { error in
                if let error = error {
                    let ns = error as NSError
                    os_log("migrate position FAILED id=%{public}@ domain=%{public}@ code=%{public}d desc=%{public}@",
                           log: libraryLog, type: .error,
                           id, ns.domain, ns.code, ns.localizedDescription)
                }
            }
        }
    }

    // MARK: - Eliminazione

    /// Elimina il documento Firestore dell'item. Il listener real-time
    /// rimuoverà automaticamente la cella dalla riga corrispondente.
    func delete(itemId: String,
                completion: ((Result<Void, Error>) -> Void)? = nil) {
        collectionRef.document(itemId).delete { error in
            if let error = error {
                let ns = error as NSError
                os_log("delete: Firestore delete FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                       log: libraryLog, type: .error,
                       ns.domain, ns.code, ns.localizedDescription)
                completion?(.failure(LibraryError.underlying(error)))
            } else {
                completion?(.success(()))
            }
        }
    }

    // MARK: - Reorder (drag & drop)

    /// Aggiorna `position` (e opzionalmente `category`) di un item.
    /// Usato sia per il riordinamento dentro la stessa categoria sia per il
    /// drop cross-categoria con posizione esatta. Il listener real-time
    /// rimuoverà l'item dalla riga sorgente e lo inserirà nella destinazione
    /// nella posizione corretta in automatico.
    func reorder(itemId: String,
                 to newPosition: Double,
                 category: LibraryCategory? = nil,
                 completion: ((Result<Void, Error>) -> Void)? = nil) {
        var fields: [String: Any] = ["position": newPosition]
        if let category = category {
            fields["category"] = category.rawValue
        }
        collectionRef.document(itemId).updateData(fields) { error in
            if let error = error {
                let ns = error as NSError
                os_log("reorder: Firestore updateData FAILED domain=%{public}@ code=%{public}d desc=%{public}@",
                       log: libraryLog, type: .error,
                       ns.domain, ns.code, ns.localizedDescription)
                completion?(.failure(LibraryError.underlying(error)))
            } else {
                completion?(.success(()))
            }
        }
    }

    /// Calcola la `position` da assegnare a un item droppato all'indice
    /// `index` di una lista già ordinata `position asc`.
    ///
    /// - drop a indice 0          → `items[0].position - 1.0`
    /// - drop in fondo (index ≥ count) → `items.last.position + 1.0`
    /// - drop fra A (index-1) e B (index) → `(A.position + B.position) / 2`
    ///
    /// Se gli adiacenti non hanno ancora una `position` (item legacy non
    /// ancora migrato dal listener), usiamo un fallback basato sull'indice
    /// per garantire un valore sensato senza forced unwrap.
    func computePosition(at index: Int, in items: [LibraryItem]) -> Double {
        // Lista vuota: qualsiasi valore va bene; uso 0 per restare leggibile.
        guard !items.isEmpty else { return 0.0 }

        // Drop in cima: vado *prima* del primo elemento.
        if index <= 0 {
            let firstPos = items[0].position ?? Double(0)
            return firstPos - 1.0
        }

        // Drop in coda (oltre l'ultimo indice valido).
        if index >= items.count {
            let lastPos = items[items.count - 1].position ?? Double(items.count - 1)
            return lastPos + 1.0
        }

        // Drop in mezzo: media fra A (precedente) e B (successivo).
        let aPos = items[index - 1].position ?? Double(index - 1)
        let bPos = items[index].position ?? Double(index)
        return (aPos + bPos) / 2.0
    }
}
