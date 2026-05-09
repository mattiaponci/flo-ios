//
//  ImageCache.swift
//  Flotip
//
//  Cache immagini condivisa fra tutti i view controller / cell che caricano
//  copertine, avatar, screenshot, ecc. Evita di ri-scaricare la stessa
//  immagine ad ogni rebuild di cella o ad ogni scroll.
//
//  Strategia a due livelli:
//
//   1. NSCache<NSString, UIImage> in-memory: hit immediato, già decodificate,
//      pronte per essere assegnate a UIImageView.image. Costo per "byte"
//      stimato come width*height*4 (RGBA8) per dare a NSCache un budget
//      sensato in MB invece che in conteggio nudo.
//
//   2. URLCache disco/RAM: serve la richiesta HTTP da disco quando l'app
//      viene riaperta da fredda (NSCache è solo in-memory e si svuota a
//      ogni launch). Configurato come cache di default di URLSession via
//      `URLSession(configuration:)`, così tutte le `dataTask` create da
//      qui passano dalla cache.
//
//  Le richieste HTTP sono cancellabili: `loadImage(from:completion:)`
//  ritorna il `URLSessionDataTask` così le celle possono `cancel()` in
//  `prepareForReuse` ed evitare flicker quando una cella è riusata per
//  un altro item prima che il download precedente termini.
//

import UIKit

final class ImageCache {

    static let shared = ImageCache()

