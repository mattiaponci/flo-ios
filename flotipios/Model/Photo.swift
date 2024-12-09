//
//  Photo.swift
//  flotipios
//
//  Created by mattia poncini on 09.12.2024.
//

import Firebase
import Foundation

class Photo {
    var caption: String? // Può essere nil
    var likes: Int? // Può essere nil
    var imageUrl: String? // Può essere nil
    var ownerUid: String? // Può essere nil
    var creationDate: Date? // Può essere nil
    var photoId: String? // Può essere nil
    var user: User? // Può essere nil
    var didLike: Bool = false // Non è opzionale, ma ha un valore di default
    var link: String? // Campo opzionale per il link salvato

    init(photoId: String?, user: User?, dictionary: Dictionary<String, AnyObject>) {
        self.photoId = photoId
        self.user = user

        if let caption = dictionary["caption"] as? String {
            self.caption = caption
        }

        if let likes = dictionary["likes"] as? Int {
            self.likes = likes
        }

        if let imageUrl = dictionary["imageUrl"] as? String {
            self.imageUrl = imageUrl
        }

        if let ownerUid = dictionary["ownerUid"] as? String {
            self.ownerUid = ownerUid
        }

        if let creationDate = dictionary["creationDate"] as? Double {
            self.creationDate = Date(timeIntervalSince1970: creationDate)
        }

        // Assegna il link salvato se disponibile
        if let link = dictionary["pageURL"] as? String {
            self.link = link
        }
    }
}
