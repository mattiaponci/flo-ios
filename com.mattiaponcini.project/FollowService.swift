//
//  FollowService.swift
//  Flotip
//
//  Servizio Firestore per il sistema follow / follow-request fra utenti.
//
//  Schema:
//    users/{myUid}/following/{otherUid}      ← "io seguo other" (follow accettato)
//      followedAt: Timestamp, followeeId: String
//
//    users/{recipientUid}/followRequests/{requesterUid}
//                                             ← richiesta pending da requester
//                                             a recipient. Quando il recipient
//                                             accetta, il doc viene cancellato
//                                             e contestualmente si crea
//                                             users/{requesterUid}/following/{recipientUid}.
//      requesterUid: String, requestedAt: Timestamp, status: "pending"
//
//  Flow tipico:
//    A vuole seguire B:
//      1. A → requestFollow(B)
//         → crea users/{B}/followRequests/{A}
//         → Cloud Function notifyFollowRequest invia push a B
//      2. B → acceptFollowRequest(from: A)
//         → batch: crea users/{A}/following/{B} + delete users/{B}/followRequests/{A}
//      ...oppure:
//      2'. B → rejectFollowRequest(from: A)
//         → delete users/{B}/followRequests/{A}
//      ...oppure:
//      2''. A → cancelFollowRequest(B)
//         → delete users/{B}/followRequests/{A}
//
//  Backward-compat: gli utenti già presenti in `following` (follow vecchi
//  senza request flow) restano validi. `fetchFollowingUids` /
//  `fetchFollowersUids` continuano a leggere lo stesso schema.
//

import Foundation
import os.log
import FirebaseAuth
import FirebaseFirestore

private let followLog = OSLog(subsystem: "com.mattiaponcini.project", category: "FollowService")

final class FollowService {

    static let shared = FollowService()
    private init() {}

    private lazy var db = Firestore.firestore()

    private var currentUid: String { Auth.auth().currentUser?.uid ?? "" }

    private func followingRef(for uid: String) -> CollectionReference {
        db.collection("users").document(uid).collection("following")
    }

    private func followRequestsRef(for recipientUid: String) -> CollectionReference {
        db.collection("users").document(recipientUid).collection("followRequests")
    }

    // MARK: - Follow / Unfollow

    /// Tappare "Segui" su un profilo invia una **richiesta** invece di
    /// scrivere direttamente in `following`. Mantenuto come `follow(_:)` per
    /// backward-compat con i call site esistenti (PublicProfileViewController):
    /// internamente delega a `requestFollow(_:)`.
    ///
    /// Per scrittura diretta in `following` (caso "accept" da parte del
    /// recipient) usare `acceptFollowRequest(from:)`.
    func follow(_ otherUid: String,
                completion: @escaping (Result<Void, Error>) -> Void) {
        requestFollow(otherUid, completion: completion)
    }

    /// Scrittura "raw" del documento `users/{currentUid}/following/{otherUid}`.
    /// Usata internamente dal flow di accept (dove il recipient = currentUid
    /// crea il doc following nella collezione del requester) e da eventuali
    /// migrazioni. **Non chiamare dalla UI**: il bottone "Segui" deve passare
    /// per `requestFollow(_:)`.
    fileprivate func writeFollowingDoc(ownerUid: String,
                                       followeeUid: String,
                                       in batch: WriteBatch) {
        let docRef = followingRef(for: ownerUid).document(followeeUid)
        // NB: salviamo `followeeId` come campo esplicito (oltre che come document ID).
        // Serve per le collection-group query "chi segue X": Firestore non
        // permette `whereField(FieldPath.documentID(), isEqualTo: uid)` su una
        // collection group perché richiederebbe un path con numero PARI di
        // segmenti (e l'uid da solo è 1 segmento, dispari → crash a runtime
        // con FIRInvalidArgumentException). Filtrare per campo evita il problema.
        batch.setData([
            "followedAt": FieldValue.serverTimestamp(),
            "followeeId": followeeUid
        ], forDocument: docRef)
    }

