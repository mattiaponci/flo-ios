//
//  Chat.swift
//  Flotip
//
//  Modelli Firestore per la chat 1-a-1 fra utenti dell'app.
//
//  Schema:
//    conversations/{cid}                     ← Conversation
//      participants:        [uid, uid]
//      participantNames:    [uid: String]    (denormalizzato per evitare
//                                             una query users/{uid} in lista)
//      participantPhotoURLs:[uid: String]    (idem)
//      lastMessage:         String
//      lastSenderId:        String
//      updatedAt:           Date
//      createdAt:           Date
//      hiddenFor:           [String]?    (uid che hanno "eliminato" la
//                                         chat dalla loro lista; ricompare
//                                         se l'altro manda un messaggio)
//
//    conversations/{cid}/messages/{mid}      ← ChatMessage
//      senderId:            String
//      text:                String?
//      sharedPost:          SharedPostPayload?
//      createdAt:           Date
//

import Foundation
import FirebaseFirestore

// MARK: - Conversation

struct Conversation: Codable, Identifiable {
    @DocumentID var id: String?
    var participants: [String]
    var participantNames: [String: String]
    var participantPhotoURLs: [String: String]
    var lastMessage: String
    var lastSenderId: String
    var updatedAt: Date
    var createdAt: Date
    /// Lista di uid che hanno "eliminato" la chat dalla propria lista.
    /// Optional per retro-compatibilità con conversazioni vecchie create
    /// prima dell'introduzione del campo. Il client deve trattare nil ed
    /// array vuoto come equivalenti.
    var hiddenFor: [String]?

    func otherParticipant(currentUserId: String) -> String {
        return participants.first(where: { $0 != currentUserId }) ?? ""
    }

    func otherName(currentUserId: String) -> String {
        let other = otherParticipant(currentUserId: currentUserId)
        return participantNames[other] ?? "Utente"
    }

    func otherPhotoURL(currentUserId: String) -> String? {
        let other = otherParticipant(currentUserId: currentUserId)
        return participantPhotoURLs[other]
    }

    /// True se la conversazione è stata "eliminata" da `uid` e quindi
    /// non deve apparire nella sua lista chat finché non riceve un nuovo
    /// messaggio dall'altro partecipante.
    func isHidden(for uid: String) -> Bool {
        return (hiddenFor ?? []).contains(uid)
    }
}

// MARK: - SharedPostPayload

struct SharedPostPayload: Codable {
    var postId: String
    var imageURL: String
    /// URL della pagina web da cui è stato catturato lo screenshot
    /// originale del post. Propagato da `Post.sourceURL` al momento dello
    /// share-to-chat. Optional per retro-compatibilità con messaggi
    /// vecchi (prima dell'introduzione del campo) e con post legacy.
    /// Usato dal doppio tap sulla card in chat per riaprire la pagina
    /// nella tab Cattura, stesso pattern di feed/profilo.
    var sourceURL: String?
    var caption: String
    var authorId: String
    var authorName: String
}

// MARK: - ChatMessage

struct ChatMessage: Codable, Identifiable {
    @DocumentID var id: String?
    var senderId: String
    var text: String?
    var sharedPost: SharedPostPayload?
    var createdAt: Date

    func isMine(currentUserId: String) -> Bool {
        return senderId == currentUserId
    }
}

// MARK: - Helpers

enum ChatID {
    /// ID deterministico della conversazione 1-a-1: i due uid ordinati
    /// alfabeticamente e concatenati con "_". Stesso ID se A↔B o B↔A.
    static func make(_ a: String, _ b: String) -> String {
        let pair = [a, b].sorted()
        return "\(pair[0])_\(pair[1])"
    }
}
