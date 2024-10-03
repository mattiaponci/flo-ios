//
//  SecondViewController.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import UIKit
import CropViewController
import Firebase

class SecondViewController: UIViewController, CropViewControllerDelegate {

    var imageView: UIImageView!
    var textView: UITextView!
    var screenshotImage: UIImage?
    var postButton: UIButton!
    var closeButton: UIButton!
    var topBar: UIView!
    var linkLabel: UILabel!
    var pageURL: URL?  // Variabile per salvare l'URL della pagina
    var linkIcon: UIImageView!
    var categoryIcon: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        setupUI()
        configureImageIfNeeded()
        addKeyboardObservers()
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
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        view.addSubview(imageView)

        // Configure the UITextView for comments
        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.layer.borderColor = UIColor.gray.cgColor
        textView.layer.borderWidth = 1.0
        textView.layer.cornerRadius = 10
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

        // Configure the link icon and label
        linkIcon = UIImageView(image: UIImage(systemName: "paperclip"))
        linkIcon.translatesAutoresizingMaskIntoConstraints = false
        linkIcon.tintColor = .blue
        view.addSubview(linkIcon)

        linkLabel = UILabel()
        linkLabel.text = pageURL?.host?.replacingOccurrences(of: "www.", with: "") ?? "No URL"
        linkLabel.textColor = .blue
        linkLabel.textAlignment = .left
        linkLabel.isUserInteractionEnabled = true
        linkLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(linkLabel)
        linkLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(linkLabelTapped)))

        // Configure the category icon
        categoryIcon = UIButton(type: .system)
        categoryIcon.setImage(UIImage(systemName: "tag"), for: .normal)
        categoryIcon.tintColor = .blue
        categoryIcon.translatesAutoresizingMaskIntoConstraints = false
        categoryIcon.addTarget(self, action: #selector(categoryIconTapped), for: .touchUpInside)
        view.addSubview(categoryIcon)

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
            imageView.widthAnchor.constraint(equalToConstant: 100),
            imageView.heightAnchor.constraint(equalToConstant: 100),

            textView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(equalToConstant: 100),

            linkIcon.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 20),
            linkIcon.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            linkIcon.widthAnchor.constraint(equalToConstant: 24),
            linkIcon.heightAnchor.constraint(equalToConstant: 24),

            linkLabel.centerYAnchor.constraint(equalTo: linkIcon.centerYAnchor),
            linkLabel.leadingAnchor.constraint(equalTo: linkIcon.trailingAnchor, constant: 10),
            linkLabel.trailingAnchor.constraint(equalTo: categoryIcon.leadingAnchor, constant: -10),
            linkLabel.heightAnchor.constraint(equalToConstant: 30),

            categoryIcon.centerYAnchor.constraint(equalTo: linkIcon.centerYAnchor),
            categoryIcon.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            categoryIcon.widthAnchor.constraint(equalToConstant: 24),
            categoryIcon.heightAnchor.constraint(equalToConstant: 24),

            postButton.topAnchor.constraint(equalTo: linkLabel.bottomAnchor, constant: 20),
            postButton.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            postButton.trailingAnchor.constraint(equalTo: textView.trailingAnchor),
            postButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func configureImageIfNeeded() {
        if let image = screenshotImage {
            imageView.image = image
        }
    }

    @objc func postButtonTapped() {
        handleUploadsavesitePost()
    }

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

    @objc func linkLabelTapped() {
        if let url = pageURL {
            print(url.absoluteString)
        }
    }

    @objc func categoryIconTapped() {
        let alertController = UIAlertController(title: "Select Category", message: nil, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Sport", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "Attualità", style: .default, handler: nil))
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            alertController.dismiss(animated: true, completion: nil)
        }))
        present(alertController, animated: true, completion: nil)
    }

    @objc func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
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
}

