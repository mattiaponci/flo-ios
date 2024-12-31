

//
//  UserProfileVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit
import Firebase
import ActiveLabel
import FirebaseDatabase

protocol UserVCDelegate: AnyObject {
    func didSelectWebsiteInUser(url: URL)
}

class UserProfileVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, UserProfileHeaderDelegate, UserCellDelegate {
    
    func handleOptionsTapped(for cell: UserPostCell, isDoubleTap: Bool) {
        guard let post = cell.post else { return }

        let alertController = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)

        // Edit Post
        alertController.addAction(UIAlertAction(title: "Edit Post", style: .default, handler: { _ in
            let uploadPostController = UploadPostVC()
            uploadPostController.postToEdit = post

            // Pass image to UploadPostVC
            if let imageUrlString = post.imageUrl, let imageUrl = URL(string: imageUrlString) {
                URLSession.shared.dataTask(with: imageUrl) { data, _, error in
                    if let error = error {
                        print("Failed to load image: \(error.localizedDescription)")
                        return
                    }

                    guard let data = data, let image = UIImage(data: data) else {
                        print("Failed to convert data to UIImage")
                        return
                    }

                    DispatchQueue.main.async {
                        uploadPostController.selectedImage = image
                        uploadPostController.uploadAction = UploadPostVC.UploadAction(index: 1)
                        let navigationController = UINavigationController(rootViewController: uploadPostController)
                        navigationController.modalPresentationStyle = .fullScreen
                        self.present(navigationController, animated: true, completion: nil)
                    }
                }.resume()
            } else {
                print("Invalid or missing imageUrl for post")
            }
        }))

        // Delete Post
        alertController.addAction(UIAlertAction(title: "Delete Post", style: .destructive, handler: { _ in
            post.deletePost { error in
                if let error = error {
                    print("Failed to delete post: \(error.localizedDescription)")
                    return
                }

                DispatchQueue.main.async {
                    self.posts.removeAll { $0.postId == post.postId }
                    self.collectionView.reloadData()
                }
            }
        }))

