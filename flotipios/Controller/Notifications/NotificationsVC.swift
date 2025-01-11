import UIKit
import Firebase

enum NotificationType {
    case follow
    case newPost
}

struct NotificationModel {
    let type: NotificationType
    let username: String?
    let userId: String?
    let postImageUrl: String?
    let postId: String? // Aggiunta della proprietà postId
    let creationDate: Date
}

class NotificationsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, NotificationCellDelegate {
    
    var userProfileController: UserProfileVC?

    
    func didTapCell(for notification: NotificationModel) {
           guard let username = notification.username else { return }
           navigateToUserProfile(username: username, postId: notification.postId)
       }
       
       private func navigateToUserProfile(username: String, postId: String?) {
           let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
           
           let profileVC = userProfileVC
           profileVC.username = username
           profileVC.selectedPostId = postId // Passa l'identificatore del post
           navigationController?.pushViewController(profileVC, animated: true)
       }
    
    func handleFollowTapped(for cell: NotificationCell) {
        print("hello")
    }
    
    func handlePostTapped(for cell: NotificationCell) {
        print("hello")
        
    }
    
    
    // MARK: - Properties
    
    private let reuseIdentifier = "NotificationCell"
    private let tableView = UITableView()
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Notifications"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.textAlignment = .left
        return label
    }()
    
    var notifications: [NotificationModel] = []
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    private let refresher = UIRefreshControl()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        fetchFollowNotifications()
        //  fetchPostNotifications()
        fetchFollowedUserPosts()
        
        view.backgroundColor = .white
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    // MARK: - UI Configuration
    
    private func configureUI() {
        // Rimuove la navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .white
        
        // Header Label
        view.addSubview(headerLabel)
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Table View
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NotificationCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.separatorColor = .clear
        
        // Refresh control
        refresher.tintColor = .gray
        refresher.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refresher
    }
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! NotificationCell
        let notification = notifications[indexPath.row]
        cell.configure(with: notification)
        cell.delegate = self
        return cell
    }
    
    // MARK: - Firebase Listeners
    
    func fetchFollowNotifications() {
        guard let currentUid = currentUserId else { return }
        let followingRef = Database.database().reference().child("following").child(currentUid)
        
        followingRef.observe(.childAdded) { [weak self] snapshot in
            guard let self = self else { return }
            let followedUserId = snapshot.key
            
            Database.database().reference().child("users").child(followedUserId).observeSingleEvent(of: .value) { userSnapshot in
                guard let userDict = userSnapshot.value as? [String: AnyObject],
                      let username = userDict["username"] as? String else { return }
                
                let notification = NotificationModel(
                    type: .follow,
                    username: username,
                    userId: followedUserId,
                    postImageUrl: nil,
                    postId: nil, // Nessun postId per follow
                    creationDate: Date()
                )
                self.notifications.append(notification)
                self.notifications.sort(by: { $0.creationDate > $1.creationDate })
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func fetchPostNotifications() {
        guard let currentUid = currentUserId else { return }
        let postsRef = Database.database().reference().child("user_posts_sites").child(currentUid)
        
        postsRef.observe(.childAdded) { [weak self] snapshot in
            guard let self = self else { return }
            guard let postDict = snapshot.value as? [String: AnyObject],
                  let creationDate = postDict["creationDate"] as? Double,
                  let imageUrl = postDict["imageUrl"] as? String else { return }
            
            let postId = snapshot.key // Ottieni il postId dal nodo corrente
            
            let notification = NotificationModel(
                type: .newPost,
                username: nil,
                userId: currentUid,
                postImageUrl: imageUrl,
                postId: postId, // Passa il postId
                creationDate: Date(timeIntervalSince1970: creationDate)
            )
            self.notifications.append(notification)
            self.notifications.sort(by: { $0.creationDate > $1.creationDate })
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    @objc func handleRefresh() {
        notifications.removeAll()
        tableView.reloadData()
        fetchFollowNotifications()
        //    fetchPostNotifications()
        fetchFollowedUserPosts()
        
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
                    userProfileVC.isFromFollowLikeVC = true
                    self.navigationController?.pushViewController(userProfileVC, animated: true)
                }
            }
        }
    }
    
    func fetchFollowedUserPosts() {
        guard let currentUid = currentUserId else { return }
        let followingRef = Database.database().reference().child("following").child(currentUid)
        
        // Recupera le persone seguite
        followingRef.observeSingleEvent(of: .value) { [weak self] snapshot in
            guard let self = self, let followingDict = snapshot.value as? [String: Any] else { return }
            let followedUserIds = Array(followingDict.keys)
            
            for userId in followedUserIds {
                // Recupera i post di ogni utente seguito
                let userPostsRef = Database.database().reference().child("user_posts_sites").child(userId)
                
                userPostsRef.observeSingleEvent(of: .value) { postSnapshot in
                    guard let postsDict = postSnapshot.value as? [String: AnyObject] else { return }
                    
                    for (postId, postData) in postsDict {
                        guard let postDict = postData as? [String: AnyObject],
                              let creationDate = postDict["creationDate"] as? Double,
                              let imageUrl = postDict["imageUrl"] as? String else { continue }
                        
                        // Recupera il nome utente
                        Database.database().reference().child("users").child(userId).observeSingleEvent(of: .value) { userSnapshot in
                            guard let userDict = userSnapshot.value as? [String: AnyObject],
                                  let username = userDict["username"] as? String else { return }
                            
                            // Crea la notifica
                            let notification = NotificationModel(
                                type: .newPost,
                                username: username,
                                userId: userId,
                                postImageUrl: imageUrl,
                                postId: postId, // Aggiunto il postId
                                creationDate: Date(timeIntervalSince1970: creationDate)
                            )
                            self.notifications.append(notification)
                            self.notifications.sort(by: { $0.creationDate > $1.creationDate })
                            
                            DispatchQueue.main.async {
                                self.tableView.reloadData()
                            }
                        }
                    }
                }
            }
        }
    }

}
