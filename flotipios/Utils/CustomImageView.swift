//
//  CustomImageView.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import UIKit

// Cache globale per le immagini
var imageCache = [String: UIImage]()

class CustomImageView: UIImageView {
    
    // Variabile per tenere traccia dell'ultima URL caricata
    var lastImgUrlUsedToLoadImage: String?
    
    func loadImage(with urlString: String) {
        // Resetta l'immagine corrente
        self.image = nil
        
        // Memorizza l'ultima URL usata
        lastImgUrlUsedToLoadImage = urlString
        
        // Controlla se l'immagine esiste nella cache
        if let cachedImage = imageCache[urlString] {
            self.image = cachedImage
            return
        }
        
        // Verifica che l'URL sia valido
        guard let url = URL(string: urlString) else {
            print("Invalid URL string: \(urlString)")
            return
        }
        
        // Effettua la richiesta per ottenere l'immagine
        URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            
            // Assicurati che `self` sia ancora disponibile
            guard let self = self else { return }
            
            // Gestisci l'errore
            if let error = error {
                print("Failed to load image from URL: \(url.absoluteString) with error: \(error.localizedDescription)")
                return
            }
            
            // Controlla che l'URL sia ancora quello corretto
            if self.lastImgUrlUsedToLoadImage != url.absoluteString {
                return
            }
            
            // Controlla che i dati siano validi e crea l'immagine
            guard let imageData = data, let photoImage = UIImage(data: imageData) else {
                print("Failed to create image from data for URL: \(url.absoluteString)")
                return
            }
            
            // Salva l'immagine nella cache
            imageCache[url.absoluteString] = photoImage
            
            // Aggiorna l'immagine sull'interfaccia utente
            DispatchQueue.main.async {
                self.image = photoImage
            }
        }.resume()
    }
}
