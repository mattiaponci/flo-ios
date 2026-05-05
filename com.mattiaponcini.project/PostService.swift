//
//  PostService.swift
//  Flotip
//
//  Tutto il traffico Firebase per il feed: upload immagini su Storage,
//  scrittura documento Post su Firestore, listener real-time del feed.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

enum PostError: LocalizedError {
    case notLoggedIn
    case imageEncoding
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:    return "Devi essere loggato per pubblicare."
        case .imageEncoding:  return "Impossibile elaborare l'immagine selezionata."
        case .underlying(let e): return e.localizedDescription
        }
    }
}

final class PostService {

    static let shared = PostService()
    private init() {}

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Stato listener feed (filtrato per "following")

    /// Listener real-time sulla subcollection `users/{uid}/following`:
    /// quando segui o smetti di seguire qualcuno ricostruiamo le query
    /// post così il feed si aggiorna senza tornare nello splash.
    private var followingListener: ListenerRegistration?

    /// Una snapshot listener PER OGNI chunk di max 30 followed uid:
    /// Firestore `whereField("authorId", in: [...])` accetta al massimo
    /// 30 elementi nell'array, quindi se segui >30 utenti spezziamo in
    /// batch e teniamo un listener per batch. Il merge è client-side.
    private var postsListeners: [ListenerRegistration] = []

    /// Risultati per batch, indicizzati per posizione del chunk.
    /// Ogni snapshot di un batch sovrascrive la sua entry, poi
    /// emettiamo il merge ordinato di tutti i batch.
    private var postsByBatch: [Int: [Post]] = [:]

    /// Lista corrente di uid seguiti (per evitare rebuild inutili
    /// quando arrivano snapshot di solo metadata sulla following).
    private var currentFollowingUids: [String] = []

    /// uid dell'utente per cui stiamo osservando il feed: serve a
    /// scartare callback in volo dopo uno stop/restart.
    private var currentFeedUid: String?

    private var postsCollection: CollectionReference {
        db.collection("posts")
    }

    // MARK: - Pubblicazione

