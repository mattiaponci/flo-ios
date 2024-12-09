//
//  SecondViewController.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import UIKit
import CropViewController
import Firebase
import SDWebImage

class SecondViewController: UIViewController, CropViewControllerDelegate, UITextViewDelegate {

    var imageView: UIImageView!
    var textView: UITextView!
    var screenshotImage: UIImage?
    var postButton: UIButton!
    var saveButton: UIButton!
    var closeButton: UIButton!
    var topBar: UIView!
    var pageURL: URL?  // Variable to store the page URL
    var categoryIcon: UIButton!
    var dimmingView: UIView!

    // Data array for user posts
    var userPostsSites = [Post]()
    var userPostsCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupUI()
        configureImageIfNeeded()
        addKeyboardObservers()
        addTapGestureToDismissKeyboard()  // Aggiunto riconoscitore di tap
    }

    func setupUI() {
        // Configure the top bar
        topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        topBar.backgroundColor = .lightGray
        view.addSubview(topBar)

        // Configure the close button
        closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(closeButton)

        // Configure the UIImageView to display the screenshot image
        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit // Mostra tutta l'immagine
        imageView.isUserInteractionEnabled = true
        imageView.layer.cornerRadius = 1 // Ridotto il bordo arrotondato al minimo
        imageView.clipsToBounds = true
        view.addSubview(imageView)

        // Configure the UITextView for comments
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.borderColor = UIColor.gray.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 10
        textView.backgroundColor = UIColor.lightGray // Sfondo grigio
        textView.textColor = .black // Colore del testo nero
        textView.font = UIFont.systemFont(ofSize: 14) // Testo più piccolo
        textView.delegate = self // Assicura che il delegato sia assegnato correttamente
        view.addSubview(textView)

        // Configure the Post button
        postButton = UIButton(type: .system)
        postButton.setTitle("Post", for: .normal)
        postButton.setTitleColor(.white, for: .normal)
        postButton.backgroundColor = .systemBlue
        postButton.layer.cornerRadius = 10
        postButton.addTarget(self, action: #selector(postButtonTapped), for: .touchUpInside)
        postButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(postButton)

        // Configure the Save button
        saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(saveButton)

        // Configure the user posts collection view
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        userPostsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        userPostsCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "postCell")
        userPostsCollectionView.dataSource = self
        userPostsCollectionView.delegate = self
        userPostsCollectionView.backgroundColor = .white
        userPostsCollectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(userPostsCollectionView)

        setupConstraints()
    }

    func setupConstraints() {
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),

            closeButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 10),
            closeButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            imageView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalToConstant: 250), // Altezza dell'immagine

            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 60), // Altezza ridotta

            postButton.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 20),
            postButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            postButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            postButton.heightAnchor.constraint(equalToConstant: 50),

            saveButton.topAnchor.constraint(equalTo: postButton.bottomAnchor, constant: 20), // Aggiunto spazio per evitare sovrapposizione
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            userPostsCollectionView.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 20),
            userPostsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            userPostsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            userPostsCollectionView.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    func configureImageIfNeeded() {
        if let image = screenshotImage {
            imageView.image = image
        }
    }

    func addTapGestureToDismissKeyboard() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc func postButtonTapped() {
        // Disable post button to prevent multiple taps
        postButton.isEnabled = false

        // Add dimming view to indicate posting process
        addDimmingView()

        // Handle post upload
        handleUploadsavesitePost()
    }

    @objc func saveButtonTapped() {
        if let url = pageURL {
            print("Save button tapped, URL: \(url.absoluteString)")
        } else {
            print("No URL available to save")
        }

        // Mostra il custom Action Sheet
        categoryIconTapped()
    }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    func addDimmingView() {
        dimmingView = UIView(frame: view.bounds)
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimmingView)
        view.bringSubviewToFront(postButton) // Ensure postButton remains visible
    }
    // Rest of your code...


    // Rest of your code...





    func handleUploadsavesitePost() {
        guard let caption = textView.text,
              let postImg = imageView.image,
              let currentUid = Auth.auth().currentUser?.uid,
              let urlString = pageURL?.absoluteString else { return }

        guard let uploadData = postImg.jpegData(compressionQuality: 0.5) else { return }

        let creationDate = Int(NSDate().timeIntervalSince1970)
        let filename = NSUUID().uuidString
        let storageRef = Storage.storage().reference().child("post_images").child(filename)

        storageRef.putData(uploadData, metadata: nil) { (metadata, error) in
            if let error = error {
                print("Failed to upload image to storage: \(error.localizedDescription)")
                return
            }

            storageRef.downloadURL { (url, error) in
                guard let imageUrl = url?.absoluteString else { return }

                let values: [String: Any] = [
                    "caption": caption,
                    "creationDate": creationDate,
                    "likes": 0,
                    "imageUrl": imageUrl,
                    "ownerUid": currentUid,
                    "pageURL": urlString
                ]

                let postId = Database.database().reference().child("posts").childByAutoId()
                guard let postKey = postId.key else { return }

                postId.updateChildValues(values) { (error, ref) in
                    if let error = error {
                        print("Failed to save post data: \(error.localizedDescription)")
                        return
                    }

                    let userPostsRef = Database.database().reference().child("user_posts_sites").child(currentUid)
                    userPostsRef.updateChildValues([postKey: 1])

                    self.updateUserFeeds(with: postKey)
                    self.fetchUserPostsSites() // Fetch and update UI after posting
                    self.dismiss(animated: true) {
                        self.tabBarController?.selectedIndex = 0
                    }
                }
            }
        }
    }

    func updateUserFeeds(with postId: String) {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        let values = [postId: 1]

        Database.database().reference().child("user_followers").child(currentUid).observe(.childAdded) { snapshot in
            let followerUid = snapshot.key
            Database.database().reference().child("user_feeds").child(followerUid).updateChildValues(values)
        }

        Database.database().reference().child("user_feeds").child(currentUid).updateChildValues(values)
    }

 

    @objc func categoryIconTapped() {
        // Crea una vista semi-trasparente come sfondo
        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.gray.withAlphaComponent(0.5) // Sfondo grigio semi-trasparente
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.alpha = 0
        view.addSubview(dimmingView)
        NSLayoutConstraint.activate([
            dimmingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimmingView.topAnchor.constraint(equalTo: view.topAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Crea il contenitore per il custom Action Sheet
        let actionSheetView = UIView()
        actionSheetView.backgroundColor = UIColor.lightGray // Contenitore grigio
        actionSheetView.layer.cornerRadius = 16
        actionSheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        actionSheetView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(actionSheetView)

        let actionSheetHeight: CGFloat = 350
        NSLayoutConstraint.activate([
            actionSheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            actionSheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            actionSheetView.heightAnchor.constraint(equalToConstant: actionSheetHeight),
            actionSheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: actionSheetHeight)
        ])

        // Contenuti dell'Action Sheet
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Select Category"
        subtitleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        subtitleLabel.textColor = .black
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        actionSheetView.addSubview(subtitleLabel)

        // Pulsanti personalizzati
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 16
        buttonStackView.distribution = .fillEqually
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        actionSheetView.addSubview(buttonStackView)

        let buttonTitles = ["Sport", "News", "Activity", "Save"]
        for title in buttonTitles {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.layer.cornerRadius = 8
            if title == "Save" {
                // Pulsante "Save" con sfondo azzurro
                button.backgroundColor = UIColor.systemBlue
                button.setTitleColor(.white, for: .normal)
            } else {
                // Pulsanti normali con sfondo bianco
                button.backgroundColor = .white
                button.setTitleColor(.black, for: .normal)
            }
            button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)
            buttonStackView.addArrangedSubview(button)
        }

        // Layout dei contenuti
        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: actionSheetView.topAnchor, constant: 16),
            subtitleLabel.centerXAnchor.constraint(equalTo: actionSheetView.centerXAnchor),

            buttonStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            buttonStackView.leadingAnchor.constraint(equalTo: actionSheetView.leadingAnchor, constant: 16),
            buttonStackView.trailingAnchor.constraint(equalTo: actionSheetView.trailingAnchor, constant: -16),
            buttonStackView.bottomAnchor.constraint(equalTo: actionSheetView.bottomAnchor, constant: -24)
        ])

        // Mostra il custom Action Sheet con animazione
        UIView.animate(withDuration: 0.3) {
            dimmingView.alpha = 1
            actionSheetView.transform = CGAffineTransform(translationX: 0, y: -actionSheetHeight)
        }

        // Chiudi il custom Action Sheet toccando la vista semi-trasparente
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissActionSheet))
        dimmingView.addGestureRecognizer(tapGesture)
        dimmingView.isUserInteractionEnabled = true

        // Assegna i tag per poter accedere facilmente alle viste quando necessario
        dimmingView.tag = 101
        actionSheetView.tag = 102
    }

    @objc func categoryButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        print("Category selected: \(title)")

        // Se il pulsante è "Save", dismetti la vista come se fosse stato premuto il pulsante di chiusura
        if title == "Save" {
            dismiss(animated: true, completion: nil)
        } else {
            // Chiudi l'action sheet senza dismettere l'intero view controller
            dismissActionSheet()
        }
    }

    @objc func dismissActionSheet() {
        // Trova le viste aggiunte per il custom action sheet
        if let dimmingView = view.viewWithTag(101), let actionSheetView = view.viewWithTag(102) {
            UIView.animate(withDuration: 0.3, animations: {
                actionSheetView.transform = .identity
                dimmingView.alpha = 0
            }) { _ in
                dimmingView.removeFromSuperview()
                actionSheetView.removeFromSuperview()
            }
        }
    }

   

    func addKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.height
            let bottomPadding = view.safeAreaInsets.bottom
            let visibleHeight = view.frame.height - keyboardHeight - bottomPadding

            let textViewBottom = textView.frame.origin.y + textView.frame.height
            if textViewBottom > visibleHeight {
                view.frame.origin.y = -(textViewBottom - visibleHeight + 20)
            }
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        view.frame.origin.y = 0
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func fetchUserPostsSites() {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            print("No current user ID found")
            return
        }

        print("Fetching user posts sites for user with ID: \(currentUid)")

        Database.database().reference().child("user_posts_sites").child(currentUid).observeSingleEvent(of: .value, with: { snapshot in
            print("Snapshot received: \(snapshot)")

            guard snapshot.exists() else {
                print("No user posts sites found for user")
                return
            }

            guard let allObjects = snapshot.children.allObjects as? [DataSnapshot] else {
                print("Failed to cast snapshot to DataSnapshot")
                return
            }

            // Clear previous posts to avoid duplicates
            self.userPostsSites.removeAll()

            allObjects.forEach { snapshot in
                let postId = snapshot.key
                print("Fetching post with ID: \(postId)")
                self.fetchPost(withPostId: postId) { post in
                    // Ensure the post is fetched and print the post details
                    print("Fetched post: \(post)")

                    // Add the post to the array
                    self.userPostsSites.append(post)

                    // Sort posts by creation date
                    self.userPostsSites.sort(by: { $0.creationDate > $1.creationDate })

                    // Reload collection view on the main thread
                    DispatchQueue.main.async {
                        self.userPostsCollectionView.reloadData()
                    }
                }
            }
        }) { error in
            print("Failed to fetch user posts sites: \(error.localizedDescription)")
        }
    }

    func fetchPost(withPostId postId: String, completion: @escaping (Post) -> Void) {
        print("Attempting to fetch post with ID: \(postId)")
        Database.fetchPost(with: postId) { (post) in
            print("Fetched post with ID: \(postId)")
            completion(post)
        }
    }
}


