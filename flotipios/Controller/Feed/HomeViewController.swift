//
//  HomeViewController.swift
//  flotipios
//
//  Created by mattia poncini on 09.12.2024.
//
import UIKit
import Firebase
import SafariServices

class HomeViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout, FeedCellDelegate , PhotoCellDelegate {
    func handleUsernameTapped(for cell: PhotoCell) {
        print("")
    }
    
    func handleOptionsTapped(for cell: PhotoCell) {
        print("")
    }
    
    func handleLikeTapped(for cell: PhotoCell, isDoubleTap: Bool) {
        print("")
    }
    
    func handleCommentTapped(for cell: PhotoCell) {
        print("")
    }
    
    func handleConfigureLikeButton(for cell: PhotoCell) {
        print("")
    }
    
    func handleShowLikes(for cell: PhotoCell) {
        print("")
    }
    
    func configureCommentIndicatorView(for cell: PhotoCell) {
        print("")
    }
    
    func handleSaveTapped(for cell: PhotoCell) {
        print("")
    }
    
    func handleConfigureLikeButton(for cell: FeedCell) {
        print("hello")
    }
    
    func handleSaveTapped(for cell: FeedCell) {
        print("hello")

    }
    
    
    private let reuseIdentifier = "FeedCell"
    var posts = [Post]()
    var photos = [Photo]()
    var isFetching = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configura la collection view
        collectionView.backgroundColor = .white
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView.alwaysBounceVertical = true
        
        // Configura il refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        // Imposta il titolo della navigation bar
        self.navigationItem.title = "Home"
        
        // Aggiungi il pulsante per fetchare un nuovo post
        configureNavigationBar()
        
