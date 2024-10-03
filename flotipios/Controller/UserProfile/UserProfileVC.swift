//
//  UserProfileVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit
import Firebase
import ActiveLabel


private let reuseIdentifier = "Cell"
private let headerIdentifier = "UserProfileHeader"

protocol UserVCDelegate: AnyObject {
    func didSelectWebsiteInUser(url: URL)
}

class UserProfileVC: UICollectionViewController, UICollectionViewDelegateFlowLayout, UserProfileHeaderDelegate, UserCellDelegate {
    
    // MARK: - Properties
    weak var delegate: UserVCDelegate?
    

    var user: User?
    var posts = [Post]()
    var currentKey: String?
    
    // MARK: - Init
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // register cell classes
        self.collectionView!.register(UserPostCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView!.register(UserProfileHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)
        
        // configure refresh control
        configureRefreshControl()
        
        // background color
        self.collectionView?.backgroundColor = .white

        // fetch user data
        if self.user == nil {
            fetchCurrentUserData()
        }
        
        // fetch posts
        fetchSitesSavePosts()

        // Configura il pulsante delle impostazioni nella barra di navigazione
        let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gearshape.fill"), style: .plain, target: self, action: #selector(handleSettingsTapped))
        navigationItem.rightBarButtonItem = settingsButton
    }
    
    // MARK: - Configurazione della barra di navigazione
      
    @objc func handleSettingsTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }

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
            fetchPosts()
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
    
 /*   override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedVC = FeedVC(collectionViewLayout: UICollectionViewFlowLayout())
        feedVC.viewSinglePost = true
        feedVC.userProfileController = self
        feedVC.post = posts[indexPath.item]
        navigationController?.pushViewController(feedVC, animated: true)
    }*/
    
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
        
        USER_FOLLOWER_REF.child(uid).observe(.value) { snapshot in
            let numberOfFollowers = snapshot.value as? Int ?? 0
            let attributedText = NSMutableAttributedString(string: "\(numberOfFollowers)\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
            attributedText.append(NSAttributedString(string: "followers", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]))
            header.followersLabel.attributedText = attributedText
        }
        
        USER_FOLLOWING_REF.child(uid).observe(.value) { snapshot in
            let numberOfFollowing = snapshot.value as? Int ?? 0
            let attributedText = NSMutableAttributedString(string: "\(numberOfFollowing)\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
            attributedText.append(NSAttributedString(string: "following", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]))
            header.followingLabel.attributedText = attributedText
        }
        
        USER_POSTS_REF.child(uid).observeSingleEvent(of: .value) { snapshot in
            let postCount = snapshot.childrenCount
            let attributedText = NSMutableAttributedString(string: "\(postCount)\n", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14)])
            attributedText.append(NSAttributedString(string: "posts", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray]))
            header.postsLabel.attributedText = attributedText
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
        var uid: String!
        
        if let user = self.user {
            uid = user.uid
        } else {
            uid = Auth.auth().currentUser?.uid
        }
        
        if currentKey == nil {
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
    
    func fetchPost(withPostId postId: String) {
        Database.fetchPost(with: postId) { post in
            self.posts.append(post)
            self.posts.sort { $0.creationDate > $1.creationDate }
            self.collectionView?.reloadData()
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
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        USER_SAVED_SITES_REF.child(currentUid).observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            self.posts.removeAll()
            allObjects.forEach { snapshot in
                let postId = snapshot.key
                self.fetchPost(withPostId: postId) { post in
                    self.posts.append(post)
                    self.posts.sort { $0.creationDate > $1.creationDate }
                    DispatchQueue.main.async {
                        self.collectionView?.reloadData()
                        self.collectionView?.refreshControl?.endRefreshing()
                    }
                }
            }
        }
    }
    
    func fetchPost(withPostId postId: String, completion: @escaping (Post) -> Void) {
        Database.fetchPost(with: postId) { post in
            completion(post)
        }
    }
}