        // Cancel Action
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alertController, animated: true, completion: nil)
    }
    
    
    func handleFlagToLike(for cell: UserPostCell, isDoubleTap: Bool) {
        guard let postId = cell.post?.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let flagsRef = Database.database().reference().child("post-flags").child(postId)
        
        flagsRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            // Controlla se il flag è presente
            if let didFlag = snapshot.value as? Int, didFlag == 1 {
                // Rimuovi il flag
                flagsRef.child(currentUid).removeValue()
                print("Flag rimosso per il post con ID: \(postId)")
                DispatchQueue.main.async {
                    cell.savePostButton.setImage(UIImage(named: "flag"), for: .normal)
                }
            } else {
                // Aggiungi il flag
                flagsRef.child(currentUid).setValue(1)
                print("Post flaggato con successo con ID: \(postId)")
                DispatchQueue.main.async {
                    cell.savePostButton.setImage(UIImage(named: "flag1"), for: .normal)
                }
            }
        }
    }
        
    
    func handleLikeTapped(for cell: UserPostCell, isDoubleTap: Bool) {
           guard let postId = cell.post?.postId else { return }
           guard let currentUid = Auth.auth().currentUser?.uid else { return }

           let likesRef = Database.database().reference().child("post-likes").child(postId)
           likesRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
               if let didLike = snapshot.value as? Int, didLike == 1 {
                   likesRef.child(currentUid).removeValue()
                   cell.likeButton.setImage(UIImage(named: "star"), for: .normal)
               } else {
                   likesRef.child(currentUid).setValue(1)
                   cell.likeButton.setImage(UIImage(named: "star2"), for: .normal)
               }
           }
       }
    
    func handleEditFollowTapped(for header: UserProfileHeader) {
        print("Edit Follow tapped")
        
        let settingsVC = SettingsViewController()
        settingsVC.modalPresentationStyle = .fullScreen // Stile per presentazione dal basso
            settingsVC.modalTransitionStyle = .coverVertical // Transizione verticale
            
            if let topController = UIApplication.shared.keyWindow?.rootViewController {
                topController.present(settingsVC, animated: true, completion: nil)
            }
    }
    
    func setUserStats(for header: UserProfileHeader) {
        print("Edit Follow tapped")

    }
    
    func handleFollowersTapped(for header: UserProfileHeader) {
        print("Edit Follow tapped")

    }
    
    func handleFollowingTapped(for header: UserProfileHeader) {
        print("Edit Follow tapped")

    }
    
    
    // MARK: - Properties
    private let reuseIdentifier = "UserPostCell"
    private let headerIdentifier = "UserProfileHeader"
    
    weak var delegate: UserVCDelegate?
    
    var user: User?
    var posts = [Post]()
    var currentKey: String?
    
    // MARK: - Init
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the collection view
        collectionView.backgroundColor = .white
        collectionView.register(UserPostCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView.register(UserProfileHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)
        
        // Configure refresh control
        configureRefreshControl()
        
        // Fetch data
       
        
        // Fetch user data and then posts
            fetchCurrentUserData {
                self.fetchSitesSavePosts()
            }
       
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.width / 1.1
        let height = width + 10 + 40
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: view.frame.width, height: 210)
    }
    
    // MARK: - UICollectionView DataSource
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 30, left: 0, bottom: 0, right: 0) // Spaziatura tra header e celle
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? UserPostCell else {
            return UICollectionViewCell()
        }

        let post = posts[indexPath.item]
        cell.post = post
        cell.delegate = self

        // Verifica se il post è stato flaggato dall'utente
        let flagsRef = Database.database().reference().child("post-flags").child(post.postId)
        if let currentUid = Auth.auth().currentUser?.uid {
            flagsRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
                if let isFlagged = snapshot.value as? Int, isFlagged == 1 {
                    DispatchQueue.main.async {
                        cell.savePostButton.setImage(UIImage(named: "flag1"), for: .normal)
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.savePostButton.setImage(UIImage(named: "flag"), for: .normal)
                    }
                }
            }
        }

        // Verifica se il post è stato liked dall'utente
        let likesRef = Database.database().reference().child("post-likes").child(post.postId)
        if let currentUid = Auth.auth().currentUser?.uid {
            likesRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
                if let isLiked = snapshot.value as? Int, isLiked == 1 {
                    DispatchQueue.main.async {
                        cell.likeButton.setImage(UIImage(named: "star2"), for: .normal)
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.likeButton.setImage(UIImage(named: "star"), for: .normal)
                    }
                }
            }
        }

        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerIdentifier, for: indexPath) as! UserProfileHeader
        header.user = self.user
        header.delegate = self
        return header
    }
    
    // MARK: - Handlers
    func handleImageclicked(url: URL) {
        print("Image tapped with URL: \(url)")
      
        
        delegate?.didSelectWebsiteInUser(url: url)

    }
    
    
    
    func handleLike(postId: String, addLike: Bool) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let values = [currentUid: addLike ? 1 : 0]
        let likesRef = Database.database().reference().child("post-likes").child(postId)

        likesRef.updateChildValues(values) { (error, ref) in
            if let error = error {
                print("Failed to like post: \(error.localizedDescription)")
                return
            }
            print("Successfully \(addLike ? "liked" : "unliked") the post.")
        }
        
        
    }
        
        
        
    func handleFlag(postId: String, addFlag: Bool) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let values = [currentUid: addFlag ? 1 : 0]
        let flagsRef = Database.database().reference().child("post-flags").child(postId)

        flagsRef.updateChildValues(values) { error, ref in
            if let error = error {
                print("Failed to flag post: \(error.localizedDescription)")
                return
            }
            print("Successfully \(addFlag ? "flagged" : "unflagged") the post.")
        }
    }
 
    func handleCommentTapped(for cell: UserPostCell) {
        guard let post = cell.post else { return }
        let commentVC = CommentVC(collectionViewLayout: UICollectionViewFlowLayout())
        commentVC.post = post
        navigationController?.pushViewController(commentVC, animated: true)
    }
    
    @objc func handleRefresh() {
        posts.removeAll(keepingCapacity: false)
        currentKey = nil
        fetchSitesSavePosts()
        collectionView.reloadData()
    }
    
    // MARK: - API
    func fetchPosts() {
        guard let currentUser = Auth.auth().currentUser else { return }
        let uid = user?.uid ?? currentUser.uid
        let query: DatabaseQuery = currentKey == nil
            ? USER_POSTS_REF.child(uid).queryLimited(toLast: 10)
            : USER_POSTS_REF.child(uid).queryOrderedByKey().queryEnding(atValue: currentKey!).queryLimited(toLast: 7)
        
        query.observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            allObjects.forEach { self.fetchPost(withPostId: $0.key) }
            self.currentKey = allObjects.first?.key
            self.collectionView.refreshControl?.endRefreshing()
        }
    }
    
    func fetchPost(withPostId postId: String) {
        Database.fetchPost(with: postId) { post in
            self.posts.append(post)
            self.posts.sort { $0.creationDate > $1.creationDate }
            self.collectionView.reloadData()
        }
    }
    
    func fetchCurrentUserData(completion: @escaping () -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            return
        }

        Database.database().reference().child("users").child(currentUid).observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else {
                print("Failed to fetch user data")
                return
            }

            self.user = User(uid: currentUid, dictionary: dictionary)
            print("User data fetched: \(self.user?.username ?? "No Username")")

            // Chiama il completion handler dopo aver caricato i dati
            completion()
        }
    }
    func fetchSitesSavePosts() {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            return
        }

        guard let currentUser = self.user else {
            print("User is nil. Cannot fetch saved posts.")
            return
        }

        print("Fetching user posts sites for user with ID: \(currentUid)")

        let ref = Database.database().reference().child("user_posts_sites").child(currentUid)

        ref.observeSingleEvent(of: .value) { snapshot in
            print("Snapshot received: \(snapshot)")

            guard snapshot.exists() else {
                print("No saved post sites found for user")
                self.collectionView?.refreshControl?.endRefreshing()
                return
            }

            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                print("Failed to cast snapshot to DataSnapshot")
                self.collectionView?.refreshControl?.endRefreshing()
                return
            }

            self.posts.removeAll()

            allObjects.forEach { snapshot in
                let postId = snapshot.key
                print("Fetching post site with ID: \(postId)")

                if let postData = snapshot.value as? [String: AnyObject] {
                    // Crea l'oggetto Post solo se i dati sono completi
                    let post = Post(postId: postId, user: currentUser, dictionary: postData)
                    self.posts.append(post)
                } else {
                    print("Snapshot does not contain valid data for post ID: \(snapshot.key)")
                }
            }

            self.posts.sort(by: { $0.creationDate > $1.creationDate })

            DispatchQueue.main.async {
                print("Reloading collectionView with \(self.posts.count) post sites")
                self.collectionView?.reloadData()
                self.collectionView?.refreshControl?.endRefreshing()
            }
        } withCancel: { error in
            print("Failed to fetch user posts sites: \(error.localizedDescription)")
            self.collectionView?.refreshControl?.endRefreshing()
        }
    }
    func configureRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
}
