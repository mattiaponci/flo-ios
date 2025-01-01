import UIKit
import Firebase
import SDWebImage
import AudioToolbox
import FirebaseFunctions
import Alamofire  // se vuoi usarlo, altrimenti URLSession
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
    func handleFlagToLike(for cell: FeedCell) {
        print("")

    }
    

    // MARK: - Proprietà
    
    weak var delegate: NotificationsVC?
    
    var user: User?
    var users = [User]()
    var filteredUsers = [User]()

    // Questo array conterrà solo 1 post alla volta
    var userPostsSites = [Post]()
    
    var inSearchMode = false
    var currentKey: String?
    var isFetching = false
    
    // Search bar
    var searchBar = UISearchBar()
    var isSearching: Bool = false

    // MARK: - Elementi UI
    
    /// TableView per i risultati di ricerca (inizialmente nascosta)
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .white
        tv.delegate = self
        tv.dataSource = self
        tv.register(SearchUserCell.self, forCellReuseIdentifier: reuseIdentifier)
        tv.separatorStyle = .none
        tv.isHidden = true
        return tv
    }()
    
    /// CollectionView a tutto schermo (per mostrare il singolo post)
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
    lazy var noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "Nessun risultato trovato"
        label.textAlignment = .center
        label.textColor = .gray
        label.isHidden = true // Nascondi inizialmente
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
          view.addSubview(fullCollectionView)
          view.addSubview(tableView)
          view.addSubview(noResultsLabel) // Aggiungi la noResultsLabel alla vista principale
          
          fullCollectionView.translatesAutoresizingMaskIntoConstraints = false
          tableView.translatesAutoresizingMaskIntoConstraints = false
          
          NSLayoutConstraint.activate([
              // CollectionView a tutto schermo
              fullCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              fullCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              fullCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              fullCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
              
              // TableView sopra la collection (stessa posizione e dimensioni)
              tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
              tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
              tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
              tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
              
            
          ])
          
          // 4) Configuriamo il refreshControl per la collectionView
          configureRefreshControl()
          fullCollectionView.refreshControl = refreshControl
          
          // 5) Controllo utente loggato
          if let user = Auth.auth().currentUser {
              print("User authenticated with UID: \(user.uid)")
          } else {
              print("No user authenticated.")
          }
          
          // 6) Se vuoi caricare dati dell’utente, fallo qui (opzionale)
          fetchCurrentUserData {
              // Una volta preso l’utente, chiediamo il random post
              self.fetchRandomSite()
          }
    }
    
    // MARK: - fetchRandomSite: chiama la Cloud Function e carica 1 post
    func fetchRandomSite() {
        print("Chiedo al server un post random...")

        // Esempio di URL per la funzione: sostituisci con la TUA endpoint
        guard let url = URL(string: "https://us-central1-flotip-3aa4d.cloudfunctions.net/getRandomPostFromAllUsers") else {
            print("URL non valida")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Se la tua Cloud Function richiede un token ID, aggiungi l’header:
        // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Puoi usare URLSession o Alamofire. Qui esempio con URLSession:
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.fullCollectionView.refreshControl?.beginRefreshing()
            }

            if let error = error {
                print("Errore richiesta random site:", error.localizedDescription)
                DispatchQueue.main.async {
                    self.fullCollectionView.refreshControl?.endRefreshing()
                }
                return
            }

            guard let data = data else {
                print("Nessun dato ricevuto dal server.")
                DispatchQueue.main.async {
                    self.fullCollectionView.refreshControl?.endRefreshing()
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                   let randomPostId = json["postId"] {
                    print("postId casuale ricevuto dal server: \(randomPostId)")
                    // Adesso prendiamo i dettagli del post
                    self.fetchPostDetails(postId: randomPostId)
                } else {
                    print("La Cloud Function ha restituito un JSON inatteso.")
                    DispatchQueue.main.async {
                        self.fullCollectionView.refreshControl?.endRefreshing()
                    }
                }
            } catch {
                print("Errore nel parsing JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.fullCollectionView.refreshControl?.endRefreshing()
                }
            }
        }
        task.resume()
    }

    // MARK: - fetchPostDetails: Recupera i dati di un post specifico dal database e dall'utente
    func fetchPostDetails(postId: String) {
        print("Recupero i dettagli del post con ID: \(postId)...")
        
        let postsRef = Database.database().reference().child("user_posts_sites")
        
        postsRef.observeSingleEvent(of: .value) { snapshot in
            guard snapshot.exists(),
                  let userPostsData = snapshot.value as? [String: [String: AnyObject]] else {
                print("Errore: Impossibile trovare dati in user_posts_sites.")
                DispatchQueue.main.async {
                    self.fullCollectionView.refreshControl?.endRefreshing()
                }
                return
            }
            
            // Iterate over users to find the post
            for (userId, posts) in userPostsData {
                if let postData = posts[postId] {
                    print("Post trovato per l'utente con ID: \(userId).")
                    
                    // Fetch user details
                    self.fetchUserDetails(userId: userId) { user in
                        guard let user = user else {
                            print("Errore: Impossibile trovare l'utente proprietario del post.")
                            DispatchQueue.main.async {
                                self.fullCollectionView.refreshControl?.endRefreshing()
                            }
                            return
                        }
                        
                        // Create the Post object
                        let post = Post(postId: postId, user: user, dictionary: postData as! Dictionary<String, AnyObject>)
                        
                        // Update the collectionView with the post
                        self.userPostsSites = [post]
                        
                        DispatchQueue.main.async {
                            print("Post e utente caricati correttamente. Ricarico la CollectionView.")
                            self.fullCollectionView.reloadData()
                            self.fullCollectionView.refreshControl?.endRefreshing()
                        }
                    }
                    return
                }
            }
            
            // If the post was not found
            print("Errore: Post ID \(postId) non trovato.")
            DispatchQueue.main.async {
                self.fullCollectionView.refreshControl?.endRefreshing()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60 // Altezza personalizzata
    }
    // MARK: - fetchUserDetails: Recupera i dettagli di un utente dato il suo ID
    func fetchUserDetails(userId: String, completion: @escaping (User?) -> Void) {
        let userRef = Database.database().reference().child("users").child(userId)
        userRef.observeSingleEvent(of: .value) { snapshot in
            guard let userData = snapshot.value as? [String: AnyObject] else {
                print("Impossibile trovare i dettagli dell'utente con ID: \(userId)")
                completion(nil)
                return
            }

            let user = User(uid: userId, dictionary: userData)
            completion(user)
        }
    }
    // MARK: - fetchCurrentUserData (opzionale)
    func fetchCurrentUserData(completion: @escaping () -> Void) {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            completion()
            return
        }
        
        let ref = Database.database().reference().child("users").child(currentUid)
        ref.observeSingleEvent(of: .value) { snapshot in
            guard let dictionary = snapshot.value as? [String: AnyObject] else {
                print("Failed to fetch user data")
                completion()
                return
            }
            self.user = User(uid: currentUid, dictionary: dictionary)
            print("User data fetched: \(self.user?.username ?? "No Username")")
            
            completion()
        }
    }
    
    // Se clicchi su refresh
    @objc func handleRefresh() {
        // Ogni volta che fai refresh, chiediamo di nuovo un post random
        userPostsSites.removeAll()
        self.fullCollectionView.reloadData()
       fetchRandomSite()
    }
    
    // MARK: - Refresh Control
    var refreshControl: UIRefreshControl?
    
    func configureRefreshControl() {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        refreshControl = rc
    }
    
    // MARK: - TableView DataSource / Delegate
    func numberOfSections(in tableView: UITableView) -> Int { return 1 }
   
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if filteredUsers.isEmpty && inSearchMode && !isSearching {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "NoResultsCell")
            cell.textLabel?.text = "Nessun risultato trovato"
            cell.textLabel?.textColor = .gray
            cell.textLabel?.textAlignment = .center
            cell.selectionStyle = .none
            return cell
        }

        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as? SearchUserCell else {
            return UITableViewCell()
        }
        
        let user = filteredUsers[indexPath.row]
        cell.user = user
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return 0 // Non mostra nulla mentre sta cercando
        }

        if filteredUsers.isEmpty && inSearchMode {
            return 1 // Mostra "Nessun risultato trovato" solo se non ci sono risultati
        }

        return filteredUsers.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if filteredUsers.isEmpty {
            return // Non fare nulla se la cella mostra "No Results"
        }
        
        let user = filteredUsers[indexPath.row]
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = user
        userProfileVC.isFromSearch = true // Indica che viene dalla ricerca
        navigationController?.pushViewController(userProfileVC, animated: true)
    }
    
    // MARK: - CollectionView DataSource / Delegate
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        // Mostriamo i post se non stiamo cercando
        return inSearchMode ? 0 : userPostsSites.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "FeedCell",
            for: indexPath
        ) as? FeedCell else {
            fatalError("Failed to dequeue FeedCell")
        }
        
        let post = userPostsSites[indexPath.item]
        cell.delegate = self
        cell.post = post
        
        // Carichiamo l'immagine
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
        
        let post = userPostsSites[indexPath.item]
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            handleImageTapped(url: postUrl)
        }
    }
    
    // MARK: - Spaziatura items
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
        searchBar.barTintColor = UIColor(
            red: 240/255,
            green: 240/255,
            blue: 240/255,
            alpha: 1
        )
        searchBar.tintColor = .black
        searchBar.searchTextField.backgroundColor = .gray
        searchBar.showsCancelButton = true
        navigationItem.titleView = searchBar
    }
    
    func searchBar(_ searchBar: UISearchBar,
                   textDidChange searchText: String) {
        if searchText.isEmpty || searchText == " " {
            // Non stiamo cercando
            inSearchMode = false
            fullCollectionView.isHidden = false
            tableView.isHidden = true
            tableView.reloadData()
            fullCollectionView.reloadData()
        } else {
            // Stiamo cercando
            inSearchMode = true
            fullCollectionView.isHidden = true
            tableView.isHidden = false
            searchUsers(withUsername: searchText.lowercased())
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        searchBar.text = nil
        inSearchMode = false
        
        fullCollectionView.isHidden = false
        tableView.isHidden = true
        
        tableView.reloadData()
        fullCollectionView.reloadData()
    }
    
    // MARK: - Ricerca Utenti
    func searchUsers(withUsername username: String) {
        // Resetta i risultati e aggiorna lo stato della ricerca
        self.filteredUsers = []
        self.isSearching = true
        self.noResultsLabel.isHidden = true
        tableView.reloadData()
        
        guard !username.isEmpty else {
            // Se il campo di ricerca è vuoto, resetta la modalità di ricerca
            inSearchMode = false
            isSearching = false
            tableView.reloadData()
            return
        }

        inSearchMode = true

        // Query per ricerca parziale
        let query = USER_REF
            .queryOrdered(byChild: "username")
            .queryStarting(atValue: username)
            .queryEnding(atValue: username + "\u{f8ff}")

        query.observeSingleEvent(of: .value) { snapshot in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                print("Nessun utente trovato.")
                self.filteredUsers = []
                self.isSearching = false
                self.tableView.reloadData()
                self.noResultsLabel.isHidden = false // Mostra il messaggio
                return
            }

            // Itera sugli utenti trovati
            let group = DispatchGroup()
            self.filteredUsers = []

            allObjects.forEach { snap in
                let uid = snap.key
                group.enter()
                Database.fetchUser(with: uid) { fetchedUser in
                    if !self.filteredUsers.contains(where: { $0.uid == fetchedUser.uid }) {
                        self.filteredUsers.append(fetchedUser)
                    }
                    group.leave()
                }
            }

            // Quando tutte le richieste sono completate
            group.notify(queue: .main) {
                self.isSearching = false
                self.tableView.reloadData()
                if self.filteredUsers.isEmpty {
                    self.noResultsLabel.isHidden = false // Mostra il messaggio solo se vuoto
                } else {
                    self.noResultsLabel.isHidden = true // Nascondi il messaggio
                }
            }
        }
    }
    
    // MARK: - NavigationBar
    func configureNavigationBar() {
        guard let currentUid = Auth.auth().currentUser?.uid,
              let user = self.user else { return }
        
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
