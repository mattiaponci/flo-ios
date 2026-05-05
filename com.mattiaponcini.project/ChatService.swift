//
//  ChatService.swift
//  Flotip
//
//  Wrapper Firestore per la chat: liste/listener delle conversazioni,
//  liste/listener dei messaggi di una singola conversazione, invio testo
//  e share di un post Flotip nella chat. Include search degli utenti.
//

import Foundation
import os.log
import FirebaseAuth
import FirebaseFirestore

private let chatLog = OSLog(subsystem: "com.mattiaponcini.project", category: "ChatService")

final class ChatService {

    static let shared = ChatService()
    private init() {}

    private lazy var db = Firestore.firestore()

    private var conversationsRef: CollectionReference {
        db.collection("conversations")
    }

    private var currentUid: String { Auth.auth().currentUser?.uid ?? "" }

    // MARK: - Lista conversazioni

    func observeConversations(
        onChange: @escaping ([Conversation]) -> Void
    ) -> ListenerRegistration? {
        guard !currentUid.isEmpty else {
            onChange([])
            return nil
        }
        let uid = currentUid
        return conversationsRef
            .whereField("participants", arrayContains: uid)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    os_log("observeConversations: %{public}@",
                           log: chatLog, type: .error, error.localizedDescription)
                    // NB: NON chiamiamo onChange([]) sull'errore. Stesso
                    // motivo del listener libreria: un errore transiente
                    // (rete intermittente, refresh del token, indice
                    // composito non ancora pronto) farebbe sparire le
                    // chat già a schermo per poi rimetterle al prossimo
                    // snapshot — l'utente vede un flash "vuoto"
                    // sgradevole. Lasciamo l'ultima cache e ci affidiamo
                    // al prossimo snapshot di successo per aggiornarla.
                    return
                }
                let convs: [Conversation] = snapshot?.documents.compactMap {
                    try? $0.data(as: Conversation.self)
                } ?? []
                // Filtra client-side le chat che l'utente corrente ha
                // "eliminato" (hiddenFor contiene uid). Firestore non
                // supporta "array NON contiene", quindi è gestito qui.
                let visible = convs.filter { !$0.isHidden(for: uid) }
                onChange(visible)
            }
    }

    // MARK: - Trova o crea conversazione

    func findOrCreateConversation(
        with other: UserProfile,
        myProfile: UserProfile,
        completion: @escaping (Result<Conversation, Error>) -> Void
    ) {
        guard !currentUid.isEmpty,
              let otherUid = other.id, !otherUid.isEmpty else {
            completion(.failure(NSError(
                domain: "ChatService", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Utente non valido."]
            )))
            return
        }
        let cid = ChatID.make(currentUid, otherUid)
        let docRef = conversationsRef.document(cid)

        docRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                completion(.failure(error))
                return
            }
            if let snapshot = snapshot, snapshot.exists {
                do {
                    var conv = try snapshot.data(as: Conversation.self)
                    conv.id = snapshot.documentID
                    completion(.success(conv))
                } catch {
                    completion(.failure(error))
                }
                return
            }

            let myUid = self.currentUid
            let now = Date()
            let conv = Conversation(
                id: nil,
                participants: [myUid, otherUid].sorted(),
                participantNames: [
                    myUid: myProfile.fullName,
                    otherUid: other.fullName
                ],
                participantPhotoURLs: [
                    myUid: myProfile.photoURL ?? "",
                    otherUid: other.photoURL ?? ""
                ],
                lastMessage: "",
                lastSenderId: "",
                updatedAt: now,
                createdAt: now,
                hiddenFor: []
            )
            do {
                try docRef.setData(from: conv) { err in
                    if let err = err {
                        completion(.failure(err))
                    } else {
                        var withId = conv
                        withId.id = cid
                        completion(.success(withId))
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Messaggi della conversazione

    func observeMessages(
        conversationId: String,
        onChange: @escaping ([ChatMessage]) -> Void
    ) -> ListenerRegistration? {
        return conversationsRef
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: 200)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    os_log("observeMessages: %{public}@",
                           log: chatLog, type: .error, error.localizedDescription)
                    onChange([])
                    return
                }
                let msgs: [ChatMessage] = snapshot?.documents.compactMap {
                    try? $0.data(as: ChatMessage.self)
                } ?? []
                onChange(msgs)
            }
    }

    // MARK: - Invio messaggi

    func sendText(
        _ text: String,
        in conversation: Conversation,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let cid = conversation.id else {
            completion(.failure(NSError(
                domain: "ChatService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Conversazione senza id."]
            )))
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success(()))
            return
        }
        sendMessage(
            cid: cid,
            participants: conversation.participants,
            message: ChatMessage(
                id: nil,
                senderId: currentUid,
                text: trimmed,
                sharedPost: nil,
                createdAt: Date()
            ),
            previewForList: trimmed,
            completion: completion
        )
    }

    func share(
        post: Post,
        in conversation: Conversation,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let cid = conversation.id else {
            completion(.failure(NSError(
                domain: "ChatService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Conversazione senza id."]
            )))
            return
        }
        let payload = SharedPostPayload(
            postId: post.id ?? "",
            imageURL: post.imageURL,
            // Propaga la sourceURL del post originale: serve al doppio tap
            // sulla card in chat per riaprire la pagina nella tab Cattura
            // (stesso UX di feed/profilo). I post legacy non l'hanno e
            // resta nil — il client mostrerà un toast di "nessuna sorgente".
            sourceURL: post.sourceURL,
            caption: post.caption,
            authorId: post.authorId,
            authorName: post.authorName
        )
        sendMessage(
            cid: cid,
            participants: conversation.participants,
            message: ChatMessage(
                id: nil,
                senderId: currentUid,
                text: nil,
                sharedPost: payload,
                createdAt: Date()
            ),
            previewForList: "Tip condiviso",
            completion: completion
        )
    }

    private func sendMessage(
        cid: String,
        participants: [String],
        message: ChatMessage,
        previewForList: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let convRef = conversationsRef.document(cid)
        let msgRef = convRef.collection("messages").document()
        let batch = db.batch()
        do {
            try batch.setData(from: message, forDocument: msgRef)
        } catch {
            completion(.failure(error))
            return
        }

        // Quando arriva un nuovo messaggio, la chat deve "tornare visibile"
        // a tutti i destinatari che l'avevano nascosta. Rimuoviamo dunque
        // gli uid degli altri partecipanti dal set hiddenFor (arrayRemove
        // è idempotente: non fa nulla se l'uid non è presente).
        let othersToRestore = participants.filter { $0 != message.senderId }

        var convUpdate: [String: Any] = [
            "lastMessage": previewForList,
            "lastSenderId": message.senderId,
            "updatedAt": Date()
        ]
        if !othersToRestore.isEmpty {
            convUpdate["hiddenFor"] = FieldValue.arrayRemove(othersToRestore)
        }
        batch.updateData(convUpdate, forDocument: convRef)

        batch.commit { error in
            if let error = error {
                os_log("sendMessage: %{public}@",
                       log: chatLog, type: .error, error.localizedDescription)
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - "Elimina" conversazione (soft-delete per il solo utente)

    /// Nasconde la conversazione per l'utente corrente aggiungendo il suo
    /// uid al campo `hiddenFor`. NON cancella il documento Firestore (le
    /// rules vietano la delete reale per preservare la storia all'altro
    /// partecipante). La chat ricomparirà appena l'altro invierà un
    /// nuovo messaggio (vedi `sendMessage` → arrayRemove su hiddenFor).
    func deleteConversation(
        cid: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let uid = currentUid
        guard !uid.isEmpty else {
            completion(.failure(NSError(
                domain: "ChatService", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Utente non autenticato."]
            )))
            return
        }
        guard !cid.isEmpty else {
            completion(.failure(NSError(
                domain: "ChatService", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Conversazione senza id."]
            )))
            return
        }
        conversationsRef.document(cid).updateData([
            "hiddenFor": FieldValue.arrayUnion([uid])
        ]) { error in
            if let error = error {
                os_log("deleteConversation: %{public}@",
                       log: chatLog, type: .error, error.localizedDescription)
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Ricerca utenti

    /// Cerca utenti per prefisso. Lavora client-side su un fetch limitato di
    /// `users` (max 50) per semplicità; basta per utenza piccola.
    /// Restituisce al massimo `limit` risultati ordinati per nome.
    func searchUsers(
        query: String,
        limit: Int = 5,
        completion: @escaping (Result<[UserProfile], Error>) -> Void
    ) {
        let q = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !q.isEmpty else {
            completion(.success([]))
            return
        }

        db.collection("users")
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                let myUid = self?.currentUid ?? ""
                let all: [UserProfile] = snapshot?.documents.compactMap {
                    try? $0.data(as: UserProfile.self)
                } ?? []
                let matches = all
                    .filter { $0.id != myUid }
                    .filter { profile in
                        let full  = profile.fullName.lowercased()
                        let first = profile.firstName.lowercased()
                        let last  = profile.lastName.lowercased()
                        let mail  = profile.email.lowercased()
                        return full.contains(q)
                            || first.hasPrefix(q)
                            || last.hasPrefix(q)
                            || mail.hasPrefix(q)
                    }
                    .sorted { $0.fullName.lowercased() < $1.fullName.lowercased() }
                    .prefix(limit)
                completion(.success(Array(matches)))
            }
    }
}
