import UIKit
import Firebase
import SDWebImage
import AudioToolbox
import FirebaseFunctions
import Alamofire
import FirebaseAuth
import FirebaseStorage

private let reuseIdentifier = "SearchUserCell"

class SearchVC: UIViewController,
                UITableViewDelegate,
                UITableViewDataSource,
                UISearchBarDelegate,
                UICollectionViewDelegate,
                UICollectionViewDataSource,
                UICollectionViewDelegateFlowLayout,
                FeedCellDelegate {

    // MARK: - Proprietà
    
    weak var delegate: NotificationsVC?
    
    var user: User?
    var users = [User]()
    var filteredUsers = [User]()
    var userPostsSites = [Post]()
    
    var inSearchMode = false
    var currentKey: String?
    var isFetching = false
    
    // Search bar
    var searchBar = UISearchBar()

    // MARK: - Elementi UI
    
    /// TableView per i risultati di ricerca (inizialmente hidden)
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .white
        tv.delegate = self
        tv.dataSource = self
        tv.register(SearchUserCell.self, forCellReuseIdentifier: reuseIdentifier)
        tv.separatorStyle = .none
        // Parte nascosta
        tv.isHidden = true
        return tv
    }()
    
    /// CollectionView a tutto schermo (visibile quando non cerchiamo)
    lazy var fullCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 90, height: 200)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .lightGray
        cv.delegate = self
        cv.dataSource = self
        cv.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
        return cv
    }()
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // 1) Configuriamo la searchBar
        configureSearchBar()
        
        // 2) Navigation Bar
        configureNavigationBar()
        
        // 3) Aggiungiamo subview e configuriamo constraint
        // A) CollectionView (occupa tutto lo schermo di default)
        // B) TableView (anch’essa a tutto schermo, ma nascosta di default)
        view.addSubview(fullCollectionView)
        view.addSubview(tableView)
        
        fullCollectionView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // CollectionView a tutto schermo
            fullCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            fullCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fullCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fullCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // TableView sopra la collection (stessa posizione e dimensioni),
            // così quando è isHidden=false, copre la collection
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // 4) Configuriamo il refreshControl per la collectionView
        configureRefreshControl()
        fullCollectionView.refreshControl = refreshControl
        
        // 5) Se l’utente è loggato
        if let user = Auth.auth().currentUser {
            print("User authenticated with UID: \(user.uid)")
        } else {
            print("No user authenticated.")
        }
        
        // 6) Fetch utente, poi post
        fetchCurrentUserData {
            self.fetchSitesSavePosts()
        }
    }
    
    // MARK: - fetchCurrentUserData
    
    func fetchCurrentUserData(completion: @escaping () -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            return
        }
        
        let ref = Database.database().reference().child("users").child(currentUid)
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else {
                print("Failed to fetch user data")
                return
            }
            self.user = User(uid: currentUid, dictionary: dictionary)
            print("User data fetched: \(self.user?.username ?? "No Username")")
            
            completion()
        }
    }
    
    // MARK: - fetchSitesSavePosts
    
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
        
        let ref = Database.database().reference()
            .child("user_posts_sites")
            .child(currentUid)
        
        ref.observeSingleEvent(of: .value) { snapshot in
            print("Snapshot received: \(snapshot)")
            
            guard snapshot.exists() else {
                print("No saved post sites found for user")
                self.fullCollectionView.refreshControl?.endRefreshing()
                return
            }
            
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                print("Failed to cast snapshot to DataSnapshot")
                self.fullCollectionView.refreshControl?.endRefreshing()
                return
            }
            
            self.userPostsSites.removeAll()
            
            allObjects.forEach { snap in
                let postId = snap.key
                print("Fetching post site with ID: \(postId)")
                
                if let postData = snap.value as? [String: AnyObject] {
                    let post = Post(postId: postId, user: currentUser, dictionary: postData)
                    self.userPostsSites.append(post)
                } else {
                    print("Snapshot does not contain valid data for post ID: \(snap.key)")
                }
            }
            
            // Ordiniamo i post per data di creazione
            self.userPostsSites.sort { $0.creationDate > $1.creationDate }
            
            DispatchQueue.main.async {
                print("Reloading fullCollectionView with \(self.userPostsSites.count) post sites")
                self.fullCollectionView.reloadData()
                self.fullCollectionView.refreshControl?.endRefreshing()
            }
        } withCancel: { error in
            print("Failed to fetch user posts sites: \(error.localizedDescription)")
            self.fullCollectionView.refreshControl?.endRefreshing()
        }
    }
    
    // MARK: - Refresh Control
    
    @objc func handleRefresh() {
        userPostsSites.removeAll()
        currentKey = nil
        fetchSitesSavePosts()
    }
    
    var refreshControl: UIRefreshControl?
    
    func configureRefreshControl() {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl = rc
    }
    
    // MARK: - TableView DataSource / Delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    /// Se non siamo in searchMode, mostra `users` (oppure puoi decidere di mostrare tutti gli utenti, dipende dalla tua logica)
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        
        return inSearchMode ? filteredUsers.count : 0
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? SearchUserCell else {
            return UITableViewCell()
        }
        
        let user = filteredUsers[indexPath.row]  // in searchMode
        cell.user = user
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        
        let user = filteredUsers[indexPath.row]
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = user
        navigationController?.pushViewController(userProfileVC, animated: true)
    }
    
    // MARK: - CollectionView DataSource / Delegate
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        // Se non cerchiamo, mostriamo userPostsSites
        // Se cerchiamo, non mostriamo nulla (0)
        return inSearchMode ? 0 : userPostsSites.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell {
        
        guard indexPath.item < userPostsSites.count else {
            fatalError("Index out of range for userPostsSites")
        }
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "FeedCell",
            for: indexPath
        ) as? FeedCell else {
            fatalError("Failed to dequeue FeedCell")
        }
        
        let post = userPostsSites[indexPath.item]
        cell.delegate = self
        cell.post = post
        
        // Caricamento immagine
        if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
            cell.postImageView.sd_setImage(with: url) { [weak cell] _, _, _, _ in
                DispatchQueue.main.async {
                    cell?.setNeedsLayout()
                }
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
        guard indexPath.item < userPostsSites.count else {
            print("Index out of range for userPostsSites in didSelectItemAt")
            return
        }
        
        let post = userPostsSites[indexPath.item]
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            handleImageTapped(url: postUrl)
        }
    }
    
    // Spaziatura item
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 10
    }
    
    // MARK: - FeedCellDelegate
    
    func handleUsernameTapped(for cell: FeedCell) {
        print("Username tapped!")
    }
    
    func handleOptionsTapped(for cell: FeedCell) {
        print("Options tapped!")
    }
    
    func handleLikeTapped(for cell: FeedCell, isDoubleTap: Bool) {
        print("Like tapped!")
    }
    
    func handleCommentTapped(for cell: FeedCell) {
        print("Comment tapped!")
    }
    
    func handleConfigureLikeButton(for cell: FeedCell) {
        print("Configure Like Button tapped!")
    }
    
    func handleShowLikes(for cell: FeedCell) {
        print("Show Likes tapped!")
    }
    
    func configureCommentIndicatorView(for cell: FeedCell) {
        print("Configure Comment Indicator View tapped!")
    }
    
    func handleSaveTapped(for cell: FeedCell) {
        print("Save tapped!")
    }
    
    func handleImageTapped(url: URL) {
        print("Image tapped! URL: \(url)")
    }
    
    // MARK: - SearchBar
    
    func configureSearchBar() {
        searchBar.sizeToFit()
        searchBar.delegate = self
        searchBar.barTintColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1)
        searchBar.tintColor = .black
        searchBar.searchTextField.backgroundColor = .gray
        searchBar.showsCancelButton = true
        navigationItem.titleView = searchBar
    }
    
    // Quando il testo cambia: se è vuoto => esci dalla search mode
    // altrimenti => entra in search mode
    func searchBar(_ searchBar: UISearchBar,
                   textDidChange searchText: String) {
        
        if searchText.isEmpty || searchText == " " {
            // Non stiamo cercando
            inSearchMode = false
            
            // Mostra la collection
            fullCollectionView.isHidden = false
            
            // Nascondi la table
            tableView.isHidden = true
            
            // Ricarica
            tableView.reloadData()
            fullCollectionView.reloadData()
        } else {
            // Stiamo cercando
            inSearchMode = true
            
            // Nascondi la collection
            fullCollectionView.isHidden = true
            
            // Mostra la table
            tableView.isHidden = false
            
            // Carica i risultati di ricerca
            searchUsers(withUsername: searchText.lowercased())
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // L’utente ha toccato “Cancel”
        searchBar.endEditing(true)
        searchBar.text = nil
        inSearchMode = false
        
        // Mostra la collection
        fullCollectionView.isHidden = false
        
        // Nascondi la table
        tableView.isHidden = true
        
        // Ricarica
        tableView.reloadData()
        fullCollectionView.reloadData()
    }
    
    // MARK: - Ricerca Utenti
    
    func searchUsers(withUsername username: String) {
        self.filteredUsers = []
        
        let query = USER_REF
            .queryOrdered(byChild: "username")
            .queryStarting(atValue: username)
            .queryEnding(atValue: username + "\u{f8ff}")
            .queryLimited(toLast: 10)
        
        query.observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                self.filteredUsers = []
                self.tableView.reloadData()
                return
            }
            
            allObjects.forEach { snap in
                let uid = snap.key
                Database.fetchUser(with: uid) { fetchedUser in
                    if !self.filteredUsers.contains(where: { $0.uid == fetchedUser.uid }) {
                        self.filteredUsers.append(fetchedUser)
                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    // MARK: - NavigationBar
    
    func configureNavigationBar() {
        // Se user non c’è ancora, non facciamo nulla
        guard let currentUid = Auth.auth().currentUser?.uid,
              let user = self.user else { return }
        
        // Se l’utente corrente coincide con self.user, mostra il bottone impostazioni
        if currentUid == user.uid {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "gearshape.fill"),
                style: .plain,
                target: self,
                action: #selector(handleSettingsTapped)
            )
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    @objc func handleSettingsTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }
}
