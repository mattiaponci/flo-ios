//
//  UserProfile.swift
//  com.mattiaponcini.project
//
//  Modello del profilo utente salvato in Firestore.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var birthDate: Date
    var email: String
    /// URL pubblico (Firebase Storage) della foto profilo. Nil se non caricata.
    var photoURL: String? = nil
    /// Bio/descrizione del profilo utente.
    /// Default `nil` così il memberwise init non richiede il campo: utile
    /// alla registrazione (la bio si scrive dopo, dal Profilo).
    var bio: String? = nil
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firstName
        case lastName
        case birthDate
        case email
        case photoURL
        case bio
        case createdAt
    }

    /// Nome completo dell'utente
    var fullName: String { "\(firstName) \(lastName)" }
}