    /// Smetti di seguire `otherUid`. Idempotente.
    func unfollow(_ otherUid: String,
                  completion: @escaping (Result<Void, Error>) -> Void) {
        guard !currentUid.isEmpty, !otherUid.isEmpty else {
            completion(.failure(NSError(
                domain: "FollowService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Utente non valido."]
            )))
            return
        }
        let docRef = followingRef(for: currentUid).document(otherUid)
        docRef.delete { err in
            if let err = err {
                os_log("unfollow: %{public}@",
                       log: followLog, type: .error, err.localizedDescription)
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Lettura stato

    /// True se l'utente loggato segue `otherUid`.
    func isFollowing(_ otherUid: String,
                     completion: @escaping (Bool) -> Void) {
        guard !currentUid.isEmpty, !otherUid.isEmpty else {
            completion(false)
            return
        }
        followingRef(for: currentUid).document(otherUid)
            .getDocument { snapshot, _ in
                completion(snapshot?.exists ?? false)
            }
    }

    /// Listener real-time sullo stato "io seguo otherUid".
    func observeIsFollowing(
        _ otherUid: String,
        onChange: @escaping (Bool) -> Void
    ) -> ListenerRegistration? {
        guard !currentUid.isEmpty, !otherUid.isEmpty else {
            onChange(false)
            return nil
        }
        return followingRef(for: currentUid).document(otherUid)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.exists ?? false)
            }
    }

    // MARK: - Lista following

    /// Restituisce la lista di UID che l'utente loggato segue.
    /// Lettura one-shot, ordinata per data di follow (più recenti in cima).
    func fetchMyFollowingUids(
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard !currentUid.isEmpty else {
            completion(.success([]))
            return
        }
        followingRef(for: currentUid)
            .order(by: "followedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    os_log("fetchMyFollowingUids: %{public}@",
                           log: followLog, type: .error, error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                let uids = snapshot?.documents.map { $0.documentID } ?? []
                completion(.success(uids))
            }
    }

    /// Variante che ritorna direttamente i `UserProfile` di chi seguo.
    /// Fa due round-trip: prima la collection following, poi `users/{uid}`
    /// per ciascuno. Caso d'uso: picker "invia a chi segui" nel feed.
    func fetchMyFollowingProfiles(
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        fetchFollowingProfiles(for: currentUid, completion: completion)
    }

    // MARK: - Following / Followers di un UID arbitrario

    /// Lista UID seguiti da `uid` (one-shot, ordine `followedAt desc`).
    func fetchFollowingUids(
        for uid: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard !uid.isEmpty else {
            completion(.success([]))
            return
        }
        followingRef(for: uid)
            .order(by: "followedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    os_log("fetchFollowingUids: %{public}@",
                           log: followLog, type: .error, error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                let uids = snapshot?.documents.map { $0.documentID } ?? []
                completion(.success(uids))
            }
    }

