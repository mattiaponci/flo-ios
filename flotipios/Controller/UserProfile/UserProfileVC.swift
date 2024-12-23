//
//  UserProfileVC.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

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
    func handleEditFollowTapped(for header: UserProfileHeader) {
        print("")
    }
    
    func handleImageclicked(url: URL) {
        print("")

    }
    
    func handleLikeTapped(for cell: UserPostCell, isDoubleTap: Bool) {
        print("")

    }
    

    // MARK: - Properties
    private let reuseIdentifier = "Cell"
    private let headerIdentifier = "UserProfileHeader"
    
    weak var delegate: UserVCDelegate?
    
    var user: User?
    var posts = [Post]()
    var viewSinglePost = false
    var post: Post?
    var currentKey: String?
    var userProfileController: UserProfileVC?
    var isFlagged: Bool = false
    var postSaved: Bool = false

    // MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()

        // Hide the navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Register the cell and header classes
        self.collectionView!.register(UserPostCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        self.collectionView!.register(UserProfileHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: headerIdentifier)
        
        configureRefreshControl()
        self.collectionView?.backgroundColor = .white
        
        // Fetch user data
        fetchCurrentUserData()
        fetchSitesSavePosts()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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
            fetchSitesSavePosts()
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: headerIdentifier, for: indexPath) as! UserProfileHeader
        header.delegate = self
        header.user = self.user
        return header
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! UserPostCell
        cell.post = posts[indexPath.item]
        cell.delegate = self
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let feedVC = FeedVC(collectionViewLayout: UICollectionViewFlowLayout())
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

    func setUserStats(for header: UserProfileHeader) {
        guard let uid = header.user?.uid else { return }

        // Fetch followers count
        USER_FOLLOWER_REF.child(uid).observe(.value) { snapshot in
            let followersCount = snapshot.childrenCount
            header.followersLabel.attributedText = self.formatStat(count: followersCount, label: "followers")
        }

        // Fetch following count
        USER_FOLLOWING_REF.child(uid).observe(.value) { snapshot in
            let followingCount = snapshot.childrenCount
            header.followingLabel.attributedText = self.formatStat(count: followingCount, label: "following")
        }

        // Fetch saved sites count
        USER_SAVED_SITES_REF.child(uid).observeSingleEvent(of: .value) { snapshot in
            let savedSitesCount = snapshot.childrenCount
            header.savedSitesLabel.attributedText = self.formatStat(count: savedSitesCount, label: "saved sites")
        }
    }

    private func formatStat(count: UInt, label: String) -> NSAttributedString {
        let statText = NSMutableAttributedString(
            string: "\(count)\n",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
        )
        statText.append(NSAttributedString(
            string: label,
            attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.lightGray]
        ))
        return statText
    }

    // MARK: - Handlers

    @objc func handleRefresh() {
        posts.removeAll(keepingCapacity: false)
        currentKey = nil
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

        let uid = self.user?.uid ?? currentUser.uid
        let query: DatabaseQuery
        if currentKey == nil {
            query = USER_POSTS_REF.child(uid).queryLimited(toLast: 10)
        } else {
            query = USER_POSTS_REF.child(uid).queryOrderedByKey().queryEnding(atValue: currentKey).queryLimited(toLast: 7)
        }

        query.observeSingleEvent(of: .value) { snapshot in
            self.collectionView?.refreshControl?.endRefreshing()
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            for snapshot in allObjects {
                self.fetchPost(withPostId: snapshot.key)
            }
            if let first = allObjects.first {
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
            let user = User(uid: currentUid, dictionary: dictionary)
            self.user = user
            self.collectionView?.reloadData()
        }
    }

    func fetchSitesSavePosts() {
        guard let uid = self.user?.uid ?? Auth.auth().currentUser?.uid else { return }

        let query: DatabaseQuery
        if currentKey == nil {
            query = USER_SAVED_SITES_REF.child(uid).queryLimited(toLast: 10)
        } else {
            query = USER_SAVED_SITES_REF.child(uid).queryOrderedByKey().queryEnding(atValue: currentKey).queryLimited(toLast: 7)
        }

        query.observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
            for snapshot in allObjects {
                self.fetchPost(withPostId: snapshot.key)
            }
            if let first = allObjects.first {
                self.currentKey = first.key
            }
        }
    }

    func handleCommentTapped(for cell: UserPostCell) {
        guard let post = cell.post else { return }
        let commentVC = CommentVC(collectionViewLayout: UICollectionViewFlowLayout())
        commentVC.post = post
        navigationController?.pushViewController(commentVC, animated: true)
    }
}
