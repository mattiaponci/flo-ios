//
//  UserProfileVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit
import Firebase
import ActiveLabel



protocol UserVCDelegate: AnyObject {
    func didSelectWebsiteInUser(url: URL)
}

class UserProfileVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, UserProfileHeaderDelegate, UserCellDelegate {
    
    private let reuseIdentifier = "Cell"
    private let headerIdentifier = "UserProfileHeader"

    
    // MARK: - Properties
    weak var delegate: UserVCDelegate?
    
    // Data arrays
  //  var userPostsSites = [Post]()
    

    var user: User?
    var posts = [Post]()
    var viewSinglePost = false
    var post: Post?
    var currentKey: String?
    var userProfileController: UserProfileVC?
    var isFlagged: Bool = false // Stato iniziale, non flaggato
    var postSaved: Bool = false
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()

   
        // Register the cell and header classes
           self.collectionView!.register(UserPostCell.self, forCellWithReuseIdentifier: reuseIdentifier)
           self.collectionView!.register(UserProfileHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)        // configure refresh control
        
        
        configureRefreshControl()
        
        // background color
        self.collectionView?.backgroundColor = .white

        // fetch user data
        // fetch user data
         if self.user == nil {
             fetchCurrentUserData()
             fetchSitesSavePosts()
         }
        
        // fetch posts
        

        // Configura il pulsante delle impostazioni nella barra di navigazione
      /*  let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(handleSettingsTapped))*/
        
       // configureNavigationBar()
        // configure navigation bar
        // configure navigation bar
           
      //  navigationItem.rightBarButtonItem = settingsButton
        
        configureNavigationBar()
        
