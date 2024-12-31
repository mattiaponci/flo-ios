//
//  UserPostCell.swift
//  flotipios
//
//  Created by mattia poncini on 30.09.2024.
//

import UIKit
import Firebase
import ActiveLabel

class UserPostCell: UICollectionViewCell {
    
    // MARK: - Proprietà
    var delegate: UserCellDelegate?
    var stackView: UIStackView!
    var postSaved: Bool = false // Variabile per monitorare lo stato del salvataggio
    var viewSinglePost = false

    
    var post: Post? {
        didSet {
            guard let ownerUid = post?.ownerUid,
                  let imageUrl = post?.imageUrl,
                  let likes = post?.likes else {
                print("Error: One of the post properties is nil")
                return
            }
            
            // Procede in modo sicuro dato che tutti i valori sono garantiti non nil
            Database.fetchUser(with: ownerUid) { (user) in
                self.profileImageView.loadImage(with: user.profileImageUrl)
                self.usernameButton.setTitle(user.username, for: .normal)
                self.configurePostCaption(user: user)
            }
            
            postImageView.loadImage(with: imageUrl)
            
            likesLabel.text = "\(likes) likes"
            configureLikeButton()
            configureCommentIndicatorView()
        }
    }
    
    // MARK: - UI Components
    
    
    
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        iv.isUserInteractionEnabled = false // Ensure no interaction
        return iv
    }()

    
    lazy var usernameButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Username", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 12)
        button.addTarget(self, action: #selector(handleUsernameTapped), for: .touchUpInside)
        return button
    }()
    
    
    
    lazy var postImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.30) // Colore grigio molto chiaro
        iv.isUserInteractionEnabled = true  // Abilita l'interazione con l'immagine
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        iv.addGestureRecognizer(tapGesture)
        return iv
    }()
    lazy var optionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("•••", for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.addTarget(self, action: #selector(handleOptionsTapped), for: .touchUpInside)
        return button
    }()
    lazy var likeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "star"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleLikeTapped), for: .touchUpInside)
        return button
    }()
    lazy var savePostButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleFlagToLike), for: .touchUpInside)
        return button
    }()
    lazy var commentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "comment"), for: .normal)
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
    
    let commentIndicatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .red
        return view
    }()
    
    let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        view.layer.cornerRadius = 15
        view.clipsToBounds = true
        return view
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
   
            
            // Configura ombreggiatura
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = 4
            layer.masksToBounds = false

            // Configura containerView
            containerView.layer.cornerRadius = 10
            containerView.layer.masksToBounds = true

            // Aggiungi la containerView come subview
            addSubview(containerView)
            containerView.anchor(top: topAnchor, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 10, paddingLeft: 10, paddingBottom: 10, paddingRight: 10, width: 0, height: 0)

            // Configura l'immagine del post
            containerView.addSubview(postImageView)
            postImageView.anchor(top: containerView.topAnchor, left: containerView.leftAnchor, bottom: nil, right: containerView.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 20, paddingRight: 0, width: 0, height: 0)
            postImageView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1).isActive = true

            // Configura immagine profilo e username
            containerView.addSubview(profileImageView)
            profileImageView.anchor(top: postImageView.bottomAnchor, left: containerView.leftAnchor, bottom: nil, right: nil, paddingTop: 8, paddingLeft: 10, paddingBottom: 0, paddingRight: 0, width: 40, height: 40)
            profileImageView.layer.cornerRadius = 20 // Arrotonda i bordi del profilo
            profileImageView.layer.masksToBounds = true

            containerView.addSubview(usernameButton)
            usernameButton.anchor(top: postImageView.bottomAnchor, left: profileImageView.rightAnchor, bottom: nil, right: nil, paddingTop: 15, paddingLeft: 10, paddingBottom: 0, paddingRight: 0, width: 0, height: 20)
            usernameButton.setTitleColor(.black, for: .normal) // Testo nero

            // Configura il pulsante delle azioni (flag, like, comment)
            let actionStackView = UIStackView(arrangedSubviews: [savePostButton, likeButton, commentButton,optionsButton])
            actionStackView.axis = .horizontal
            actionStackView.spacing = 12
            actionStackView.alignment = .center
            containerView.addSubview(actionStackView)
            actionStackView.anchor(top: nil, left: nil, bottom: containerView.bottomAnchor, right: containerView.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 10, paddingRight: 10, width: 0, height: 24)
        }
    
    // MARK: - Handlers
    
    @objc func handleSaveTapped() {
       // delegate?.handleSaveTapped(for: self)
    }
    
    @objc func handleUsernameTapped() {
       // delegate?.handleUsernameTapped(for: self)
    }
    
    @objc func handleOptionsTapped() {
        print("hello wooww")
        delegate?.handleOptionsTapped(for: self, isDoubleTap: false)
    }
  
    @objc func handleLikeTapped() {
        delegate?.handleLikeTapped(for: self, isDoubleTap: false)
    }
    
    @objc func handleCommentTapped() {
       delegate?.handleCommentTapped(for: self)
    }
    
    @objc func handleShowLikes() {
       // delegate?.handleShowLikes(for: self)
    }
    
    @objc func handleDoubleTapToLike() {
        delegate?.handleLikeTapped(for: self, isDoubleTap: true)
    }
    @objc func handleFlagToLike() {
        delegate?.handleFlagToLike(for: self, isDoubleTap: true)
    }
    @objc func handleImageTap() {
            guard let linkString = post?.link, let url = URL(string: linkString) else {
                print("Invalid or nil URL for post")
                return
            }
            delegate?.handleImageclicked(url: url)
        }
    
    
    // MARK: - Funzioni di configurazione
    
    func configureLikeButton() {
       // delegate?.handleConfigureLikeButton(for: self)
    }
    
    func configureCommentIndicatorView() {
       // delegate?.configureCommentIndicatorView(for: self)
    }
    
    func configurePostCaption(user: User) {
        guard let post = self.post else { return }
        guard let caption = post.caption else { return }
        guard let username = post.user?.username else { return }
        
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
    
 
    
    func configureActionButtons() {
        // Adding profileImageView, likeButton, and commentButton in the same row
        stackView = UIStackView(arrangedSubviews: [profileImageView, likeButton, commentButton])
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fillEqually
        
        containerView.addSubview(stackView)
        stackView.anchor(top: postImageView.bottomAnchor, left: containerView.leftAnchor, bottom: containerView.bottomAnchor, right: nil, paddingTop: 8, paddingLeft: 8, paddingBottom: 8, paddingRight: 0, width: 0, height: 50)
        
        // Update profileImageView constraints for consistent display
        profileImageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
        profileImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
        profileImageView.layer.cornerRadius = 20 // make it circular if needed
    

                
       // containerView.addSubview(savePostButton)
       // savePostButton.anchor(top: postImageView.bottomAnchor, left: nil, bottom: nil, right: containerView.rightAnchor, paddingTop: 12, paddingLeft: 0, paddingBottom: 0, paddingRight: 8, width: 20, height: 24)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
