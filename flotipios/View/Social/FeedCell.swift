//
//  FeedCell.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import UIKit
import Firebase
import ActiveLabel

class FeedCell: UICollectionViewCell {
    
    var delegate: FeedCellDelegate?
    var postSaved: Bool = false

    var post: Post? {
        didSet {
            // Verifica se tutte le proprietà sono non nil prima di procedere
            guard let post = post else {
                print("Post is nil")
                return
            }
            
            // Usa il controllo degli opzionali per evitare l'unwrapping forzato
            guard let ownerUid = post.ownerUid else {
                print("Error: ownerUid is nil")
                return
            }
            
            guard let imageUrl = post.imageUrl else {
                print("Error: imageUrl is nil")
                return
            }
            
            guard let likes = post.likes else {
                print("Error: likes is nil")
                return
            }
            
            // Procedi con il caricamento sicuro dei dati
            Database.fetchUser(with: ownerUid) { [weak self] (user) in
                guard let self = self else { return }
                
                // Verifica che `user` sia valido
                if user != nil {
                  //  self.profileImageView.loadImage(with: user.profileImageUrl)
                    self.usernameButton.setTitle(user.username, for: .normal)
                    self.configurePostCaption(user: user)
                } else {
                    print("Error: User not found")
                }
            }
            
            // Carica l'immagine
            postImageView.loadImage(with: imageUrl)
            
            // Aggiorna i like
            likesLabel.text = "\(likes) likes"
            
            // Configura il pulsante di like
            configureLikeButton()
            configureCommentIndicatorView()
        }
    }

    lazy var savePostButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "flag") ?? UIImage(systemName: "flag.fill")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleSaveTapped), for: .touchUpInside)
        return button
    }()
    
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        return iv
    }()
    
    lazy var usernameButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Username", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.addTarget(self, action: #selector(handleUsernameTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var optionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("•••", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.addTarget(self, action: #selector(handleOptionsTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var postImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.30)
        iv.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        iv.addGestureRecognizer(tapGesture)
        return iv
    }()
    
    lazy var likeButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "star") ?? UIImage(systemName: "star")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleLikeTapped), for: .touchUpInside)
        return button
    }()

    lazy var commentButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "comment") ?? UIImage(systemName: "text.bubble")
        button.setImage(image, for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleCommentTapped), for: .touchUpInside)
        return button
    }()
    
    lazy var likesLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.text = "3 likes"
        let likeTap = UITapGestureRecognizer(target: self, action: #selector(handleShowLikes))
        likeTap.numberOfTapsRequired = 1
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(likeTap)
        return label
    }()
    
    let captionLabel: ActiveLabel = {
        let label = ActiveLabel()
        label.numberOfLines = 0
        return label
    }()
    
    let postTimeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .lightGray
        label.font = UIFont.boldSystemFont(ofSize: 10)
        label.text = "2 DAYS AGO"
        return label
    }()
    
    let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        view.layer.cornerRadius = 15
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Add container view
        addSubview(containerView)
        containerView.anchor(top: topAnchor, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        
        // Add postImageView inside the container view
        containerView.addSubview(postImageView)
        postImageView.anchor(top: containerView.topAnchor, left: containerView.leftAnchor, bottom: nil, right: containerView.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        postImageView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1).isActive = true
        
        // Add profileImageView
        containerView.addSubview(profileImageView)
        profileImageView.anchor(top: postImageView.bottomAnchor, left: containerView.leftAnchor, bottom: nil, right: nil, paddingTop: 8, paddingLeft: 8, paddingBottom: 0, paddingRight: 0, width: 40, height: 40)
        profileImageView.layer.cornerRadius = 40 / 2

        // Add usernameButton next to and slightly higher than profileImageView
        containerView.addSubview(usernameButton)
        usernameButton.translatesAutoresizingMaskIntoConstraints = false
        usernameButton.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 8).isActive = true
        usernameButton.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor, constant: 0).isActive = true

        // StackView for buttons aligned to the right (savePostButton, likeButton, commentButton, optionsButton)
        let rightButtonsStackView = UIStackView(arrangedSubviews: [savePostButton, likeButton, commentButton, optionsButton])
        rightButtonsStackView.axis = .horizontal
        rightButtonsStackView.spacing = 8
        rightButtonsStackView.distribution = .fillProportionally

        containerView.addSubview(rightButtonsStackView)
        rightButtonsStackView.anchor(top: postImageView.bottomAnchor, left: nil, bottom: nil, right: containerView.rightAnchor, paddingTop: 8, paddingLeft: 0, paddingBottom: 0, paddingRight: 8, width: 0, height: 40)
    }
   
    // MARK: - Handlers
    
    @objc func handleSaveTapped() {
        delegate?.handleFlagToLike(for: self)
    }
    
    @objc func handleUsernameTapped() {
        delegate?.handleUsernameTapped(for: self)
    }
    
    @objc func handleOptionsTapped() {
        delegate?.handleOptionsTapped(for: self)
    }
  
    @objc func handleLikeTapped() {
        delegate?.handleLikeTapped(for: self, isDoubleTap: false)
    }
    
    @objc func handleCommentTapped() {
        delegate?.handleCommentTapped(for: self)
    }
    
    @objc func handleShowLikes() {
        delegate?.handleShowLikes(for: self)
    }
    
    @objc func handleImageTap() {
        guard let post = post else {
            print("Post is nil")
            return
        }
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            delegate?.handleImageTapped(url: postUrl)
        } else {
            print("Invalid or nil URL for post")
        }
    }
    
    func configureLikeButton() {
        // Function to configure the like button
    }
    
    func configureCommentIndicatorView() {
        delegate?.configureCommentIndicatorView(for: self)
    }
    
    func configurePostCaption(user: User) {
        guard let post = self.post, let caption = post.caption, let username = user.username else {
            print("Unable to configure post caption: post, caption, or username is nil")
            return
        }
        
        let customType = ActiveType.custom(pattern: "^\(username)\\b")
        
        captionLabel.enabledTypes = [.mention, .hashtag, .url, customType]
        
        captionLabel.configureLinkAttribute = { (type, attributes, isSelected) in
            var atts = attributes
            
            switch type {
            case .custom:
                atts[NSAttributedString.Key.font] = UIFont.boldSystemFont(ofSize: 12)
            default: ()
            }
            return atts
        }
        
        captionLabel.customize { (label) in
            label.text = "\(username) \(caption)"
            label.customColor[customType] = .black
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = .black
            captionLabel.numberOfLines = 2
        }
        
        postTimeLabel.text = post.creationDate.timeAgoToDisplay()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
