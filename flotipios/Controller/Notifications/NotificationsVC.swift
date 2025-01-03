import UIKit
import Firebase
import Foundation // Serve solo come esempio, se non usi nulla di Foundation potresti non importarlo.

// MARK: - NotificationsVC

private let reuseIdentifier = "NotificationCell"

class NotificationsVC: UITableViewController, NotificationCellDelegate {
    func handleFollowTapped(for cell: NotificationCell) {
        print("hello follow")
    }
    
    func handlePostTapped(for cell: NotificationCell) {
        print("hello follow")

    }
    
    
    // MARK: - Properties
    
    var followNotifications = [(username: String, userId: String)]()
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    var observedFollowedUsers = Set<String>()
    private let refresher = UIRefreshControl()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        fetchFollowNotifications()
    }
    
    // MARK: - UI Configuration
    
    private func configureUI() {
        tableView.backgroundColor = .white
        tableView.separatorColor = .clear
        self.edgesForExtendedLayout = []
        
        tableView.register(NotificationCell.self, forCellReuseIdentifier: reuseIdentifier)
        self.navigationController?.navigationBar.isHidden = true
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 0, right: 0)

        refresher.tintColor = .gray
        refresher.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refresher
    }
    
    // MARK: - UITableViewDataSource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return followNotifications.count
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("cellForRowAt called for row: \(indexPath.row)")
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier,
                                                 for: indexPath) as! NotificationCell
        let notification = followNotifications[indexPath.row]
        
        cell.configure(with: notification)
        cell.delegate = self  // Imposta il delegate
        print("Delegate assigned to cell for userId: \(notification.userId)")
        
        return cell
    }
    
    // MARK: - UITableViewDelegate (Header)

    override func tableView(_ tableView: UITableView,
                            viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .white
        
        let label = UILabel()
        label.text = "Notifications"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            label.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20)
        ])
        
        return headerView
    }
    
    override func tableView(_ tableView: UITableView,
                            heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    // MARK: - Firebase Listener
    
    func fetchFollowNotifications() {
        guard let currentUid = currentUserId else { return }
        let followingRef = Database.database().reference().child("following").child(currentUid)
        
        followingRef.observe(.childAdded) { [weak self] snapshot in
            guard let self = self else { return }
            let followedUserId = snapshot.key
            
            if self.observedFollowedUsers.contains(followedUserId) { return }
            self.observedFollowedUsers.insert(followedUserId)
            
            Database.database().reference().child("users").child(followedUserId).observeSingleEvent(of: .value) { userSnapshot in
                guard let userDict = userSnapshot.value as? [String: AnyObject],
                      let username = userDict["username"] as? String else { return }
                
                self.followNotifications.append((username: username, userId: followedUserId))
                DispatchQueue.main.async {
                    print("Reloading tableView with \(self.followNotifications.count) notifications")
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    @objc func handleRefresh() {
        followNotifications.removeAll()
        observedFollowedUsers.removeAll()
        tableView.reloadData()
        fetchFollowNotifications()
        refresher.endRefreshing()
    }
    
    // MARK: - NotificationCellDelegate
    
    func didTapUsername(username userId: String) {
            print("Delegate method called for userId: \(userId)")
            
            // Fetch user details from Firebase
            Database.database().reference().child("users").child(userId).observeSingleEvent(of: .value) { snapshot in
                guard let userDict = snapshot.value as? [String: AnyObject] else {
                    print("Failed to fetch user data for userId: \(userId)")
                    return
                }
                
                let user = User(uid: userId, dictionary: userDict)
                
                // Fetch posts for the user
                Database.database().reference().child("user_posts_sites").child(userId).observeSingleEvent(of: .value) { postSnapshot in
                    var posts: [Post] = []
                    
                    if let allObjects = postSnapshot.children.allObjects as? [DataSnapshot] {
                        for snapshot in allObjects {
                            guard let postData = snapshot.value as? [String: AnyObject] else { continue }
                            let post = Post(postId: snapshot.key, user: user, dictionary: postData)
                            posts.append(post)
                        }
                    }
                    
                    // Navigate to UserProfileVC
                    DispatchQueue.main.async {
                        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
                        userProfileVC.user = user
                        userProfileVC.posts = posts
                        userProfileVC.isFromFeed = false
                        userProfileVC.isFromSearch = false
                        self.navigationController?.pushViewController(userProfileVC, animated: true)
                    }
                }
            }
        }
    
    
    // Esempio di altre funzioni (se le usavi):
    
}

// MARK: - NotificationCell

