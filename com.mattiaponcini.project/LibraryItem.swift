//
//  LibraryItem.swift
//  Flotip
//
//  Modello di un elemento personale salvato in libreria (News / Sport / Salvati).
//  Vive in una collection separata `libraryItems` su Firestore: NON è
//  un post pubblicato e non compare nel feed pubblico.
//

import Foundation
import FirebaseFirestore

/// Categoria di un elemento di libreria.
/// Stored come `String` raw (Codable) così Firestore vede semplici "news"/"sport"/"salvati".
///
/// La categoria `.saved` è stata aggiunta per ospitare i post di altri utenti
/// che l'utente loggato salva tramite il bottone "save" del feed: questi item
/// portano un `originalPostId` non-nil che lega l'item al post originale per
/// evitare duplicati.
enum LibraryCategory: String, Codable, CaseIterable {
    case news
    case sport
    case saved = "salvati"

    /// Etichetta localizzata mostrata nell'UI (action sheet, header riga, toast).
    var displayName: String {
        switch self {
        case .news:  return "News"
        case .sport: return "Sport"
        case .saved: return "Salvati"
        }
    }
}

/// Documento Firestore della collection `libraryItems`.
/// Filtrato sempre per `ownerId == currentUser.uid` lato client e regole.
struct LibraryItem: Codable, Identifiable {
    /// Document ID Firestore. Mappato in lettura via @DocumentID, ma teniamo
    /// anche un campo `id` esplicito nel documento per poter aggiornare/cancellare
    /// l'item più facilmente da subscriber esterni (es. drag&drop).
    @DocumentID var id: String?
    /// UID del proprietario (autore). Usato per filtri e regole sicurezza.
    var ownerId: String
    /// Categoria corrente. Aggiornata dal drag&drop.
    var category: LibraryCategory
    /// URL pubblico immagine su Firebase Storage.
    var imageURL: String
    /// URL della pagina sorgente da cui è stato catturato lo screenshot (se nota).
    var sourceURL: String?
    /// Caption opzionale presa dal composer (vuota se l'utente non l'ha scritta).
    var caption: String?
    /// Timestamp di creazione. Mantenuto per analytics e come fallback di ordinamento
    /// per item legacy salvati prima dell'introduzione del reorder manuale.
    var createdAt: Date
    /// Posizione di ordinamento manuale, gestita dal drag & drop (sort `position asc`).
    /// È `Double` per permettere interpolazione lineare fra due adiacenti
    /// (`(A.position + B.position) / 2`) senza dover riscrivere tutte le posizioni
    /// ad ogni reorder. È `Optional` perché i documenti scritti prima della migrazione
    /// non avevano questo campo: in tal caso il sort cade sul `createdAt` finché la
    /// soft-migration di `LibraryService.observe` non assegna una position iniziale.
    var position: Double?
    /// ID del Post originale quando l'item nasce dal "Salva" su un post altrui
    /// nel feed. Permette di:
    ///   - verificare se ho già salvato quel post (query `ownerId + originalPostId`)
    ///   - evitare duplicati al re-tap del bottone Save
    ///   - rimuovere il bookmark cancellando il LibraryItem corrispondente
    /// È nil per gli item salvati direttamente dal composer (news/sport classici).
    var originalPostId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case category
        case imageURL
        case sourceURL
        case caption
        case createdAt
        case position
        case originalPostId
    }
}