    /// In-memory cache di immagini decodificate. Limit ~100 entry e ~50MB
    /// di pixel buffer; NSCache esegue eviction LRU quando uno dei due
    /// limiti è superato.
    private let memory: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 200
        // ~50MB in pixel byte. La cella TikTok-style del feed può occupare
        // ~3MB decodificata; teniamo headroom per ~16-20 immagini grandi
        // più tante miniature di profilo/copertina.
        c.totalCostLimit = 50 * 1024 * 1024
        return c
    }()

    /// Cache disco/RAM esposta come property così possiamo usarla anche
    /// fuori dalla URLSession (es. inserire manualmente le risposte
    /// Firebase Storage prive di header Cache-Control).
    fileprivate let urlCache: URLCache = URLCache(
        memoryCapacity: 80 * 1024 * 1024,    // 80 MB RAM
        diskCapacity: 500 * 1024 * 1024,     // 500 MB disco
        diskPath: "FlotipImageCache"
    )

    /// URLSession dedicata per immagini, con cache disco/RAM ampia. Tutte
    /// le richieste HTTP fatte da `loadImage` passano da qui, così Firebase
    /// Storage downloadURL viene servito da disco al secondo accesso.
    ///
    /// Nota: `useProtocolCachePolicy` rispetta gli header Cache-Control del
    /// server. Firebase Storage di default invia header che permettono il
    /// caching, ma in caso di risposta priva di Cache-Control noi forziamo
    /// l'inserimento in cache via `storeCachedResponse` (vedi loadImage).
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = urlCache
        cfg.requestCachePolicy = .useProtocolCachePolicy
        cfg.httpMaximumConnectionsPerHost = 8
        return URLSession(configuration: cfg)
    }()

    private init() {
        // Svuotiamo la memory cache quando il sistema lo richiede: evita
        // OOM sotto pressione e ricostruiamo dal disk cache senza ri-scaricare.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - API

    /// Restituisce l'immagine già in cache (memory) per l'URL dato, oppure nil.
    /// Sincrono — sicuro da chiamare durante il configure() di una cella per
    /// evitare un flicker "vuoto → immagine" quando il dato è già in cache.
    func cachedImage(for url: URL) -> UIImage? {
        return memory.object(forKey: url.absoluteString as NSString)
    }

    /// Carica un'immagine da `url`. Lookup ordine:
    ///   1. memory cache (NSCache) → completion sincrono su main
    ///   2. disk cache (URLCache) → completion async su main, popola memory
    ///   3. download HTTP → popola entrambe le cache e completa async su main
    ///
    /// Il `completion` è SEMPRE chiamato su main thread, anche su errore
    /// (in tal caso passa `nil`), così i caller non devono saltare di
    /// queue. Il valore restituito è il `URLSessionDataTask` quando una
    /// fetch HTTP è effettivamente partita; altrimenti `nil` (cache hit).
    /// I caller possono `cancel()` il task in `prepareForReuse` per
    /// evitare assegnazioni a celle riusate.
    @discardableResult
    func loadImage(from url: URL,
                   completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        let key = url.absoluteString as NSString

        // 1) Memory hit: completion immediato. Restiamo asincroni a main
        // solo se il chiamante è su un'altra queue (raro, ma proteggiamoci).
        if let cached = memory.object(forKey: key) {
            if Thread.isMainThread {
                completion(cached)
            } else {
                DispatchQueue.main.async { completion(cached) }
            }
            return nil
        }

        // 2) Network/disk via URLCache. La data task usa la cache configurata
        // nella URLSession; un hit di disco non genera traffico ma chiama
        // comunque la completion del task. Decodifichiamo off-main e poi
        // invochiamo il completion del caller su main.
        let request = URLRequest(url: url, cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 30)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            // Errore esplicito o body mancante → completion(nil) e via.
            if let error = error {
                let nsError = error as NSError
                // Cancellazioni esplicite (URLError.cancelled) non sono
                // errori "veri": il caller ha già abbandonato l'immagine,
                // non chiamiamo neppure la completion per evitare di
                // sovrascrivere una nuova immagine appena assegnata.
                if nsError.domain == NSURLErrorDomain,
                   nsError.code == NSURLErrorCancelled {
                    return
                }
                DispatchQueue.main.async { completion(nil) }
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            // Forza-cache se il server (es. Firebase Storage senza
            // Cache-Control esplicito) non ci dice di cacheare. Senza
            // questo step la URLCache scarta la risposta e al prossimo
            // accesso ri-paghiamo la banda. `storeCachedResponse` qui sotto
            // è idempotente: in caso il sistema l'avesse già messa in
            // cache, sovrascriviamo la stessa entry.
            if let response = response,
               let httpResponse = response as? HTTPURLResponse,
               (httpResponse.value(forHTTPHeaderField: "Cache-Control") ?? "").isEmpty,
               let self = self {
                let cached = CachedURLResponse(
                    response: response,
                    data: data,
                    userInfo: nil,
                    storagePolicy: .allowed
                )
                self.urlCache.storeCachedResponse(cached, for: request)
            }
            // Cost stima per il NSCache: pixelBytes (≈ memoria reale del
            // pixel buffer). Se size è zero usiamo la lunghezza del data
            // come fallback prudente.
            let size = image.size
            let scale = image.scale
            let pixelBytes = max(Int(size.width * scale * size.height * scale * 4),
                                 data.count)
            self?.memory.setObject(image, forKey: key, cost: pixelBytes)
            DispatchQueue.main.async { completion(image) }
        }
        task.resume()
        return task
    }

    /// Variante di convenienza che accetta una stringa URL. Restituisce nil
    /// (e completa con nil) se la stringa non è un URL valido.
    @discardableResult
    func loadImage(from urlString: String,
                   completion: @escaping (UIImage?) -> Void) -> URLSessionDataTask? {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { completion(nil) }
            return nil
        }
        return loadImage(from: url, completion: completion)
    }

    /// Inserisce manualmente un'immagine in memory cache (es. dopo una
    /// generazione locale tipo screenshot composer).
    func setMemory(_ image: UIImage, for url: URL) {
        let size = image.size
        let scale = image.scale
        let cost = max(Int(size.width * scale * size.height * scale * 4), 1024)
        memory.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }

    @objc private func handleMemoryWarning() {
        memory.removeAllObjects()
    }
}
