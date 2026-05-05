//
//  AuthService.swift
//  com.mattiaponcini.project
//
//  Wrapper Firebase Auth + Firestore + Storage per registrazione/login utenti.
//  Il listener di autenticazione è gestito in SceneDelegate (background).
//

import Foundation
import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

private let authLog = OSLog(subsystem: "com.mattiaponcini.project", category: "AuthService")

enum AuthError: LocalizedError {
    case passwordMismatch
    case weakPassword
    case missingFields
    case imageEncoding
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .passwordMismatch: return "Le password non coincidono."
        case .weakPassword: return "La password deve essere di almeno 6 caratteri."
        case .missingFields: return "Compila tutti i campi obbligatori."
        case .imageEncoding: return "Impossibile elaborare l'immagine selezionata."
        case .underlying(let error): return error.localizedDescription
        }
    }
}

final class AuthService {

    static let shared = AuthService()
    private init() {}

    private let auth = Auth.auth()
    private lazy var db = Firestore.firestore()
    private lazy var storage = Storage.storage()

    // MARK: - Stato

    var isLoggedIn: Bool { auth.currentUser != nil }
    var currentUserId: String? { auth.currentUser?.uid }

    // MARK: - Registrazione

    /// Crea un account email/password, carica la foto profilo (se presente) su Storage
    /// e salva il documento utente in Firestore.
    func register(firstName: String,
                  lastName: String,
                  birthDate: Date,
                  photo: UIImage?,
                  email: String,
                  password: String,
                  confirmPassword: String,
                  completion: @escaping (Result<UserProfile, Error>) -> Void) {

        // Validazioni base
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirst.isEmpty,
              !trimmedLast.isEmpty,
              !trimmedEmail.isEmpty,
              !password.isEmpty else {
            completion(.failure(AuthError.missingFields))
            return
        }
        guard password.count >= 6 else {
            completion(.failure(AuthError.weakPassword))
            return
        }
        guard password == confirmPassword else {
            completion(.failure(AuthError.passwordMismatch))
            return
        }

        auth.createUser(withEmail: trimmedEmail, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                os_log("register: createUser fallito — %{public}@",
                       log: authLog, type: .error, error.localizedDescription)
                completion(.failure(AuthError.underlying(error)))
                return
            }
            guard let uid = result?.user.uid else {
                os_log("register: UID mancante dopo createUser", log: authLog, type: .error)
                completion(.failure(AuthError.underlying(NSError(
                    domain: "AuthService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "UID mancante dopo la creazione utente."]
                ))))
                return
            }

            // Step 2: upload foto (opzionale), poi salvataggio Firestore.
            // Nota: il completion di success viene chiamato SOLO dopo che il
            // doc Firestore è stato scritto correttamente, così non finiamo
            // in stato inconsistente (account Auth creato ma profilo mancante).
            self.uploadProfilePhotoIfNeeded(uid: uid, photo: photo) { uploadResult in
                let photoURL: String?
                switch uploadResult {
                case .failure(let error):
                    // Storage può non essere disponibile (piano gratuito) —
                    // proseguiamo comunque senza foto, così almeno il doc
                    // utente viene creato.
                    os_log("register: upload foto fallito (proseguo senza foto) — %{public}@",
                           log: authLog, type: .info, error.localizedDescription)
                    photoURL = nil
                case .success(let url):
                    photoURL = url
                }
                let profile = UserProfile(
                    id: uid,
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    birthDate: birthDate,
                    email: trimmedEmail,
                    photoURL: photoURL,
                    createdAt: Date()
                )
                self.saveUserProfile(profile) { saveResult in
                    switch saveResult {
                    case .success:
                        os_log("register: doc users/%{public}@ scritto con successo",
                               log: authLog, type: .info, uid)
                        completion(.success(profile))
                    case .failure(let error):
                        os_log("register: scrittura Firestore fallita per uid=%{public}@ — %{public}@",
                               log: authLog, type: .error, uid, error.localizedDescription)
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // MARK: - Login

    func login(email: String,
               password: String,
               completion: @escaping (Result<Void, Error>) -> Void) {

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            completion(.failure(AuthError.missingFields))
            return
        }

        auth.signIn(withEmail: trimmedEmail, password: password) { _, error in
            if let error = error {
                completion(.failure(AuthError.underlying(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Logout

    func logout() throws {
        try auth.signOut()
    }

    // MARK: - Password reset

    /// Invia all'email indicata il link per reimpostare la password.
    /// Mantenuto col pattern completion-handler per coerenza col resto di
    /// AuthService (login/register usano lo stesso stile).
    /// Il template email è gestito da Firebase Console
    /// (Authentication → Templates → Password reset).
    func sendPasswordReset(email: String,
                           completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            completion(.failure(AuthError.missingFields))
            return
        }
        auth.sendPasswordReset(withEmail: trimmedEmail) { error in
            if let error = error {
                os_log("sendPasswordReset: errore per %{public}@ — %{public}@",
                       log: authLog, type: .error, trimmedEmail, error.localizedDescription)
                completion(.failure(AuthError.underlying(error)))
            } else {
                os_log("sendPasswordReset: email inviata a %{public}@",
                       log: authLog, type: .info, trimmedEmail)
                completion(.success(()))
            }
        }
    }

    // MARK: - Lettura profilo

    /// Carica il profilo utente da Firestore. Se il documento `users/{uid}`
    /// non esiste (es. utente registrato ma scrittura Firestore mai avvenuta,
    /// oppure utente creato direttamente da console Firebase) lo crea
    /// on-the-fly usando i dati di `Auth.auth().currentUser` come fallback.
    /// In questo modo lo spinner non resta bloccato in caso di doc mancante.
    func fetchCurrentUserProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        guard let user = auth.currentUser else {
            os_log("fetchCurrentUserProfile: nessun utente loggato", log: authLog, type: .error)
            completion(.failure(AuthError.underlying(NSError(
                domain: "AuthService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Nessun utente loggato."]
            ))))
            return
        }
        let uid = user.uid
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                os_log("fetchCurrentUserProfile: errore Firestore per uid=%{public}@ — %{public}@",
                       log: authLog, type: .error, uid, error.localizedDescription)
                completion(.failure(AuthError.underlying(error)))
                return
            }
            if let snapshot = snapshot, snapshot.exists {
                do {
                    let profile = try snapshot.data(as: UserProfile.self)
                    completion(.success(profile))
                } catch {
                    os_log("fetchCurrentUserProfile: decoding error — %{public}@",
                           log: authLog, type: .error, error.localizedDescription)
                    completion(.failure(AuthError.underlying(error)))
                }
                return
            }
            // Documento mancante: lo creiamo on-the-fly con dati Auth
            os_log("fetchCurrentUserProfile: doc users/%{public}@ inesistente, creo placeholder",
                   log: authLog, type: .info, uid)
            self.createPlaceholderProfile(for: user, completion: completion)
        }
    }

    /// Crea un documento `users/{uid}` minimale con i dati disponibili da
    /// Firebase Auth (email, displayName se presente). Pensato come safety
    /// net per evitare lo spinner infinito quando register() non ha scritto
    /// il doc oppure l'utente è stato creato fuori dall'app.
    private func createPlaceholderProfile(for user: FirebaseAuth.User,
                                          completion: @escaping (Result<UserProfile, Error>) -> Void) {
        let display = (user.displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = display.split(separator: " ", maxSplits: 1).map(String.init)
        let firstName = parts.first ?? "Utente"
        let lastName = parts.count > 1 ? parts[1] : ""
        let placeholder = UserProfile(
            id: user.uid,
            firstName: firstName.isEmpty ? "Utente" : firstName,
            lastName: lastName,
            birthDate: Date(timeIntervalSince1970: 0),
            email: user.email ?? "",
            photoURL: user.photoURL?.absoluteString,
            createdAt: Date()
        )
        saveUserProfile(placeholder) { result in
            switch result {
            case .success:
                os_log("createPlaceholderProfile: doc users/%{public}@ creato",
                       log: authLog, type: .info, user.uid)
                completion(.success(placeholder))
            case .failure(let error):
                os_log("createPlaceholderProfile: scrittura fallita — %{public}@",
                       log: authLog, type: .error, error.localizedDescription)
                completion(.failure(error))
            }
        }
    }

    // MARK: - Aggiornamento profilo

    /// Aggiorna bio e/o foto profilo su Firestore (e Storage se disponibile).
    func updateProfile(bio: String?,
                       newPhoto: UIImage?,
                       completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = currentUserId else {
            completion(.failure(AuthError.underlying(NSError(
                domain: "AuthService", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Nessun utente loggato."]
            ))))
            return
        }

        // Se c'è una nuova foto, proviamo a caricarla su Storage
        if let photo = newPhoto {
            uploadProfilePhotoIfNeeded(uid: uid, photo: photo) { [weak self] uploadResult in
                guard let self = self else { return }
                switch uploadResult {
                case .failure:
                    // Storage non disponibile (piano gratuito) — aggiorna solo la bio
                    self.patchFirestoreProfile(uid: uid, fields: ["bio": bio ?? ""],
                                              completion: completion)
                case .success(let photoURL):
                    var fields: [String: Any] = ["bio": bio ?? ""]
                    if let url = photoURL { fields["photoURL"] = url }
                    self.patchFirestoreProfile(uid: uid, fields: fields, completion: completion)
                }
            }
        } else {
            // Nessuna foto nuova — aggiorna solo la bio
            patchFirestoreProfile(uid: uid, fields: ["bio": bio ?? ""], completion: completion)
        }
    }

    /// Aggiornamento parziale di un documento utente in Firestore.
    private func patchFirestoreProfile(uid: String,
                                       fields: [String: Any],
                                       completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("users").document(uid).updateData(fields) { error in
            if let error = error {
                completion(.failure(AuthError.underlying(error)))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: - Helpers

    private func uploadProfilePhotoIfNeeded(uid: String,
                                            photo: UIImage?,
                                            completion: @escaping (Result<String?, Error>) -> Void) {
        guard let photo = photo else {
            completion(.success(nil))
            return
        }
        guard let data = photo.jpegData(compressionQuality: 0.8) else {
            completion(.failure(AuthError.imageEncoding))
            return
        }
        // Path: profile_photos/{uid}/avatar.jpg
        // Le rules Firebase Storage matchano in modo affidabile su {uid} solo
        // se è un INTERO segmento di path. Mettere uid dentro una cartella
        // dedicata evita ambiguità tipo "profile_photos/{uid}.jpg".
        let ref = storage.reference().child("profile_photos/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        ref.putData(data, metadata: metadata) { _, error in
            if let error = error {
                NSLog("[AuthService] upload foto profilo fallito: \(error.localizedDescription)")
                completion(.failure(AuthError.underlying(error)))
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    NSLog("[AuthService] downloadURL foto profilo fallito: \(error.localizedDescription)")
                    completion(.failure(AuthError.underlying(error)))
                    return
                }
                completion(.success(url?.absoluteString))
            }
        }
    }

    private func saveUserProfile(_ profile: UserProfile,
                                 completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = profile.id else {
            completion(.failure(AuthError.underlying(NSError(
                domain: "AuthService", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "UID mancante nel profilo."]
            ))))
            return
        }
        do {
            try db.collection("users").document(uid).setData(from: profile) { error in
                if let error = error {
                    completion(.failure(AuthError.underlying(error)))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(AuthError.underlying(error)))
        }
    }
}