    /// Carica l'immagine su Storage e crea il documento Post su Firestore.
    /// L'autore è dedotto dall'utente loggato.
    func publish(image: UIImage,
                 caption: String,
                 sourceURL: String?,
                 author: UserProfile?,
                 completion: @escaping (Result<Post, Error>) -> Void) {

        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(PostError.notLoggedIn))
            return
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            completion(.failure(PostError.imageEncoding))
            return
        }

        // Step 1: upload immagine su Storage in posts/{uid}/{postId}.jpg
        let postId = postsCollection.document().documentID
        let ref = storage.reference().child("posts/\(uid)/\(postId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(data, metadata: metadata) { [weak self] _, error in
            if let error = error {
                completion(.failure(PostError.underlying(error)))
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(PostError.underlying(error)))
                    return
                }
                guard let urlString = url?.absoluteString else {
                    completion(.failure(PostError.underlying(NSError(
                        domain: "PostService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "URL immagine mancante."]
                    ))))
                    return
                }
                self?.writePostDocument(
                    id: postId,
                    imageURL: urlString,
                    sourceURL: sourceURL,
                    caption: caption,
                    authorId: uid,
                    author: author,
                    completion: completion
                )
            }
        }
    }

    private func writePostDocument(id: String,
                                   imageURL: String,
                                   sourceURL: String?,
                                   caption: String,
                                   authorId: String,
                                   author: UserProfile?,
                                   completion: @escaping (Result<Post, Error>) -> Void) {
        // @DocumentID è gestito da Firestore via path. Lasciamo id=nil
        // qui per evitare il warning "FST000002 — managed by Firestore".
        var post = Post(
            id: nil,
            imageURL: imageURL,
            sourceURL: sourceURL,
            caption: caption,
            authorId: authorId,
            authorName: author?.fullName ?? "Anonimo",
            authorPhotoURL: author?.photoURL,
            createdAt: Date()
        )
        do {
            try postsCollection.document(id).setData(from: post) { error in
                if let error = error {
                    NSLog("[PostService] Firestore write failed: \(error.localizedDescription)")
                    completion(.failure(PostError.underlying(error)))
                } else {
                    // Setta l'id solo dopo la write per restituire un Post completo al chiamante.
                    post.id = id
                    completion(.success(post))
                }
            }
        } catch {
            completion(.failure(PostError.underlying(error)))
        }
    }

    // MARK: - Feed real-time (filtrato "only following")

    /// Avvia il listener Firestore del feed: mostra SOLO i post degli
    /// utenti che `currentUid` segue (subcollection `users/{currentUid}/following`).
    /// Esclude i post di `currentUid` stesso (sicurezza: non vuoi vederti
    /// nel feed anche se per qualche motivo segui te stesso).
    ///
    /// Architettura:
    /// 1. Snapshot listener sulla lista `following` → quando segui o
    ///    smetti di seguire qualcuno, ricostruiamo le query post.
    /// 2. Per ogni cambio della lista, generiamo N query
    ///    `posts.whereField("authorId", in: chunk)` (max 30 elementi
    ///    per chunk: limite Firestore di `in`), ognuna con il proprio
    ///    snapshot listener (`order createdAt desc`, `limit 50`).
    /// 3. Merge client-side dei batch + dedup per id + ordinamento per
    ///    `createdAt desc` + cap finale a 50 post → AppStore.
    ///
    /// Indice composito richiesto: `posts(authorId Asc, createdAt Desc)`.
    /// Probabilmente già creato per il profilo; al primo run senza indice
    /// Firestore stampa in console un link cliccabile per crearlo.
    func startObservingFeed(for currentUid: String) {
        // Evita listener duplicati / da sessioni precedenti.
        stopObservingFeed()

        guard !currentUid.isEmpty else {
            NSLog("[PostService] startObservingFeed: uid vuoto, skip")
            return
        }
        currentFeedUid = currentUid

        NSLog("[PostService] Avvio listener feed (only following) per uid=\(currentUid)")

        // Listener real-time sulla lista following.
        followingListener = db.collection("users")
            .document(currentUid)
            .collection("following")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    NSLog("[PostService] following listener error: \(error.localizedDescription)")
                    return
                }
                // Sicurezza: filtra fuori se stessi (non si dovrebbe seguire
                // se stessi, ma se per qualche bug è stato fatto, evitiamo
                // di iniettarsi nel feed).
                let uids: [String] = (snapshot?.documents.map { $0.documentID } ?? [])
                    .filter { $0 != currentUid }

                // Se la lista è identica all'ultima, evitiamo il rebuild
                // (i listener post sono già attivi e correnti).
                if Set(uids) == Set(self.currentFollowingUids) {
                    return
                }
                self.currentFollowingUids = uids
                NSLog("[PostService] following list updated: \(uids.count) uid")
                self.rebuildPostListeners(for: uids, currentUid: currentUid)
            }
    }

    /// Spezza la lista di followed uid in chunks da max 30 e crea uno
    /// snapshot listener su `posts.whereField("authorId", in: chunk)`
    /// per ogni chunk.
    private func rebuildPostListeners(for followedUids: [String],
                                      currentUid: String) {
        // Stop dei listener post correnti prima di ricostruire.
        postsListeners.forEach { $0.remove() }
        postsListeners.removeAll()
        postsByBatch.removeAll()

        guard !followedUids.isEmpty else {
            // Non segui nessuno → feed vuoto (FeedViewController mostra
            // l'empty state che invita a esplorare e seguire qualcuno).
            NSLog("[PostService] Nessun followed: feed vuoto")
            AppStore.shared.setPosts([])
            return
        }

        let chunks = Self.chunked(followedUids, size: 30)
        NSLog("[PostService] Rebuild post listeners: \(followedUids.count) uid in \(chunks.count) chunk(s)")

        for (batchIndex, chunk) in chunks.enumerated() {
            let listener = postsCollection
                .whereField("authorId", in: chunk)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { [weak self] snapshot, error in
                    guard let self = self else { return }
                    // Difensiva: se nel frattempo abbiamo cambiato uid
                    // (logout/login) o ricostruito i listener, ignoriamo.
                    guard self.currentFeedUid == currentUid else { return }
                    if let error = error {
                        NSLog("[PostService] feed batch \(batchIndex) error: \(error.localizedDescription)")
                        return
                    }
                    let posts: [Post] = snapshot?.documents.compactMap {
                        try? $0.data(as: Post.self)
                    } ?? []
                    self.postsByBatch[batchIndex] = posts
                    self.emitMergedFeed(currentUid: currentUid)
                }
            postsListeners.append(listener)
        }
    }

    /// Merge dei batch correnti: dedup per id, esclude self (difesa
    /// in profondità), ordina per createdAt desc, cap a 50.
    private func emitMergedFeed(currentUid: String) {
        let all = postsByBatch.values.flatMap { $0 }
        var byId: [String: Post] = [:]
        for p in all {
            guard let id = p.id else { continue }
            if p.authorId == currentUid { continue }
            byId[id] = p
        }
        let merged = byId.values
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(50)
        let result = Array(merged)
        NSLog("[PostService] feed merged: \(result.count) post (after dedup/sort/limit)")
        AppStore.shared.setPosts(result)
    }

    /// Helper: spezza un array in sotto-array di dimensione massima `size`.
    /// Usato per i chunk da 30 elementi della query `whereField in`.
    private static func chunked<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [array] }
        return stride(from: 0, to: array.count, by: size).map {
            Array(array[$0..<min($0 + size, array.count)])
        }
    }

    func stopObservingFeed() {
        followingListener?.remove()
        followingListener = nil
        postsListeners.forEach { $0.remove() }
        postsListeners.removeAll()
        postsByBatch.removeAll()
        currentFollowingUids = []
        currentFeedUid = nil
    }

    /// Lettura one-shot del feed (pull-to-refresh): usa la stessa
    /// strategia "only following" — prima legge la lista following,
    /// poi una `getDocuments` per chunk, merge identico al listener.
    func refreshFeed(completion: @escaping (Result<Int, Error>) -> Void) {
        guard let myUid = Auth.auth().currentUser?.uid else {
            completion(.failure(PostError.notLoggedIn))
            return
        }
        // Step 1: lista following (one-shot).
        db.collection("users").document(myUid)
            .collection("following")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    NSLog("[PostService] refreshFeed following query error: \(error.localizedDescription)")
                    completion(.failure(PostError.underlying(error)))
                    return
                }
                guard let self = self else {
                    completion(.success(0))
                    return
                }
                let uids: [String] = (snapshot?.documents.map { $0.documentID } ?? [])
                    .filter { $0 != myUid }

                guard !uids.isEmpty else {
                    NSLog("[PostService] refreshFeed: utente non segue nessuno → feed vuoto")
                    AppStore.shared.setPosts([])
                    completion(.success(0))
                    return
                }

                // Step 2: una query per chunk da 30 uid.
                let chunks = Self.chunked(uids, size: 30)
                let group = DispatchGroup()
                var collected: [Post] = []
                let lock = NSLock()
                var firstError: Error?

                for chunk in chunks {
                    group.enter()
                    self.postsCollection
                        .whereField("authorId", in: chunk)
                        .order(by: "createdAt", descending: true)
                        .limit(to: 50)
                        .getDocuments { snap, err in
                            defer { group.leave() }
                            if let err = err {
                                lock.lock()
                                if firstError == nil { firstError = err }
                                lock.unlock()
                                return
                            }
                            let posts: [Post] = snap?.documents.compactMap {
                                try? $0.data(as: Post.self)
                            } ?? []
                            lock.lock()
                            collected.append(contentsOf: posts)
                            lock.unlock()
                        }
                }

                group.notify(queue: .main) {
                    if let err = firstError, collected.isEmpty {
                        completion(.failure(PostError.underlying(err)))
                        return
                    }
                    // Dedup per id, esclude self, sort desc, limit 50.
                    var byId: [String: Post] = [:]
                    for p in collected {
                        guard let id = p.id else { continue }
                        if p.authorId == myUid { continue }
                        byId[id] = p
                    }
                    let merged = byId.values
                        .sorted { $0.createdAt > $1.createdAt }
                        .prefix(50)
                    let result = Array(merged)
                    NSLog("[PostService] refreshFeed: \(result.count) post")
                    AppStore.shared.setPosts(result)
                    completion(.success(result.count))
                }
            }
    }

    // MARK: - Likes

    /// Subcollection `posts/{postId}/likes`. Doc ID = uid del liker, payload
    /// minimale `{ likedAt: Timestamp }`. Idempotenza nativa: ri-tappare like
    /// sovrascrive lo stesso doc.
    private func likesCollection(postId: String) -> CollectionReference {
        postsCollection.document(postId).collection("likes")
    }

    /// Toggla il like del post per l'utente loggato.
    /// - Returns: nuovo stato `isLiked` dopo l'operazione.
    /// - Throws: `PostError.notLoggedIn` o errore Firestore.
    @discardableResult
    func toggleLike(postId: String) async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw PostError.notLoggedIn
        }
        let docRef = likesCollection(postId: postId).document(uid)
        do {
            let snap = try await docRef.getDocument()
            if snap.exists {
                try await docRef.delete()
                return false
            } else {
                try await docRef.setData([
                    "likedAt": FieldValue.serverTimestamp()
                ])
                return true
            }
        } catch {
            throw PostError.underlying(error)
        }
    }

    /// Listener real-time sul numero di like.
    /// Implementato leggendo i documenti della subcollection: per <100 like
    /// è il pattern più semplice ed è già real-time. (Le aggregate queries
    /// di Firestore non supportano `addSnapshotListener`.)
    func observeLikeCount(
        postId: String,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration {
        return likesCollection(postId: postId)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    NSLog("[PostService] observeLikeCount error: \(error.localizedDescription)")
                    onChange(0)
                    return
                }
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    /// Listener real-time sullo stato "io ho messo like a questo post".
    func observeIsLiked(
        postId: String,
        onChange: @escaping (Bool) -> Void
    ) -> ListenerRegistration? {
        guard let uid = Auth.auth().currentUser?.uid else {
            onChange(false)
            return nil
        }
        return likesCollection(postId: postId).document(uid)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.exists ?? false)
            }
    }

    /// Conteggio aggregato dei like ricevuti su tutti i post di `authorId`.
    /// Lettura one-shot: prima la query `posts where authorId == X`, poi
    /// per ogni post un read della subcollection `likes` (count documenti).
    /// Non è una snapshot listener — chiamala manualmente al refresh.
    /// Per autori con molti post potrebbe diventare costosa: in tal caso
    /// si denormalizza un campo `likesCount` sul Post e si usa quello.
    func fetchTotalLikesCount(for authorId: String,
                              completion: @escaping (Result<Int, Error>) -> Void) {
        guard !authorId.isEmpty else {
            completion(.success(0))
            return
        }
        postsCollection
            .whereField("authorId", isEqualTo: authorId)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    NSLog("[PostService] fetchTotalLikesCount posts query error: \(error.localizedDescription)")
                    completion(.failure(PostError.underlying(error)))
                    return
                }
                guard let self = self else { completion(.success(0)); return }
                let postIds = snapshot?.documents.map { $0.documentID } ?? []
                guard !postIds.isEmpty else {
                    completion(.success(0))
                    return
                }
                let group = DispatchGroup()
                var total = 0
                let lock = NSLock()
                var firstError: Error?
                for pid in postIds {
                    group.enter()
                    self.likesCollection(postId: pid).getDocuments { snap, err in
                        defer { group.leave() }
                        if let err = err {
                            lock.lock()
                            if firstError == nil { firstError = err }
                            lock.unlock()
                            return
                        }
                        let n = snap?.documents.count ?? 0
                        lock.lock()
                        total += n
                        lock.unlock()
                    }
                }
                group.notify(queue: .main) {
                    if let err = firstError, total == 0 {
                        completion(.failure(PostError.underlying(err)))
                    } else {
                        completion(.success(total))
                    }
                }
            }
    }

    /// Recupera la lista dei profili che hanno messo like al post.
    /// Lettura one-shot: prima la subcollection (uids ordinati per likedAt
    /// desc), poi `users/{uid}` per ciascun like in parallelo.
    /// Per <100 likers è ok; sopra ci si aggiunge paginazione.
    func fetchLikers(postId: String) async throws -> [UserProfile] {
        let snap: QuerySnapshot
        do {
            snap = try await likesCollection(postId: postId)
                .order(by: "likedAt", descending: true)
                .getDocuments()
        } catch {
            throw PostError.underlying(error)
        }
        let uids = snap.documents.map { $0.documentID }
        guard !uids.isEmpty else { return [] }

        // Fetch parallelo dei profili tramite un classic DispatchGroup
        // (lo stesso pattern già usato in FollowService.fetchMyFollowingProfiles),
        // così evitiamo problemi di Sendable-capture sui task figli.
        let usersRef = db.collection("users")
        return await withCheckedContinuation { (continuation: CheckedContinuation<[UserProfile], Never>) in
            let group = DispatchGroup()
            var byUid: [String: UserProfile] = [:]
            let lock = NSLock()
            for uid in uids {
                group.enter()
                usersRef.document(uid).getDocument { snapshot, _ in
                    defer { group.leave() }
                    if let snapshot = snapshot,
                       let profile = try? snapshot.data(as: UserProfile.self) {
                        lock.lock()
                        byUid[uid] = profile
                        lock.unlock()
                    }
                }
            }
            group.notify(queue: .main) {
                let ordered = uids.compactMap { byUid[$0] }
                continuation.resume(returning: ordered)
            }
        }
    }
}
