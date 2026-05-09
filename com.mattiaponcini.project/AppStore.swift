//
//  AppStore.swift
//  Flotip
//
//  Modello Post (Firestore) e cache locale del feed.
//  La cache è popolata dal listener real-time in PostService.
//

import UIKit
import FirebaseFirestore

/// Documento di un singolo "tip" pubblicato.
struct Post: Codable, Identifiable {
    @DocumentID var id: String?
    var imageURL: String
    /// URL della pagina web da cui è stato catturato lo screenshot.
    /// Opzionale: i post legacy non hanno questo campo.
    var sourceURL: String?
    var caption: String
    var authorId: String
    var authorName: String
    var authorPhotoURL: String?
    var createdAt: Date
    /// Contatore like denormalizzato. Mantenuto dalle Cloud Functions
    /// `onLikeCreated` / `onLikeDeleted` via FieldValue.increment(±1).
    /// I post legacy non hanno il campo: il client tratta nil come
    /// "fallback alla subcollection likes" (lettura una tantum del count
    /// vero, vedi `PostService.observeLikeCount`).
    /// Default `= nil` così i due call site che costruiscono Post in
    /// memoria (LibraryViewController, ChatThreadViewController) non
    /// devono cambiare firma.
    var likesCount: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case imageURL
        case sourceURL
        case caption
        case authorId
        case authorName
        case authorPhotoURL
        case createdAt
        case likesCount
    }
}

/// Cache in-memory del feed. Chi pubblica/osserva passa sempre da PostService;
/// AppStore è solo lo storage locale + canale di notifica per la UI.
final class AppStore {
    static let shared = AppStore()
    private init() {}

    private(set) var posts: [Post] = []

    /// Notification posted ogni volta che la cache viene aggiornata.
    static let feedUpdatedNotification = Notification.Name("AppStore.feedUpdated")

    /// Sostituisce la cache con il nuovo elenco di post (usato dal listener Firestore).
    func setPosts(_ newPosts: [Post]) {
        posts = newPosts
        NotificationCenter.default.post(name: AppStore.feedUpdatedNotification, object: nil)
    }
}