extension SecondViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return userPostsSites.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "postCell", for: indexPath)
        
        // Rimuovere tutte le subviews precedenti per evitare duplicati
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Configurare l'UIImageView per visualizzare l'immagine del post sulla sinistra della cella
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10

        // Configurare l'UILabel per visualizzare il testo del post
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.textColor = .gray
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.numberOfLines = 2 // Numero di righe limitato per ridurre l'altezza del testo

        // Imposta i dati del post
        let post = userPostsSites[indexPath.item]
        if let imageUrl = post.imageUrl {
            imageView.sd_setImage(with: URL(string: imageUrl), placeholderImage: UIImage(named: "placeholder"))
        }
        textLabel.text = post.caption ?? "No caption available"

        // Aggiungere le subviews alla contentView della cella
        cell.contentView.addSubview(imageView)
        cell.contentView.addSubview(textLabel)

        // Layout delle subviews all'interno della cella
        NSLayoutConstraint.activate([
            // Layout per l'immagine
            imageView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 10),
            imageView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 10),
            imageView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -10),
            imageView.widthAnchor.constraint(equalTo: cell.contentView.widthAnchor, multiplier: 0.4), // L'immagine occupa il 40% della larghezza

            // Layout per il testo
            textLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            textLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -10),
            textLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor), // Centrare il testo verticalmente con l'immagine
            textLabel.heightAnchor.constraint(equalToConstant: 40) // Altezza del testo ridotta per migliorare il layout
        ])
        
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let post = userPostsSites[indexPath.item]
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            UIApplication.shared.open(postUrl, options: [:], completionHandler: nil)
        }
    }
}