        if self.user == nil {
                fetchCurrentUserData()  // Se `user` è nullo, carica i dati dell'utente corrente
            } else {
            //    configureNavigationBar()  // Configura la barra di navigazione
               // fetchPosts()  // Carica i post solo se `user` è già disponibile
            }

    }
  
        
    func configureNavigationBar() {
        guard let currentUser = Auth.auth().currentUser else { return }
        
        // Controlla se l'username dell'utente visualizzato è diverso da quello dell'utente corrente
        Database.database().reference().child("users").child(currentUser.uid).observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else { return }
            let currentUsername = dictionary["username"] as? String
            
            // Mostra il pulsante gear solo se l'username corrisponde a quello dell'utente corrente
            if self.user?.username == currentUsername {
                let settingsButton = UIBarButtonItem(
                    image: UIImage(systemName: "gearshape.fill"),
                    style: .plain,
                    target: self,
                    action: #selector(self.handleSettingsTapped)
                )
                self.navigationItem.rightBarButtonItem = settingsButton
            } else {
                self.navigationItem.rightBarButtonItem = nil
            }
        }
    }

        
        @objc func handleSettingsTapped() {
            let settingsVC = SettingsViewController()
            let navController = UINavigationController(rootViewController: settingsVC)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true, completion: nil)
        }
    
        
    // MARK: - Configurazione della barra di navigazione
      
    

    // MARK: - UICollectionViewFlowLayout
    
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
        return CGSize(width: view.frame.width, height: 200)
    }

    // MARK: - UICollectionView

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if posts.count > 9, indexPath.item == posts.count - 1 {
            fetchSitesSavePosts()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }
    
    func handleImageclicked(url: URL) {
        print("Delegate method called with URL: \(url)")
        print("secondo passaggio")
        if delegate != nil {
            print("Delegate is not nil, calling didSelectWebsiteInUser")
            
            
            delegate?.didSelectWebsiteInUser(url: url)
        } else {
            print("Delegate is nil, kipping call to didSelectWebsiteInUser")
        }
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerIdentifier, for: indexPath) as! UserProfileHeader
        header.delegate = self
        header.user = self.user
        navigationItem.title = user?.username
        return header
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! UserPostCell
        cell.post = posts[indexPath.item]
        cell.delegate = self  // UserProfileVC è il delegato di UserPostCell
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedVC = FeedVC(collectionViewLayout: UICollectionViewFlowLayout())
       // feedVC.viewSinglePost = true
      //  feedVC.userProfileController = self
      //  feedVC.post = posts[indexPath.item]
        navigationController?.pushViewController(feedVC, animated: true)
    }
    
    // MARK: - UserProfileHeader
    
    func handleFollowersTapped(for header: UserProfileHeader) {
        let followVC = FollowLikeVC()
        followVC.viewingMode = FollowLikeVC.ViewingMode(index: 1)
        followVC.uid = user?.uid
        navigationController?.pushViewController(followVC, animated: true)
    }
    
    func handleFollowingTapped(for header: UserProfileHeader) {
        let followVC = FollowLikeVC()
        followVC.viewingMode = FollowLikeVC.ViewingMode(index: 0)
        followVC.uid = user?.uid
        navigationController?.pushViewController(followVC, animated: true)
    }
    
    func handleEditFollowTapped(for header: UserProfileHeader) {
        guard let user = header.user else { return }
        if header.editProfileFollowButton.titleLabel?.text == "Edit Profile" {
            let editProfileController = EditProfileController()
            editProfileController.user = user
            editProfileController.userProfileController = self
            let navigationController = UINavigationController(rootViewController: editProfileController)
            present(navigationController, animated: true, completion: nil)
        } else {
            if header.editProfileFollowButton.titleLabel?.text == "Follow" {
                header.editProfileFollowButton.setTitle("Following", for: .normal)
                user.follow()
            } else {
                header.editProfileFollowButton.setTitle("Follow", for: .normal)
                user.unfollow()
            }
        }
    }
    
    func setUserStats(for header: UserProfileHeader) {
        guard let uid = header.user?.uid else { return }
        
        // Contare i followers
        USER_FOLLOWER_REF.child(uid).observe(.value) { snapshot in
            let numberOfFollowers = snapshot.childrenCount
            let attributedText = NSMutableAttributedString(
                string: "\(numberOfFollowers)\n",
                attributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            )
            attributedText.append(NSAttributedString(
                string: "followers",
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            ))
            header.followersLabel.attributedText = attributedText
        }
        
        // Contare chi l'utente segue
        USER_FOLLOWING_REF.child(uid).observe(.value) { snapshot in
            let numberOfFollowing = snapshot.childrenCount
            let attributedText = NSMutableAttributedString(
                string: "\(numberOfFollowing)\n",
                attributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            )
            attributedText.append(NSAttributedString(
                string: "following",
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            ))
            header.followingLabel.attributedText = attributedText
        }
        
        // Contare i siti salvati al posto dei post
        USER_SAVED_SITES_REF.child(uid).observeSingleEvent(of: .value) { snapshot in
            let savedSiteCount = snapshot.exists() ? snapshot.childrenCount : 0

            // Aggiorna il conteggio usando anche `userPostsSites`
            let visibleSitesCount = self.posts.count

            // Aggiorniamo il numero di siti salvati che sono ancora visibili
            let attributedText = NSMutableAttributedString(
                string: "\(visibleSitesCount)\n",
                attributes: [
                    NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            )
            attributedText.append(NSAttributedString(
                string: "saved sites",
                attributes: [
                    NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14),
                    NSAttributedString.Key.foregroundColor: UIColor.black
                ]
            ))
            header.postsLabel.attributedText = attributedText

            // Debug per verificare il conteggio finale
            print("DEBUG: Numero di siti salvati e ancora visibili: \(visibleSitesCount)")
        }
    }


    
    // MARK: - Handlers
    
    @objc func handleRefresh() {
        posts.removeAll(keepingCapacity: false)
        self.currentKey = nil
        fetchSitesSavePosts()
        collectionView?.reloadData()
    }
    
    func configureRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView?.refreshControl = refreshControl
    }
    
    // MARK: - API
    
   func fetchPosts() {
        guard let currentUser = Auth.auth().currentUser else { return }

        // Recupera l'username dell'utente corrente da Firebase
        Database.database().reference().child("users").child(currentUser.uid).observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else { return }
            let currentUsername = dictionary["username"] as? String

            // Verifica che l'utente visualizzato sia quello corrente
            guard self.user?.username == currentUsername else {
                print("L'utente visualizzato non è quello corrente. Non verranno stampati i post.")
                return
            }

            // Procede solo se l'utente visualizzato è quello corrente
            let uid = self.user?.uid ?? currentUser.uid
            
            if self.currentKey == nil {
                USER_POSTS_REF.child(uid).queryLimited(toLast: 10).observeSingleEvent(of: .value) { snapshot in
                    self.collectionView?.refreshControl?.endRefreshing()
                    guard let first = snapshot.children.allObjects.first as? DataSnapshot else { return }
                    guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
                    allObjects.forEach { snapshot in
                        let postId = snapshot.key
                        self.fetchPost(withPostId: postId)
                    }
                    self.currentKey = first.key
                }
            } else {
                USER_POSTS_REF.child(uid).queryOrderedByKey().queryEnding(atValue: self.currentKey).queryLimited(toLast: 7).observeSingleEvent(of: .value) { snapshot in
                    guard let first = snapshot.children.allObjects.first as? DataSnapshot else { return }
                    guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
                    allObjects.forEach { snapshot in
                        let postId = snapshot.key
                        if postId != self.currentKey {
                            self.fetchPost(withPostId: postId)
                        }
                    }
                    self.currentKey = first.key
                }
            }
        }
    }


    
    func fetchPost(withPostId postId: String) {
        Database.fetchPost(with: postId) { post in
            self.posts.append(post)
            self.posts.sort { $0.creationDate > $1.creationDate }
            self.collectionView?.reloadData()
        }
    }
    func handleLikeTapped(for cell: UserPostCell, isDoubleTap: Bool) {
        guard let post = cell.post else { return }

        if post.didLike {
            if !isDoubleTap {
                post.adjustLikes(addLike: false, completion: { (likes) in
                    cell.likesLabel.text = "\(likes) likes"
                    cell.likeButton.setImage(UIImage(named: "star2"), for: .normal)
                })
            }
        } else {
            post.adjustLikes(addLike: true, completion: { (likes) in
                cell.likesLabel.text = "\(likes) likes"
                cell.likeButton.setImage(UIImage(named: "star"), for: .normal)
            })
        }
    }
    func fetchCurrentUserData() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference().child("users").child(currentUid).observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else { return }
            let uid = snapshot.key
            let user = User(uid: uid, dictionary: dictionary)
            self.user = user
            self.navigationItem.title = user.username
            self.collectionView?.reloadData()

        }
    }
    
    func fetchSitesSavePosts() {
        // Determina l'UID dell'utente da cui recuperare i siti salvati
        let uid = self.user?.uid ?? Auth.auth().currentUser?.uid
        guard let userId = uid else { return }

        // Definisce la query per il caricamento iniziale o incrementale
        let query: DatabaseQuery
        if currentKey == nil {
            // Primo caricamento: limita ai 10 siti più recenti
            query = USER_SAVED_SITES_REF.child(userId).queryLimited(toLast: 10)
        } else {
            // Caricamento incrementale: limita ai successivi 7 siti
            query = USER_SAVED_SITES_REF.child(userId).queryOrderedByKey().queryEnding(atValue: currentKey).queryLimited(toLast: 7)
        }
        
        query.observeSingleEvent(of: .value) { snapshot in
            // Recupera il primo e tutti gli altri siti salvati
            guard let first = snapshot.children.allObjects.first as? DataSnapshot else { return }
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            // Svuota la lista dei post solo al primo caricamento
            if self.currentKey == nil {
                self.posts.removeAll()
            }
            
            // Carica ciascun sito salvato evitando duplicati
            allObjects.forEach { snapshot in
                let postId = snapshot.key
                if postId != self.currentKey {  // Evita duplicati nel caricamento incrementale
                    self.fetchPost(withPostId: postId) { post in
                        self.posts.append(post)
                        self.posts.sort { $0.creationDate > $1.creationDate }
                        
                        // Ricarica la collection view sulla main queue
                        DispatchQueue.main.async {
                            self.collectionView?.reloadData()
                            self.collectionView?.refreshControl?.endRefreshing()
                        }
                    }
                }
            }
            
            // Aggiorna currentKey per il prossimo caricamento incrementale
            self.currentKey = first.key
        }
    }

    func handleCommentTapped(for cell: UserPostCell) {
        guard let post = cell.post else { return }
        let commentVC = CommentVC(collectionViewLayout: UICollectionViewFlowLayout())
        commentVC.post = post
        navigationController?.pushViewController(commentVC, animated: true)
    }
    
    func fetchPost(withPostId postId: String, completion: @escaping (Post) -> Void) {
        Database.fetchPost(with: postId) { post in
            completion(post)
        }
    }
    
    func configureCommentIndicatorView(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }

        COMMENT_REF.child(postId).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.exists() {
              //  cell.addCommentIndicatorView(toStackView: cell.stackView)
            } else {
             //   cell.commentIndicatorView.isHidden = true
            }
        }
    }
}
