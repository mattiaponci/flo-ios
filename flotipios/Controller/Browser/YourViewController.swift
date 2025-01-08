//
//  YourViewController.swift
//  flotipios
//
//  Created by mattia poncini on 28.09.2024.
//
//

import UIKit
import Firebase
import SDWebImage

protocol YourViewControllerDelegate: AnyObject {
    func didSelectWebsite(url: URL)
}

class YourViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    weak var delegate: YourViewControllerDelegate?
    
    // ScrollView and StackView
    var scrollView: UIScrollView!
    var stackView: UIStackView!
    var userPostsSites = [Post]()
      var newsPosts = [Post]()
      var sportsPosts = [Post]()
      var activitiesPosts = [Post]()
      var otherPosts = [Post]()
    // Collection views
    var searchEnginesCollectionView: UICollectionView!
    var newspapersCollectionView: UICollectionView!
    var userPostsSitesCollectionView: UICollectionView!
      var newsCollectionView: UICollectionView!
      var sportsCollectionView: UICollectionView!
    var activitiesCollectionView: UICollectionView!

    var otherCollectionView: UICollectionView!

    // Data arrays
    
    private let postReuseIdentifier = "PostCell"
    private var showDeleteButtons = false // Variabile per la modalità di modifica

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        view.backgroundColor = .white
        
        // Setup refresh control
        setupRefreshControl()
        
        // Add edit button
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(handleEditButtonTapped))
        
        // Recupera i post
       // showLoadingIndicator()  // Mostra un indicatore di caricamento
        fetchSitesSavePosts()
        
        configureNavigationBar()
    }
    
    func setupUI() {
        // ScrollView
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // StackView
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Constraints for ScrollView and StackView
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        setupLabelsAndCollectionViews()
    }
    func configureNavigationBar() {
        guard let navigationController = navigationController else { return }

        // Disabilita large titles
        navigationController.navigationBar.prefersLargeTitles = false

        // Configura l'aspetto della navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.isTranslucent = false

        // Configura il pulsante "<" senza testo
        let backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(backButtonTapped))
        backButton.tintColor = .black
        navigationItem.leftBarButtonItem = backButton
        
        
        
    }
    
    
    
    

    @objc func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    func setupLabelsAndCollectionViews() {
            addSection(title: "User Posts Sites", collectionView: &userPostsSitesCollectionView)
            addSection(title: "News", collectionView: &newsCollectionView)
            addSection(title: "Sports", collectionView: &sportsCollectionView)
            addSection(title: "Activities", collectionView: &activitiesCollectionView)
            addSection(title: "Other", collectionView: &otherCollectionView)
        }
    
    func addSection(title: String, collectionView: inout UICollectionView!) {
        let titleLabel = createLabel(text: title)
        stackView.addArrangedSubview(titleLabel)
        
        collectionView = createCollectionView()
        stackView.addArrangedSubview(collectionView)
        setCollectionViewHeight(collectionView)
    }
    
    // Create UILabel dynamically
    func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.textAlignment = .left
        label.textColor = .black
        return label
    }
    
    // Create UICollectionView dynamically
    func createCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .white
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }
    
    // Set height for UICollectionView
    func setCollectionViewHeight(_ collectionView: UICollectionView) {
        NSLayoutConstraint.activate([
            collectionView.heightAnchor.constraint(equalToConstant: 150)
        ])
    }
    
    // Setup Refresh Control
    func setupRefreshControl() {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl

    }
    
    @objc func refreshData() {
        print("Refreshing data...")
        userPostsSites.removeAll()
        userPostsSitesCollectionView.reloadData()
        fetchSitesSavePosts()
        scrollView.refreshControl?.endRefreshing()
    }
    
    // Collection View Delegate and DataSource Methods
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            switch collectionView {
            case userPostsSitesCollectionView:
                return userPostsSites.count
            case newsCollectionView:
                return newsPosts.count
            case sportsCollectionView:
                return sportsPosts.count
            case activitiesCollectionView:
                return activitiesPosts.count
            case otherCollectionView:
                return otherPosts.count
            default:
                return 0
            }
        }

  
    // Funzione per configurare la cella di ogni collection view
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let post: Post?
        switch collectionView {
        case userPostsSitesCollectionView:
            post = userPostsSites[indexPath.item]
        case newsCollectionView:
            post = newsPosts[indexPath.item]
        case sportsCollectionView:
            post = sportsPosts[indexPath.item]
        case activitiesCollectionView:
            post = activitiesPosts[indexPath.item]
        case otherCollectionView:
            post = otherPosts[indexPath.item]
        default:
            post = nil
        }

        if let post = post {
            print("Displaying post: \(post.caption ?? "No Caption")")
        }

        // Configurazione dell'immagine nella cella
        let imageView = UIImageView(frame: cell.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10

        if let imageUrl = post?.imageUrl {
            imageView.sd_setImage(with: URL(string: imageUrl), placeholderImage: UIImage(named: "placeholder"))
        } else {
            imageView.image = UIImage(named: "placeholder")
        }
        cell.contentView.addSubview(imageView)
        
        // Aggiungi riconoscitore di pressione prolungata
           let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
           longPressGesture.minimumPressDuration = 2.0
           cell.addGestureRecognizer(longPressGesture)

        // Applicazione dell'effetto di shaking
        if showDeleteButtons {
            addShakeAnimation(to: cell)
        } else {
            removeShakeAnimation(from: cell)
        }

        return cell
    }
    
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showDeleteButtons = true
        print("Entered edit mode with shaking effect")
        reloadAllCollectionsWithShakeEffect()
    }
    // MARK: - Metodo per Attivare Effetto Shaking in Tutte le Categorie
    @objc func handleEditButtonTapped() {
        showDeleteButtons.toggle()

        // Ricarica tutte le collezioni per applicare o rimuovere l'effetto di shaking
        userPostsSitesCollectionView.reloadData()
        newsCollectionView.reloadData()
        sportsCollectionView.reloadData()
        activitiesCollectionView.reloadData()
        otherCollectionView.reloadData()

        // Aggiorna il titolo del pulsante di modifica
        navigationItem.rightBarButtonItem?.title = showDeleteButtons ? "Done" : "Edit"
    }

    // MARK: - Helper Methods per Shaking Effect

    private func addShakeAnimation(to cell: UICollectionViewCell) {
        let shakeAnimation = CABasicAnimation(keyPath: "transform.rotation")
        shakeAnimation.fromValue = -0.05
        shakeAnimation.toValue = 0.05
        shakeAnimation.duration = 0.1
        shakeAnimation.autoreverses = true
        shakeAnimation.repeatCount = .infinity
        cell.layer.add(shakeAnimation, forKey: "shake")
    }

    private func removeShakeAnimation(from cell: UICollectionViewCell) {
        cell.layer.removeAnimation(forKey: "shake")
    }

    // MARK: - Metodo per Attivare Vibrazione in Tutte le Collezioni

  

    // MARK: - Metodo per Ricaricare Tutte le Collezioni con Effetto Shaking

    private func reloadAllCollectionsWithShakeEffect() {
        userPostsSitesCollectionView.reloadData()
        newsCollectionView.reloadData()
        sportsCollectionView.reloadData()
        activitiesCollectionView.reloadData()
        otherCollectionView.reloadData()
    }
    
    
    // MARK: - Metodo per Attivare Effetto Shaking in Tutte le Categorie
   

    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 120, height: 120)
    }
    func fetchSitesSavePosts() {
          guard let currentUid = Auth.auth().currentUser?.uid else { return }

          userPostsSites.removeAll()
          newsPosts.removeAll()
          sportsPosts.removeAll()
          activitiesPosts.removeAll()
          otherPosts.removeAll()

          let categories = ["user_posts_sites", "news", "sport", "activity", "other"]
          let group = DispatchGroup()

          for category in categories {
              group.enter()
              let postsRef = Database.database().reference().child(category).child(currentUid)
              postsRef.observeSingleEvent(of: .value, with: { snapshot in
                  defer { group.leave() }
                  guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else { return }

                  for postSnapshot in allObjects {
                      guard let postData = postSnapshot.value as? [String: AnyObject] else { continue }
                      let postId = postSnapshot.key
                      let post = Post(postId: postId, user: nil, dictionary: postData)

                      switch category {
                      case "user_posts_sites":
                          self.userPostsSites.append(post)
                      case "news":
                          self.newsPosts.append(post)
                      case "sport":
                          self.sportsPosts.append(post)
                      case "activity":
                          self.activitiesPosts.append(post)
                      case "other":
                          self.otherPosts.append(post)
                      default:
                          break
                      }
                  }

                  print("Fetched \(self.userPostsSites.count) user posts, \(self.newsPosts.count) news posts, \(self.sportsPosts.count) sports posts.")
              }, withCancel: { error in
                  print("Error fetching posts for \(category): \(error.localizedDescription)")
                  group.leave()
              })
          }

          group.notify(queue: DispatchQueue.main) {
              self.userPostsSitesCollectionView.reloadData()
              self.newsCollectionView.reloadData()
              self.sportsCollectionView.reloadData()
              self.activitiesCollectionView.reloadData()
              self.otherCollectionView.reloadData()
          }
      }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        var selectedPost: Post?

        // Determina il post selezionato in base alla collection view
        switch collectionView {
        case userPostsSitesCollectionView:
            selectedPost = userPostsSites[indexPath.item]
        case newsCollectionView:
            selectedPost = newsPosts[indexPath.item]
        case sportsCollectionView:
            selectedPost = sportsPosts[indexPath.item]
        case activitiesCollectionView:
            selectedPost = activitiesPosts[indexPath.item]
        case otherCollectionView:
            selectedPost = otherPosts[indexPath.item]
        default:
            return
        }

        guard let post = selectedPost else {
            print("Post not found for the selected item.")
            return
        }

        // Se siamo in modalità modifica (shaking), mostra il popup di eliminazione
        if showDeleteButtons {
            guard let postId = post.postId else {
                print("Post ID is missing")
                return
            }

            let alertController = UIAlertController(
                title: "Delete Post",
                message: "Are you sure you want to delete this post?",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                // Rimuovi il post dal database e dall'interfaccia
                post.deletePost(postId: postId) { error in
                    if let error = error {
                        print("Failed to delete post: \(error.localizedDescription)")
                    } else {
                        print("Post deleted successfully")

                        // Rimuovi il post dall'array appropriato
                        switch collectionView {
                        case self.userPostsSitesCollectionView:
                            self.userPostsSites.removeAll { $0.postId == postId }
                            self.userPostsSitesCollectionView.reloadData()
                        case self.newsCollectionView:
                            self.newsPosts.removeAll { $0.postId == postId }
                            self.newsCollectionView.reloadData()
                        case self.sportsCollectionView:
                            self.sportsPosts.removeAll { $0.postId == postId }
                            self.sportsCollectionView.reloadData()
                        case self.activitiesCollectionView:
                            self.activitiesPosts.removeAll { $0.postId == postId }
                            self.activitiesCollectionView.reloadData()
                        case self.otherCollectionView:
                            self.otherPosts.removeAll { $0.postId == postId }
                            self.otherCollectionView.reloadData()
                        default:
                            break
                        }
                    }
                }
            }))
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            present(alertController, animated: true, completion: nil)
        } else {
            // Se non è in modalità modifica, apri il link del post
            if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
                delegate?.didSelectWebsite(url: postUrl)
            }
        }
    }
    
    func showLoadingIndicator() {
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.center = view.center
        loadingIndicator.tag = 100 // Tag per individuare facilmente l'indicatore di caricamento
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
    }
    
    func hideLoadingIndicator() {
        if let loadingIndicator = view.viewWithTag(100) as? UIActivityIndicatorView {
            loadingIndicator.stopAnimating()
            loadingIndicator.removeFromSuperview()
        }
    }
}
