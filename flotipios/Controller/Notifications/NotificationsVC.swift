import UIKit
import Firebase

class NotificationsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, NotificationCellDelegate {
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
            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2), // Margine di 2 punti dal bordo superiore sicuro
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10), // Allineamento a sinistra con margine
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor), // Opzionale
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
        return followNotifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! NotificationCell
        let notification = followNotifications[indexPath.row]
        cell.configure(with: notification)
        cell.delegate = self
        return cell
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
                    userProfileVC.isFromFollowLikeVC = true // Indica che proviene dalle notifiche
                    self.navigationController?.pushViewController(userProfileVC, animated: true)
                }
            }
        }
    }
}
