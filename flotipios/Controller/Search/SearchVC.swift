import UIKit
import Firebase
import SDWebImage
import AudioToolbox
import FirebaseFunctions
import Alamofire
import FirebaseAuth
import FirebaseStorage


private let reuseIdentifier = "SearchUserCell"

class SearchVC: UITableViewController, UISearchBarDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, FeedCellDelegate {
    
    
    weak var delegate: NotificationsVC?
    
    // MARK: - FeedCellDelegate Methods
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
    
    // MARK: - Properties
    var user: User?
    var users = [User]()
    var filteredUsers = [User]()
    var searchBar = UISearchBar()
    var inSearchMode = false
    var collectionView: UICollectionView!
    var posts = [Post]()
    var currentKey: String?
    var userPostsSites = [Post]()
    var isFetching = false
    
    
    
    
    lazy var fetchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Fetch Random Post", for: .normal)
        button.backgroundColor = .blue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(handleFetchButtonTapped), for: .touchUpInside)
        return button
    }()
    lazy var horizontalCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical  // Cambiato da .horizontal a .vertical
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 90, height: 200)  // Modifica l'altezza dell'item se necessario
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false  // Puoi rimuoverlo o impostarlo su true se desideri la barra di scorrimento orizzontale
        collectionView.backgroundColor = .lightGray
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
     
        return collectionView
    }()

    
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Register cell classes
        tableView.register(SearchUserCell.self, forCellReuseIdentifier: reuseIdentifier)
        
        // Remove separators
        tableView.separatorStyle = .none
        view.backgroundColor = .white
        searchBar.searchTextField.textColor = .black
        
        // Configure components
        configureSearchBar()
        configureEmptyStateView()
        configureNavigationBar()
        configureCollectionView()
        horizontalCollectionView.refreshControl = refreshControl

        // Add horizontal collection view
        view.addSubview(horizontalCollectionView)
        NSLayoutConstraint.activate([
            horizontalCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            horizontalCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            horizontalCollectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            horizontalCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])

        // Aggiungi il pulsante alla vista principale (non alla cella)

        view.addSubview(fetchButton)
        fetchButton.translatesAutoresizingMaskIntoConstraints = false

           fetchButton.translatesAutoresizingMaskIntoConstraints = false
           fetchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
           fetchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20).isActive = true
           fetchButton.widthAnchor.constraint(equalToConstant: 200).isActive = true
           fetchButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        // Add random button functionality
        // button.addTarget(self, action: #selector(handleActionButtonTapped), for: .touchUpInside)

        // Fetch posts initially
     //   fetchRandomUserPost()
      //  configureRefreshControl()
        
        if let user = Auth.auth().currentUser {
            print("User authenticated with UID: \(user.uid)")
        } else {
            print("No user authenticated.")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    
    // MARK: - Actions
    
    // MARK: - UITableView
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = inSearchMode ? filteredUsers.count : users.count
        horizontalCollectionView.isHidden = count > 0 || inSearchMode
        return count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as? SearchUserCell else { fatalError("Failed to dequeue SearchUserCell") }
        let user = inSearchMode ? filteredUsers[indexPath.row] : users[indexPath.row]
        cell.user = user
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = inSearchMode ? filteredUsers[indexPath.row] : users[indexPath.row]
        let userProfileVC = UserProfileVC(collectionViewLayout: UICollectionViewFlowLayout())
        userProfileVC.user = user
        navigationController?.pushViewController(userProfileVC, animated: true)
    }
    
    // MARK: - UICollectionView
    
    func configureCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 90, height: UIScreen.main.bounds.height / 1.8)
        
        // Calcola l'altezza della Tab Bar
        let tabBarHeight = tabBarController?.tabBar.frame.height ?? 0
        
        // Calcola l'altezza della UICollectionView senza andare sotto la Tab Bar
        let collectionViewHeight = 200
        
        let frame = CGRect(x: 0, y: horizontalCollectionView.frame.maxY + 10, width: view.frame.width, height: 200)
        collectionView = UICollectionView(frame: frame, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .black
        collectionView.register(FeedCell.self, forCellWithReuseIdentifier: "FeedCell")
        //collectionView.refreshControl = UIRefreshControl()
       // collectionView.refreshControl?.addTarget(self, action: #selector(handleRefreshWithOffset), for: .valueChanged)
        view.addSubview(collectionView)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == horizontalCollectionView {
            return inSearchMode ? 0 : min(userPostsSites.count, 5)
        } else {
            return 1
        }
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == horizontalCollectionView {
            guard indexPath.item < userPostsSites.count else {
                fatalError("Index out of range for horizontalCollectionView")
            }
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as? FeedCell else {
                fatalError("Failed to dequeue FeedCell")
            }

            // Imposta il post
            let post = userPostsSites[indexPath.item]
            cell.post = post
            cell.delegate = self

            // Carica l'immagine in maniera asincrona
            if let imageUrl = post.imageUrl, let url = URL(string: imageUrl) {
                cell.postImageView.sd_setImage(with: url, completed: { [weak cell] image, error, cacheType, url in
                    // Questo callback viene chiamato quando l'immagine è caricata
                    DispatchQueue.main.async {
                        // A questo punto l'immagine è caricata, quindi aggiorna la cella
                        cell?.setNeedsLayout()  // Forza la cella a ridisegnarsi se necessario
                    }
                })
            }

            return cell
        } else {
            guard indexPath.item < posts.count else {
                fatalError("Index out of range for collectionView")
            }
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FeedCell", for: indexPath) as! FeedCell
            cell.post = posts[indexPath.item]
            cell.delegate = self
            return cell
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let post: Post
        if collectionView == horizontalCollectionView {
            guard indexPath.item < userPostsSites.count else {
                print("Index out of range for horizontalCollectionView in didSelectItemAt")
                return
            }
            post = userPostsSites[indexPath.item]
        } else {
            guard indexPath.item < posts.count else {
                print("Index out of range for collectionView in didSelectItemAt")
                return
            }
            post = posts[indexPath.item]
        }
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            handleImageTapped(url: postUrl)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    // MARK: - UISearchBar
    
    func configureSearchBar() {
        searchBar.sizeToFit()
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        searchBar.barTintColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1)
        searchBar.tintColor = .black
        searchBar.searchTextField.backgroundColor = .gray
        searchBar.showsCancelButton = true
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty || searchText == " " {
            inSearchMode = false
            tableView.reloadData()
            horizontalCollectionView.reloadData() // Reload horizontal collection view when exiting search mode
        } else {
            inSearchMode = true
            searchUsers(withUsername: searchText.lowercased())
            horizontalCollectionView.reloadData() // Reload horizontal collection view when entering search mode
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        searchBar.text = nil
        inSearchMode = false
        tableView.reloadData()
        horizontalCollectionView.reloadData() // Reload horizontal collection view when search is cancelled
    }
    
    // MARK: - Navigation Bar
    
    func configureNavigationBar() {
        guard let currentUid = Auth.auth().currentUser?.uid, let user = self.user else { return }
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
    
    @objc func handleRefreshWithOffset() {
        // Avvia il processo di ricaricamento dei dati
   //     fetchRandomUserPost()

        // Dopo che i dati sono stati ricaricati
        DispatchQueue.main.async {
            // Termina il refresh
       //     self.refreshControl.endRefreshing()

            // Ricarica la collection view
            self.horizontalCollectionView.reloadData()
        }
    }
    
    func configureEmptyStateView() {
        view.addSubview(horizontalCollectionView)
        NSLayoutConstraint.activate([
            horizontalCollectionView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            horizontalCollectionView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            horizontalCollectionView.widthAnchor.constraint(equalToConstant: 300),
            horizontalCollectionView.heightAnchor.constraint(equalToConstant: view.frame.height / 4)
        ])
        horizontalCollectionView.isHidden = true
    }
    
    @objc func handleRefresh() {
        posts.removeAll(keepingCapacity: false)
        self.currentKey = nil
       // fetchRandomUserPost()
        collectionView?.reloadData()
    }
    
    func configureRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView?.refreshControl = refreshControl
    }
    
    
    
    @objc func handleSettingsTapped() {
        let settingsVC = SettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
    }
    
    @objc func handleFeedCellButtonTapped() {
        print("FeedCell button tapped!")
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
     //   fetchRandomUserPost()
        
    }
    
    @objc func handleFetchButtonTapped() {
        // Cambia il colore del pulsante
        fetchButton.backgroundColor = fetchButton.backgroundColor == .blue ? .green : .blue

        // Vibra al clic
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

        // Richiama la funzione nel controller
      // fetchRandomUserPost()
        
        
        print("hello")
        refreshControl?.beginRefreshing()

    }

    
 /*   func fetchRandomUserPost() {
        Auth.auth().currentUser?.getIDToken { token, error in
            if let error = error {
                print("Errore nel recuperare il token ID: \(error.localizedDescription)")
                return
            }

            guard let token = token else {
                print("Nessun token disponibile.")
                return
            }

            print("Token ottenuto: \(token)")

            guard let url = URL(string: "https://us-central1-flotip-3aa4d.cloudfunctions.net/getRandomPostFromAllUsers") else {
                print("URL non valida.")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Errore durante la richiesta: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("Errore dal server: \(httpResponse.statusCode)")
                        return
                    }
                }

                guard let data = data else {
                    print("Nessun dato ricevuto dal server.")
                    return
                }

                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                       let postId = jsonResponse["postId"] {
                        print("Post ID ricevuto: \(postId)")
                        self.userPostsSites.removeAll()
                        print("step before fetchpost")
                        // Qui recuperi effettivamente il post corrispondente all’ID ottenuto
                        self.fetchPost(withPostId: postId) { [weak self] post in
                            guard let self = self else { return }

                            if let fetchedPost = post {
                                
                          //  self.userPostsSites.insert(fetchedPost, at: 0)


                                self.userPostsSites.append(fetchedPost)
                                print("i'm here")

                                // Ricarica la collection view sul main thread
                                DispatchQueue.main.async {
                                    self.horizontalCollectionView.isHidden = false

                                    self.horizontalCollectionView.reloadData()
                                }
                            } else {
                                print("Nessun post trovato per l'ID: \(postId)")
                            }
                        }

                    } else {
                        print("Parsing JSON fallito.")
                    }
                } catch {
                    print("Errore durante il parsing JSON: \(error.localizedDescription)")
                }
            }.resume()
        }
    }
*/
  

  /*  func fetchRandomUserPost() {
        // Ottieni il token di autenticazione dell'utente corrente
        Auth.auth().currentUser?.getIDToken { token, error in
            if let error = error {
                print("Errore nel recuperare il token ID: \(error.localizedDescription)")
                return
            }

            guard let token = token else {
                print("Nessun token disponibile.")
                return
            }

            print("Token ottenuto: \(token)")

            // Configurazione della richiesta
            guard let url = URL(string: "https://us-central1-flotip-3aa4d.cloudfunctions.net/getRandomPostFromAllUsers") else {
                print("URL non valida.")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            // Avvio del task di rete
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Errore durante la richiesta: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("HTTP Response Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("Errore dal server: \(httpResponse.statusCode)")
                        return
                    }
                }

                guard let data = data else {
                    print("Nessun dato ricevuto dal server.")
                    return
                }

                do {
                    // Parsing della risposta JSON
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
                       let postId = jsonResponse["postId"] {
                        print("Post ID ricevuto: \(postId)")
                        // Puoi aggiornare la UI direttamente qui
                        DispatchQueue.main.async {
                            // Aggiorna la UI con il postId
                            print("Aggiorna la UI con il Post ID: \(postId)")
                        }
                    } else {
                        print("Parsing JSON fallito.")
                    }
                } catch {
                    print("Errore durante il parsing JSON: \(error.localizedDescription)")
                }
            }.resume()
        }
    }*/

  /*  func fetchPost(withPostId postId: String, completion: @escaping (Post?) -> Void) {
        Database.fetchPost(with: postId) { post in
            print(post != nil ? "Post recuperato con successo: \(post.postId)" : "Errore nel recuperare il post con ID: \(postId)")
            completion(post)
        }
    }*/
    



   

   



    

    func searchUsers(withUsername username: String) {
        self.filteredUsers = []

        let query = USER_REF.queryOrdered(byChild: "username").queryStarting(atValue: username).queryEnding(atValue: username + "\u{f8ff}").queryLimited(toLast: 10)
        query.observeSingleEvent(of: .value) { (snapshot) in
            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                self.filteredUsers = []
                self.tableView.reloadData()
                return
            }

            allObjects.forEach { snapshot in
                let uid = snapshot.key
                Database.fetchUser(with: uid) { (user) in
                    if !self.filteredUsers.contains(where: { $0.uid == user.uid }) {
                        self.filteredUsers.append(user)

                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
}