    /// Profili (UserProfile) seguiti da `uid`, nell'ordine `followedAt desc`.
    func fetchFollowingProfiles(
        for uid: String,
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        fetchFollowingUids(for: uid) { [weak self] result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let uids):
                guard let self = self else { completion(.success([])); return }
                self.fetchProfiles(for: uids, completion: completion)
            }
        }
    }

    /// Lista UID che seguono `uid` (one-shot). Usa una collection-group
    /// query su tutte le subcollection `following` filtrando per il campo
    /// `followeeId == uid` (NB: NON `FieldPath.documentID()`: in
    /// collection-group quel filtro richiede un path con numero pari di
    /// segmenti e crasha a runtime con un solo uid).
    /// L'autore del follow è il parent doc id (ricavato via parent reference).
    func fetchFollowersUids(
        for uid: String,
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard !uid.isEmpty else {
            completion(.success([]))
            return
        }
        db.collectionGroup("following")
            .whereField("followeeId", isEqualTo: uid)
            .getDocuments { snapshot, error in
                if let error = error {
                    os_log("fetchFollowersUids: %{public}@",
                           log: followLog, type: .error, error.localizedDescription)
                    completion(.failure(error))
                    return
                }
                // Il parent del path users/{follower}/following/{uid} è la
                // collection "following"; il doc.parent.parent è users/{follower}.
                let uids: [String] = snapshot?.documents.compactMap {
                    $0.reference.parent.parent?.documentID
                } ?? []
                completion(.success(uids))
            }
    }

    /// Profili che seguono `uid`. Una sola lettura di collection group
    /// + lookup parallelo dei `users/{uid}`.
    func fetchFollowersProfiles(
        for uid: String,
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        fetchFollowersUids(for: uid) { [weak self] result in
            switch result {
            case .failure(let err):
                completion(.failure(err))
            case .success(let uids):
                guard let self = self else { completion(.success([])); return }
                self.fetchProfiles(for: uids, completion: completion)
            }
        }
    }

    /// Helper: dato un set di UID, recupera in parallelo i `UserProfile`
    /// preservando l'ordine originale. Usato sia da
    /// `fetchFollowingProfiles` che da `fetchFollowersProfiles`.
    private func fetchProfiles(
        for uids: [String],
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        guard !uids.isEmpty else { completion(.success([])); return }
        let group = DispatchGroup()
        var profilesByUid: [String: UserProfile] = [:]
        let lock = NSLock()
        for uid in uids {
            group.enter()
            self.db.collection("users").document(uid).getDocument { snapshot, _ in
                defer { group.leave() }
                if let snapshot = snapshot,
                   let profile = try? snapshot.data(as: UserProfile.self) {
                    lock.lock()
                    profilesByUid[uid] = profile
                    lock.unlock()
                }
            }
        }
        group.notify(queue: .main) {
            let ordered = uids.compactMap { profilesByUid[$0] }
            completion(.success(ordered))
        }
    }

    // MARK: - Counts (real-time)

    /// Listener real-time sul numero di utenti seguiti da `uid`.
    /// Implementato leggendo i documenti della subcollection
    /// `users/{uid}/following`. Per follow-list piccole è il pattern
    /// più semplice; per scale grandi servirà una count aggregata.
    func observeFollowingCount(
        for uid: String,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration? {
        guard !uid.isEmpty else {
            onChange(0)
            return nil
        }
        return followingRef(for: uid).addSnapshotListener { snapshot, error in
            if let error = error {
                os_log("observeFollowingCount: %{public}@",
                       log: followLog, type: .error, error.localizedDescription)
                onChange(0)
                return
            }
            onChange(snapshot?.documents.count ?? 0)
        }
    }

    /// Listener real-time sul numero di utenti che seguono `uid`.
    /// Usa una collection-group query sulle subcollection `following`.
    /// Richiede:
    /// 1. Un'esenzione collection-group nelle Firestore Indexes (single-field
    ///    auto-creata al primo run; in caso di errore, Firestore stamperà
    ///    in console un link per crearla).
    /// 2. Regole di sicurezza che permettano la lettura collection-group:
    ///    `match /{path=**}/following/{followee} { allow read: if true; }`
    ///    (o limitato all'utente loggato a piacere).
    func observeFollowersCount(
        for uid: String,
        onChange: @escaping (Int) -> Void
    ) -> ListenerRegistration? {
        guard !uid.isEmpty else {
            onChange(0)
            return nil
        }
        return db.collectionGroup("following")
            .whereField("followeeId", isEqualTo: uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    os_log("observeFollowersCount: %{public}@",
                           log: followLog, type: .error, error.localizedDescription)
                    onChange(0)
                    return
                }
                onChange(snapshot?.documents.count ?? 0)
            }
    }

    // MARK: - Follow requests (pending approval flow)

    /// Crea (o riattiva) una richiesta di follow verso `otherUid`.
    /// Idempotente: se la richiesta esiste già o se sto già seguendo
    /// `otherUid`, ritorna success senza scrivere nulla.
    /// La Cloud Function `notifyFollowRequest` invia la push al recipient
    /// quando questo doc viene creato.
    func requestFollow(_ otherUid: String,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        guard !currentUid.isEmpty, !otherUid.isEmpty,
              otherUid != currentUid else {
            completion(.failure(NSError(
                domain: "FollowService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Utente non valido."]
            )))
            return
        }
        let me = currentUid
        // Short-circuit: se sto già seguendo, no-op.
        followingRef(for: me).document(otherUid).getDocument { [weak self] snap, _ in
            if snap?.exists == true {
                completion(.success(()))
                return
            }
            guard let self = self else { return }
            let reqRef = self.followRequestsRef(for: otherUid).document(me)
            // Idempotenza: setData (non addDocument) overwriting safe — se la
            // richiesta esiste, il merge mantiene `requestedAt` aggiornato e
            // status="pending". Il trigger Cloud Function reagisce solo a
            // onCreate, quindi un overwrite di una request già pending non
            // genera notifiche duplicate.
            reqRef.setData([
                "requesterUid": me,
                "requestedAt": FieldValue.serverTimestamp(),
                "status": "pending"
            ]) { err in
                if let err = err {
                    os_log("requestFollow: %{public}@",
                           log: followLog, type: .error, err.localizedDescription)
                    completion(.failure(err))
                } else {
                    completion(.success(()))
                }
            }
        }
    }

    /// Cancella una richiesta di follow che ho inviato a `otherUid`.
    /// Usato dal bottone "Richiesta inviata" (cancellazione lato requester).
    /// Idempotente: se la richiesta non esiste, ritorna success.
    func cancelFollowRequest(_ otherUid: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        guard !currentUid.isEmpty, !otherUid.isEmpty else {
            completion(.failure(NSError(
                domain: "FollowService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Utente non valido."]
            )))
            return
        }
        followRequestsRef(for: otherUid).document(currentUid).delete { err in
            if let err = err {
                os_log("cancelFollowRequest: %{public}@",
                       log: followLog, type: .error, err.localizedDescription)
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Accetta una richiesta di follow ricevuta da `requesterUid`.
    /// Esegue in batch:
    ///   - create users/{requesterUid}/following/{currentUid}  (= requester
    ///     ora segue me, currentUid)
    ///   - delete users/{currentUid}/followRequests/{requesterUid}
    /// Le rules permettono al recipient di scrivere il doc following del
    /// requester *solo* se esiste la corrispondente followRequest pending.
    func acceptFollowRequest(from requesterUid: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        guard !currentUid.isEmpty, !requesterUid.isEmpty,
              requesterUid != currentUid else {
            completion(.failure(NSError(
                domain: "FollowService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Richiesta non valida."]
            )))
            return
        }
        let me = currentUid
        let batch = db.batch()
        // 1) Create following doc nella collezione del requester.
        writeFollowingDoc(ownerUid: requesterUid, followeeUid: me, in: batch)
        // 2) Delete followRequest dalla mia collezione.
        let reqRef = followRequestsRef(for: me).document(requesterUid)
        batch.deleteDocument(reqRef)

        batch.commit { err in
            if let err = err {
                os_log("acceptFollowRequest: %{public}@",
                       log: followLog, type: .error, err.localizedDescription)
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Rifiuta una richiesta di follow ricevuta da `requesterUid`. Cancella
    /// solo il doc `followRequests` (no scrittura in `following`).
    func rejectFollowRequest(from requesterUid: String,
                             completion: @escaping (Result<Void, Error>) -> Void) {
        guard !currentUid.isEmpty, !requesterUid.isEmpty else {
            completion(.failure(NSError(
                domain: "FollowService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Richiesta non valida."]
            )))
            return
        }
        followRequestsRef(for: currentUid).document(requesterUid).delete { err in
            if let err = err {
                os_log("rejectFollowRequest: %{public}@",
                       log: followLog, type: .error, err.localizedDescription)
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }

    /// Listener real-time: true se HO una richiesta di follow pending verso
    /// `otherUid` (ovvero esiste users/{otherUid}/followRequests/{currentUid}).
    /// Usato dal bottone "Segui" sul profilo pubblico per distinguere
    /// "Segui" / "Richiesta inviata" / "Seguito".
    func observeFollowRequest(
        to otherUid: String,
        onChange: @escaping (Bool) -> Void
    ) -> ListenerRegistration? {
        guard !currentUid.isEmpty, !otherUid.isEmpty else {
            onChange(false)
            return nil
        }
        return followRequestsRef(for: otherUid)
            .document(currentUid)
            .addSnapshotListener { snapshot, _ in
                onChange(snapshot?.exists ?? false)
            }
    }

    /// Singola richiesta di follow ricevuta. `requesterUid` è il document ID.
    struct PendingFollowRequest {
        let requesterUid: String
        let requestedAt: Date?
    }

    /// Listener real-time sulle richieste di follow ricevute dall'utente
    /// loggato, ordinate per `requestedAt` discendente (più recenti in cima).
    /// Callback con la lista completa a ogni snapshot (replace, non diff).
    func observePendingRequests(
        onChange: @escaping ([PendingFollowRequest]) -> Void
    ) -> ListenerRegistration? {
        guard !currentUid.isEmpty else {
            onChange([])
            return nil
        }
        return followRequestsRef(for: currentUid)
            .order(by: "requestedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    os_log("observePendingRequests: %{public}@",
                           log: followLog, type: .error, error.localizedDescription)
                    onChange([])
                    return
                }
                let items: [PendingFollowRequest] = (snapshot?.documents ?? []).map { doc in
                    let data = doc.data()
                    let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue()
                    return PendingFollowRequest(
                        requesterUid: doc.documentID,
                        requestedAt: requestedAt
                    )
                }
                onChange(items)
            }
    }

    /// Variante "profili": stesso listener di `observePendingRequests` ma
    /// risolve in parallelo i `UserProfile` dei requester per renderli
    /// pronti all'uso nella UI (avatar + nome). Mantiene l'ordine.
    func observePendingRequestProfiles(
        onChange: @escaping ([UserProfile]) -> Void
    ) -> ListenerRegistration? {
        return observePendingRequests { [weak self] requests in
            guard let self = self else { onChange([]); return }
            let uids = requests.map { $0.requesterUid }
            self.fetchProfiles(for: uids) { result in
                switch result {
                case .success(let profiles):
                    DispatchQueue.main.async { onChange(profiles) }
                case .failure:
                    DispatchQueue.main.async { onChange([]) }
                }
            }
        }
    }
}
