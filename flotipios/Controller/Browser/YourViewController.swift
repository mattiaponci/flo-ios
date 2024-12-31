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
    
    // Collection views
    var searchEnginesCollectionView: UICollectionView!
    var newspapersCollectionView: UICollectionView!
    var userPostsSitesCollectionView: UICollectionView!
    
    // Data arrays
    var userPostsSites = [Post]()
    
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
    
    func setupLabelsAndCollectionViews() {
        addSection(title: "Search Engines", collectionView: &searchEnginesCollectionView)
        addSection(title: "Newspapers", collectionView: &newspapersCollectionView)
        addSection(title: "User Posts Sites", collectionView: &userPostsSitesCollectionView)
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
        case searchEnginesCollectionView:
            return 4
        case newspapersCollectionView:
            return 1
        case userPostsSitesCollectionView:
            return userPostsSites.count
        default:
            return 0
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        let imageView = UIImageView(frame: cell.bounds)
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 10 // Bordi arrotondati
        imageView.clipsToBounds = true // Applica il ritaglio per i bordi arrotondati
        
        if collectionView == searchEnginesCollectionView {
            let images = ["google", "yahoo", "bing", "baidu"]
            imageView.image = UIImage(named: images[indexPath.item])
        } else if collectionView == newspapersCollectionView {
            imageView.image = UIImage(named: "gazza")
        } else if collectionView == userPostsSitesCollectionView {
            let post = userPostsSites[indexPath.item]
            if let imageUrl = post.imageUrl {
                imageView.sd_setImage(with: URL(string: imageUrl), placeholderImage: UIImage(named: "placeholder"))
            } else {
                imageView.image = UIImage(named: "placeholder")
            }
            
            // Aggiungi animazione di "shaking" se in modalità modifica
            if showDeleteButtons {
                let shakeAnimation = CABasicAnimation(keyPath: "transform.rotation")
                shakeAnimation.fromValue = -0.05
                shakeAnimation.toValue = 0.05
                shakeAnimation.duration = 0.1
                shakeAnimation.autoreverses = true
                shakeAnimation.repeatCount = .infinity
                cell.layer.add(shakeAnimation, forKey: "shake")
            } else {
                cell.layer.removeAnimation(forKey: "shake")
            }
        }
        
        cell.contentView.addSubview(imageView)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == searchEnginesCollectionView {
            let urls = ["https://www.google.com", "https://www.yahoo.com", "https://www.bing.com", "https://image.baidu.com"]
            if let url = URL(string: urls[indexPath.item]) {
                delegate?.didSelectWebsite(url: url)
            }
        } else if collectionView == newspapersCollectionView {
            if let url = URL(string: "https://www.gazzetta.it") {
                delegate?.didSelectWebsite(url: url)
            }
        } else if collectionView == userPostsSitesCollectionView {
            if showDeleteButtons {
                // Show confirmation alert for deletion
                let post = userPostsSites[indexPath.item]
                let alertController = UIAlertController(
                    title: "Delete Post",
                    message: "Are you sure you want to delete this post?",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { _ in
                    post.deletePost { error in
                        if let error = error {
                            print("Failed to delete post: \(error.localizedDescription)")
                        } else {
                            print("Post deleted successfully")
                            self.userPostsSites.remove(at: indexPath.item)
                            self.userPostsSitesCollectionView.reloadData()
                        }
                    }
                }))
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                present(alertController, animated: true, completion: nil)
            } else {
                let post = userPostsSites[indexPath.item]
                if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
                    delegate?.didSelectWebsite(url: postUrl)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 120, height: 120)
    }
    
    func fetchSitesSavePosts() {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            DispatchQueue.main.async {
                self.scrollView.refreshControl?.endRefreshing()
            }
            return
        }

        let userRef = Database.database().reference().child("users").child(currentUid)
        userRef.observeSingleEvent(of: .value) { userSnapshot in
            guard let userDict = userSnapshot.value as? [String: AnyObject] else {
                print("Failed to fetch user data")
                DispatchQueue.main.async {
                    self.scrollView.refreshControl?.endRefreshing()
                }
                return
            }
            let user = User(uid: currentUid, dictionary: userDict)

            let postsRef = Database.database().reference().child("user_posts_sites").child(currentUid)
            postsRef.observeSingleEvent(of: .value, with: { snapshot in
                self.userPostsSites.removeAll()
                guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                    print("Failed to cast snapshot to DataSnapshot")
                    DispatchQueue.main.async {
                        self.scrollView.refreshControl?.endRefreshing()
                    }
                    return
                }

                let group = DispatchGroup()

                for postSnapshot in allObjects {
                    let postId = postSnapshot.key
                    let postFlagsRef = Database.database().reference().child("post-flags").child(postId).child(currentUid)
                    group.enter()
                    postFlagsRef.observeSingleEvent(of: .value, with: { flagSnapshot in
                        defer { group.leave() }
                        if let flagValue = flagSnapshot.value as? Int, flagValue == 1 {
                            if let postData = postSnapshot.value as? [String: AnyObject] {
                                let post = Post(postId: postId, user: user, dictionary: postData)
                                self.userPostsSites.append(post)
                            }
                        }
                    })
                }

                group.notify(queue: DispatchQueue.main) {
                    self.userPostsSitesCollectionView.reloadData()
                    self.scrollView.refreshControl?.endRefreshing()
                }
            }, withCancel: { error in
                print("Error fetching user posts sites: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.scrollView.refreshControl?.endRefreshing()
                }
            })
        }
    }
    @objc func handleEditButtonTapped() {
        showDeleteButtons.toggle()
        userPostsSitesCollectionView.reloadData()
        
        // Aggiorna il titolo del pulsante di modifica
        navigationItem.rightBarButtonItem?.title = showDeleteButtons ? "Done" : "Edit"
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
