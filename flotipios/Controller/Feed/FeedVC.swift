//
//  FeedVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit
import Firebase
import ActiveLabel


protocol FeedVCDelegate: AnyObject {
    func didSelectWebsiteInFeed(url: URL)
}

class FeedVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, FeedCellDelegate {
   
    

    weak var delegate: FeedVCDelegate?

    private let reuseIdentifier = "Cell"

    // MARK: - Properties
    var posts = [Post]()
    var user: User?
    var viewSinglePost = false
    var post: Post?
    var currentKey: String?
    var userProfileController: UserProfileVC?
    var isFlagged: Bool = false // Stato iniziale, non flaggato
    var postSaved: Bool = false
    var isFetching = false



    var messageNotificationView: MessageNotificationView = {
        let view = MessageNotificationView()
        return view
    }()

    // MARK: - Init
    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView?.backgroundColor = .white

        // Disable scroll indicators
        collectionView?.showsVerticalScrollIndicator = false

        // Register cell classes
        self.collectionView!.register(FeedCell.self, forCellWithReuseIdentifier: reuseIdentifier)

        // Configure refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView?.refreshControl = refreshControl
        // Adjust section insets
            if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
                layout.sectionInset = UIEdgeInsets(top: 30, left: 0, bottom: 0, right: 0)  // Adjust top inset as needed
            }
        // Configure logout button
        configureNavigationBar()

        // Fetch posts
           // fetchSitesSavePosts()
            fetchSitesSavePosts()
        

        
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        setUnreadMessageCount()

    }

    // MARK: - UICollectionViewFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = view.frame.width / 1.1
        var height = width + 10 + 40
        return CGSize(width: width, height: height)
    }

    // MARK: - UICollectionViewDataSource
   /* override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        print("indexPath.item: \(indexPath.item), posts.count: \(posts.count)")

        if posts.count > 4 {
            if indexPath.item == posts.count - 1 {
                //fetchSitesSavePosts()
               // fetchRandomUserPost()
            }
        }
    }*/

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewSinglePost ? 1 : posts.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("Configuring cell for item at indexPath: \(indexPath.item)")

        guard indexPath.item < posts.count else {
            print("Error: Attempted to access an index out of bounds. indexPath: \(indexPath.item), posts.count: \(posts.count)")
            return UICollectionViewCell()
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! FeedCell
        cell.delegate = self

        if viewSinglePost {
            if let post = self.post {
                cell.post = post
            }
        } else {
            cell.post = posts[indexPath.item]
        }

        // Verifica se il post appartiene all'utente corrente
        if let post = cell.post, let currentUid = Auth.auth().currentUser?.uid {
            if post.ownerUid == currentUid {
                print("Hiding save button for user's own post")
              //  cell.savePostButton.isHidden = true
            } else {
                print("Showing save button for post by user \(post.ownerUid)")
                cell.savePostButton.isHidden = false

                // Verifica se il post è stato salvato
                USER_SAVED_REF.child(currentUid).child(post.postId ?? "").observeSingleEvent(of: .value) { snapshot in
                    if snapshot.exists() {
                        print("Post \(post.postId ?? "") is saved")
                        cell.postSaved = true
                        cell.savePostButton.setImage(#imageLiteral(resourceName: "flag1"), for: .normal)
                    } else {
                        print("Post \(post.postId ?? "") is not saved")
                        cell.postSaved = false
                        cell.savePostButton.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
                    }
                }
            }
        }

        handleHashtagTapped(forCell: cell)
        handleUsernameLabelTapped(forCell: cell)
        handleMentionTapped(forCell: cell)
        configureLikeAndFlagButtons(for: cell)

        return cell
    }

    // MARK: - FeedCellDelegate
    func handleUsernameTapped(for cell: FeedCell) {
        guard let post = cell.post else { return }
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = post.user
        userProfileVC.isFromSearch = false // Specifica che non proviene dalla ricerca
        userProfileVC.isFromFeed = true // Imposta isFromFeed

        navigationController?.pushViewController(userProfileVC, animated: true)
    }

   
    func handleOptionsTapped(for cell: FeedCell) {
        guard let post = cell.post else { return }

        if post.ownerUid == Auth.auth().currentUser?.uid {
            let alertController = UIAlertController(title: "Options", message: nil, preferredStyle: .actionSheet)

            // Edit Post
            alertController.addAction(UIAlertAction(title: "Edit Post", style: .default, handler: { (_) in
                let uploadPostController = UploadPostVC()
                let navigationController = UINavigationController(rootViewController: uploadPostController)
                uploadPostController.postToEdit = post
                uploadPostController.uploadAction = UploadPostVC.UploadAction(index: 1)
                navigationController.modalPresentationStyle = .fullScreen
                self.present(navigationController, animated: true, completion: nil)
            }))

            // Delete Post
            alertController.addAction(UIAlertAction(title: "Delete Post", style: .destructive, handler: { (_) in
                guard let postId = post.postId else {
                    print("Post ID is missing.")
                    return
                }
                
                post.deletePost(postId: postId) { error in
                    if let error = error {
                        print("Failed to delete post: \(error.localizedDescription)")
                    } else {
                        print("Post deleted successfully")

                        if !self.viewSinglePost {
                            self.handleRefresh()
                        } else {
                            if let userProfileController = self.userProfileController {
                                _ = self.navigationController?.popViewController(animated: true)
                                userProfileController.handleRefresh()
                            }
                        }
                    }
                }
            }))

            // Cancel
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alertController, animated: true, completion: nil)
        }
    }
    func handleImageTapped(url: URL) {
        print("Delegate method called with URL: \(url)")
        print("secondo passaggio")

        delegate?.didSelectWebsiteInFeed(url: url)
    }

    func handleLikeTapped(for cell: FeedCell, isDoubleTap: Bool) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let likesRef = Database.database().reference().child("post-likes").child(postId)

        // Controlla se il like è già presente
        likesRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                // Rimuovi il like
                likesRef.child(currentUid).removeValue { error, _ in
                    if let error = error {
                        print("Failed to unlike post: \(error.localizedDescription)")
                        return
                    }
                    print("Post unliked")
                    DispatchQueue.main.async {
                        cell.likeButton.setImage(#imageLiteral(resourceName: "star"), for: .normal)
                    }
                }
            } else {
                // Aggiungi il like
                likesRef.child(currentUid).setValue(1) { error, _ in
                    if let error = error {
                        print("Failed to like post: \(error.localizedDescription)")
                        return
                    }
                    print("Post liked")
                    DispatchQueue.main.async {
                        cell.likeButton.setImage(#imageLiteral(resourceName: "star2"), for: .normal)
                    }
                }
            }
        }
    }

    func handleShowLikes(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }

        let followLikeVC = FollowLikeVC()
        followLikeVC.viewingMode = FollowLikeVC.ViewingMode(index: 2)
        followLikeVC.postId = postId
        navigationController?.pushViewController(followLikeVC, animated: true)
    }

    func handleConfigureLikeButton(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        USER_LIKES_REF.child(currentUid).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.hasChild(postId) {
                post.didLike = true
                cell.likeButton.setImage(#imageLiteral(resourceName: "star"), for: .normal)
            } else {
                post.didLike = false
                cell.likeButton.setImage(#imageLiteral(resourceName: "star2"), for: .normal)
            }
        }
    }

    func configureCommentIndicatorView(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }

        COMMENT_REF.child(postId).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.exists() {
           //     cell.addCommentIndicatorView(toStackView: cell.stackView)
            } else {
            //    cell.commentIndicatorView.isHidden = true
            }
        }
    }

    @objc func handleShowMessages() {
        let messagesController = MessagesController()
        self.messageNotificationView.isHidden = true
        navigationController?.pushViewController(messagesController, animated: true)
    }

    func handleCommentTapped(for cell: FeedCell) {
        guard let post = cell.post else { return }
        let commentVC = CommentVC(collectionViewLayout: UICollectionViewFlowLayout())
        commentVC.post = post
        navigationController?.pushViewController(commentVC, animated: true)
    }

    // MARK: - Handlers
    @objc func handleRefresh() {
        posts.removeAll(keepingCapacity: false)
        self.currentKey = nil
        //fetchSitesSavePosts()
        fetchSitesSavePosts()
        collectionView?.reloadData()
    }

    func handleHashtagTapped(forCell cell: FeedCell) {
        cell.captionLabel.handleHashtagTap { (hashtag) in
            let hashtagController = HashtagController(collectionViewLayout: UICollectionViewFlowLayout())
            hashtagController.hashtag = hashtag.lowercased()
            self.navigationController?.pushViewController(hashtagController, animated: true)
        }
    }

    func handleMentionTapped(forCell cell: FeedCell) {
        cell.captionLabel.handleMentionTap { (username) in
            self.getMentionedUser(withUsername: username)
        }
    }

    func handleUsernameLabelTapped(forCell cell: FeedCell) {
        guard let user = cell.post?.user else { return }
        guard let username = user.username else { return }

        let customType = ActiveType.custom(pattern: "^\(username)\\b")

        cell.captionLabel.handleCustomTap(for: customType) { (_) in
            let userProfileController = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
            userProfileController.user = user
            self.navigationController?.pushViewController(userProfileController, animated: true)
        }
    }
    func fetchSitesSavePosts() {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            DispatchQueue.main.async {
                self.collectionView.refreshControl?.endRefreshing()
            }
            return
        }

        let userRef = Database.database().reference().child("users").child(currentUid)
        userRef.observeSingleEvent(of: .value) { [weak self] (userSnapshot) in
            guard let self = self else { return }
            
            if let userDict = userSnapshot.value as? [String: AnyObject] {
                self.user = User(uid: currentUid, dictionary: userDict)
            } else {
                print("Could not fetch user data")
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            // Fetch followed users
            let followingRef = Database.database().reference().child("following").child(currentUid)
            followingRef.observeSingleEvent(of: .value) { followingSnapshot in
                var followedUserIds = [String]()
                if let followingDict = followingSnapshot.value as? [String: AnyObject] {
                    followedUserIds = Array(followingDict.keys)
                }
                
                // Add the current user to the list
                followedUserIds.append(currentUid)
                
                let group = DispatchGroup()
                self.posts.removeAll()
                
                // Fetch posts for each user
                for userId in followedUserIds {
                    group.enter()
                    let postsRef = Database.database().reference().child("user_posts_sites").child(userId)
                    postsRef.observeSingleEvent(of: .value) { snapshot in
                        guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                            print("Failed to cast snapshot for user \(userId)")
                            group.leave()
                            return
                        }
                        
                        for postSnapshot in allObjects {
                            guard let postData = postSnapshot.value as? [String: AnyObject] else {
                                continue
                            }
                            let post = Post(postId: postSnapshot.key, user: self.user!, dictionary: postData)
                            self.posts.append(post)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.posts.sort { $0.creationDate > $1.creationDate }
                    print("Loaded \(self.posts.count) posts from the user and followed users")
                    self.collectionView.reloadData()
                    self.collectionView.refreshControl?.endRefreshing()
                }
            }
        }
    }
    func handleSaveTapped(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let values = [postId: 1]

        if cell.postSaved {
            // Rimuovi il post salvato
            USER_SAVED_REF.child(currentUid).child(postId).removeValue { (error, ref) in
                if let error = error {
                    print("Failed to unsave post:", error.localizedDescription)
                    return
                }
                cell.postSaved = false
                cell.savePostButton.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
            }
        } else {
            // Salva il post
            USER_SAVED_REF.child(currentUid).updateChildValues(values) { (error, ref) in
                if let error = error {
                    print("Failed to save post:", error.localizedDescription)
                    return
                }
                cell.postSaved = true
                cell.savePostButton.setImage(#imageLiteral(resourceName: "flag1"), for: .normal)
            }
        }
    }

    func configureNavigationBar() {
        if !viewSinglePost {
            self.navigationItem.title = "Feed"

            // Aggiungi il pulsante Logout nella barra di navigazione
            let logoutButton = UIBarButtonItem(
                title: "Logout",
                style: .plain,
                target: self,
                action: #selector(handleLogout)
            )
            self.navigationItem.rightBarButtonItem = logoutButton
        }
    }

    func setUnreadMessageCount() {
        if !viewSinglePost {
            getUnreadMessageCount { (unreadMessageCount) in
                guard unreadMessageCount != 0 else { return }
                self.navigationController?.navigationBar.addSubview(self.messageNotificationView)
                self.messageNotificationView.anchor(top: self.navigationController?.navigationBar.topAnchor, left: nil, bottom: nil, right: self.navigationController?.navigationBar.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 4, width: 20, height: 20)
                self.messageNotificationView.layer.cornerRadius = 20 / 2
                self.messageNotificationView.notificationLabel.text = "\(unreadMessageCount)"
            }
        }
    }
    @objc func handleLogout() {
        let alertController = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out?",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { _ in
            do {
                try Auth.auth().signOut()

                let loginVC = LoginVC()
                let navController = UINavigationController(rootViewController: loginVC)

                // Modalità presentazione a schermo intero per iOS 13+
                navController.modalPresentationStyle = .fullScreen

                self.present(navController, animated: true, completion: nil)
            } catch {
                print("Failed to sign out: \(error.localizedDescription)")
            }
        }))

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        present(alertController, animated: true, completion: nil)
    }
    

    // MARK: - API
    func setUserFCMToken() {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        guard let fcmToken = Messaging.messaging().fcmToken else { return }

        let values = ["fcmToken": fcmToken]

        USER_REF.child(currentUid).updateChildValues(values)
    }
    
    
    
   
    func fetchPost(withPostId postId: String) {
        Database.fetchPost(with: postId) { post in
            self.posts.append(post)
            self.posts.sort { $0.creationDate > $1.creationDate }
            self.collectionView.reloadData()
        }
    }

    func getUnreadMessageCount(withCompletion completion: @escaping(Int) -> ()) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        var unreadCount = 0

        USER_MESSAGES_REF.child(currentUid).observe(.childAdded) { (snapshot) in
            let uid = snapshot.key

            USER_MESSAGES_REF.child(currentUid).child(uid).observe(.childAdded, with: { (snapshot) in
                let messageId = snapshot.key

                MESSAGES_REF.child(messageId).observeSingleEvent(of: .value) { (snapshot) in
                    guard let dictionary = snapshot.value as? Dictionary<String, AnyObject> else { return }

                    let message = Message(dictionary: dictionary)

                    completion(unreadCount)
                }
            })
        }
    }
    func handleFlagToLike(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let flagsRef = Database.database().reference().child("post-flags").child(postId)

        // Controlla se il flag è già presente
        flagsRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                // Rimuovi il flag
                flagsRef.child(currentUid).removeValue { error, _ in
                    if let error = error {
                        print("Failed to remove flag: \(error.localizedDescription)")
                        return
                    }
                    print("Flag removed from post-flags")
                    DispatchQueue.main.async {
                        cell.savePostButton.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
                    }
                }
            } else {
                // Aggiungi il flag
                flagsRef.child(currentUid).setValue(1) { error, _ in
                    if let error = error {
                        print("Failed to add flag: \(error.localizedDescription)")
                        return
                    }
                    print("Flag added to post-flags")
                    DispatchQueue.main.async {
                        cell.savePostButton.setImage(#imageLiteral(resourceName: "flag1"), for: .normal)
                    }
                }
            }
        }
    }
    func configureLikeAndFlagButtons(for cell: FeedCell) {
        guard let post = cell.post else { return }
        guard let postId = post.postId else { return }
        guard let currentUid = Auth.auth().currentUser?.uid else { return }

        let likesRef = Database.database().reference().child("post-likes").child(postId)
        let flagsRef = Database.database().reference().child("post-flags").child(postId)

        // Controlla lo stato del like
        likesRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if snapshot.exists() {
                    cell.likeButton.setImage(#imageLiteral(resourceName: "star2"), for: .normal)
                } else {
                    cell.likeButton.setImage(#imageLiteral(resourceName: "star"), for: .normal)
                }
            }
        }

        // Controlla lo stato del flag
        flagsRef.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if snapshot.exists() {
                    cell.savePostButton.setImage(#imageLiteral(resourceName: "flag1"), for: .normal)
                } else {
                    cell.savePostButton.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
                }
            }
        }
    }
}