        // Fetch iniziale del post
        fetchRandomPost()
    }
    
    // MARK: - Handlers
    
    @objc func handleRefresh() {
        fetchRandomPost()
    }
    
    func configureNavigationBar() {
        // Aggiungi un pulsante per fetchare un nuovo post
        let fetchButton = UIBarButtonItem(title: "Random Post", style: .plain, target: self, action: #selector(handleFetchButtonTapped))
        self.navigationItem.rightBarButtonItem = fetchButton
    }
    
    @objc func handleFetchButtonTapped() {
        fetchRandomPost(shouldClear: true)
    }
    
    // MARK: - API
    
    func fetchRandomPost(shouldClear: Bool = false) {
        if isFetching { return }
        isFetching = true
        
        Auth.auth().currentUser?.getIDToken { [weak self] token, error in
            guard let self = self else { return }
            if let error = error {
                print("Errore nel recuperare il token ID: \(error.localizedDescription)")
                self.isFetching = false
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            guard let token = token else {
                print("Nessun token disponibile.")
                self.isFetching = false
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            print("Token ottenuto: \(token)")
            
            guard let url = URL(string: "https://us-central1-flotip-3aa4d.cloudfunctions.net/getRandomPostFromAllUsers") else {
                print("URL non valida.")
                self.isFetching = false
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { self.isFetching = false }
                
                if let error = error {
                    print("Errore durante la richiesta: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.collectionView.refreshControl?.endRefreshing()
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("Errore dal server: \(httpResponse.statusCode)")
                        DispatchQueue.main.async {
                            self.collectionView.refreshControl?.endRefreshing()
                        }
                        return
                    }
                }
                
                guard let data = data else {
                    print("Nessun dato ricevuto dal server.")
                    DispatchQueue.main.async {
                        self.collectionView.refreshControl?.endRefreshing()
                    }
                    return
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                       let postId = jsonResponse["postId"] {
                        print("Post ID ricevuto: \(postId)")
                        
                        // Recupera i dettagli del post
                        self.fetchPhotoDetails(withPhotoId: postId, shouldClear: shouldClear)
                        
                    } else {
                        print("Parsing JSON fallito.")
                        DispatchQueue.main.async {
                            self.collectionView.refreshControl?.endRefreshing()
                        }
                    }
                } catch {
                    print("Errore durante il parsing JSON: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.collectionView.refreshControl?.endRefreshing()
                    }
                }
            }.resume()
        }
    }
    

    func fetchPhotoDetails(withPhotoId photoId: String, shouldClear: Bool) {
        Database.fetchPhoto(with: photoId) { [weak self] photo in
            guard let self = self else { return }
            
            //try
            
            print("Richiesta completata per photoId: \(photoId)")
            if let photo = photo {
                print("Foto ricevuta: \(photo)")
                print("Photo ID: \(photo.photoId ?? "Nessun ID")")
            } else {
                print("Errore: Foto non trovata o non valida per ID \(photoId).")
            }
            
            // Gestione del caso in cui la foto non esista
            guard let photo = photo else {
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            // Log dettagliati sull'array photos
            print("Numero attuale di foto: \(self.photos.count)")
            if shouldClear {
                print("Pulizia dell'array photos.")
                self.photos.removeAll()
            }
            
            // Controlla i duplicati
            if self.photos.contains(where: { $0.photoId == photo.photoId }) {
                print("La foto con ID \(photo.photoId ?? "Nessun ID") è già presente nell'array.")
            } else {
                self.photos.append(photo)
                print("Foto aggiunta all'array: \(photo.photoId ?? "Nessun ID")")
            }
            
            // Aggiorna la UI
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.collectionView.refreshControl?.endRefreshing()
            }
        }
    }
    // MARK: - UICollectionView DataSource & Delegate
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? PhotoCell else {
            fatalError("Failed to dequeue PhotoCell")
        }
        
        let photo = photos[indexPath.item]
        cell.photo = photo
        cell.delegate = self // Configura il delegato se necessario
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.width - 20 // Margine
        let height: CGFloat = 500 // Altezza fissa o calcolata dinamicamente
        return CGSize(width: width, height: height)
    }
    
    // MARK: - FeedCellDelegate
    
 
    
    func handleUsernameTapped(for cell: FeedCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let post = posts[indexPath.item]
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = post.user
        navigationController?.pushViewController(userProfileVC, animated: true)
    }
    
    func handleOptionsTapped(for cell: FeedCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let post = posts[indexPath.item]
        
        if post.ownerUid == Auth.auth().currentUser?.uid {
            let alertController = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)
            
            alertController.addAction(UIAlertAction(title: "Delete Post", style: .destructive, handler: { _ in
                post.deletePost()
                self.posts.remove(at: indexPath.item)
                self.collectionView.deleteItems(at: [indexPath])
            }))
            
            alertController.addAction(UIAlertAction(title: "Edit Post", style: .default, handler: { _ in
                let uploadPostController = UploadPostVC()
                uploadPostController.postToEdit = post
                let navController = UINavigationController(rootViewController: uploadPostController)
                self.present(navController, animated: true, completion: nil)
            }))
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func handleLikeTapped(for cell: FeedCell, isDoubleTap: Bool) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        var post = posts[indexPath.item]
        
        if post.didLike {
            post.adjustLikes(addLike: false) { likes in
                self.posts[indexPath.item].likes = likes
                self.posts[indexPath.item].didLike = false
                DispatchQueue.main.async {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }
        } else {
            post.adjustLikes(addLike: true) { likes in
                self.posts[indexPath.item].likes = likes
                self.posts[indexPath.item].didLike = true
                DispatchQueue.main.async {
                    self.collectionView.reloadItems(at: [indexPath])
                }
            }
        }
    }
    
    func handleCommentTapped(for cell: FeedCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let post = posts[indexPath.item]
        let commentVC = CommentVC(collectionViewLayout: UICollectionViewFlowLayout())
        commentVC.post = post
        navigationController?.pushViewController(commentVC, animated: true)
    }
    
    func handleShowLikes(for cell: FeedCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let post = posts[indexPath.item]
        let followLikeVC = FollowLikeVC()
      //  followLikeVC.viewingMode = .likes
        followLikeVC.postId = post.postId
        navigationController?.pushViewController(followLikeVC, animated: true)
    }
    
    func handleImageTapped(url: URL) {
        // Apri l'URL in Safari
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }
    
    func configureCommentIndicatorView(for cell: FeedCell) {
        // Implementa la logica per mostrare o nascondere l'indicatore dei commenti
    }
}
