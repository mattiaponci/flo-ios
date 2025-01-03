//
//  FollowLikeVC.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import UIKit
import Firebase

private let reuseIdentifier = "FollowCell"

class FollowLikeVC: UITableViewController {

    // MARK: - Properties
    
    var followCurrentKey: String?
    var likeCurrentKey: String?
    var users = [User]()
    
    enum ViewingMode: Int {
        case Following
        case Followers
        case Likes
        
        init(index: Int) {
            switch index {
            case 0: self = .Following
            case 1: self = .Followers
            case 2: self = .Likes
            default: self = .Following
            }
        }
    }

    var viewingMode: ViewingMode!
    var uid: String?
    var postId: String?

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureNavigationTitle()
        fetchUsers()
    }

    // MARK: - Configuration
    
    private func configureTableView() {
        tableView.register(FollowLikeCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
    }
    
    private func configureNavigationTitle() {
        guard let viewingMode = viewingMode else { return }
        switch viewingMode {
        case .Followers:
            navigationItem.title = "Followers"
        case .Following:
            navigationItem.title = "Following"
        case .Likes:
            navigationItem.title = "Likes"
        }
    }

    // MARK: - TableView DataSource & Delegate
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return users.count
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! FollowLikeCell
        cell.user = users[indexPath.row]
        cell.backgroundColor = .white // Sfondo bianco per ogni cella

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedUser = users[indexPath.row]
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = selectedUser
        userProfileVC.isFromFollowLikeVC = true

        navigationController?.pushViewController(userProfileVC, animated: true)
    }
    
    // MARK: - API
    
    private func fetchUsers() {
        guard let ref = getDatabaseReference() else { return }
        guard let viewingMode = viewingMode else { return }
        
        switch viewingMode {
        case .Followers, .Following:
            guard let uid = self.uid else { return }
            fetchFollowData(ref: ref, uid: uid)
        case .Likes:
            guard let postId = self.postId else { return }
            fetchLikeData(ref: ref, postId: postId)
        }
    }
    
    private func getDatabaseReference() -> DatabaseReference? {
        switch viewingMode {
        case .Followers:
            return Database.database().reference().child("followers")
        case .Following:
            return Database.database().reference().child("following")
        case .Likes:
            return Database.database().reference().child("post-likes")
        default:
            return nil
        }
    }

    private func fetchFollowData(ref: DatabaseReference, uid: String) {
        if followCurrentKey == nil {
            ref.child(uid).queryLimited(toLast: 4).observeSingleEvent(of: .value) { snapshot in
                self.processFollowSnapshot(snapshot)
            }
        } else {
            ref.child(uid).queryOrderedByKey().queryEnding(atValue: followCurrentKey).queryLimited(toLast: 5).observeSingleEvent(of: .value) { snapshot in
                self.processFollowSnapshot(snapshot)
            }
        }
    }
    
    private func fetchLikeData(ref: DatabaseReference, postId: String) {
        if likeCurrentKey == nil {
            ref.child(postId).queryLimited(toLast: 4).observeSingleEvent(of: .value) { snapshot in
                self.processLikeSnapshot(snapshot)
            }
        } else {
            ref.child(postId).queryOrderedByKey().queryEnding(atValue: likeCurrentKey).queryLimited(toLast: 5).observeSingleEvent(of: .value) { snapshot in
                self.processLikeSnapshot(snapshot)
            }
        }
    }
    
    private func processFollowSnapshot(_ snapshot: DataSnapshot) {
        guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
        if followCurrentKey == nil {
            followCurrentKey = allObjects.first?.key
        }
        allObjects.forEach { snapshot in
            let followUid = snapshot.key
            fetchUser(withUid: followUid)
        }
    }
    
    private func processLikeSnapshot(_ snapshot: DataSnapshot) {
        guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }
        if likeCurrentKey == nil {
            likeCurrentKey = allObjects.first?.key
        }
        allObjects.forEach { snapshot in
            let likeUid = snapshot.key
            fetchUser(withUid: likeUid)
        }
    }
    
    private func fetchUser(withUid uid: String) {
        Database.fetchUser(with: uid) { user in
            self.users.append(user)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
}
