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
    var stackView: UIStackView!
    var postSaved: Bool = false // Variabile per monitorare lo stato del salvataggio

    var post: Post? {
        didSet {
            guard let ownerUid = post?.ownerUid else { return }
            guard let imageUrl = post?.imageUrl else { return }
            guard let likes = post?.likes else { return }
            
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
    
    lazy var savePostButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "flag"), for: .normal)
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
        button.setTitleColor(.white, for: .normal)
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
        iv.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 0.30) // Colore grigio molto chiaro
        iv.isUserInteractionEnabled = true  // Abilita l'interazione con l'immagine
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleImageTap))
        iv.addGestureRecognizer(tapGesture)
        return iv
    }()
    
    lazy var likeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "like_unselected"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleLikeTapped), for: .touchUpInside)
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
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // Colore grigio molto chiaro

        view.layer.cornerRadius = 15
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner] // Arrotonda tutti gli angoli
        view.clipsToBounds = true
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // Aggiungi la vista contenitore
        addSubview(containerView)
        containerView.anchor(top: topAnchor, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        
        // Aggiungi postImageView all'interno della vista contenitore
        containerView.addSubview(postImageView)
        postImageView.anchor(top: containerView.topAnchor, left: containerView.leftAnchor, bottom: nil, right: containerView.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        postImageView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1).isActive = true
        
        containerView.addSubview(profileImageView)
        profileImageView.anchor(top: postImageView.topAnchor, left: postImageView.leftAnchor, bottom: nil, right: nil, paddingTop: 8, paddingLeft: 8, paddingBottom: 0, paddingRight: 0, width: 40, height: 40)
        profileImageView.layer.cornerRadius = 40 / 2
        
        containerView.addSubview(usernameButton)
        usernameButton.anchor(top: profileImageView.bottomAnchor, left: postImageView.leftAnchor, bottom: nil, right: nil, paddingTop: 4, paddingLeft: 8, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        
        containerView.addSubview(optionsButton)
        optionsButton.anchor(top: profileImageView.bottomAnchor, left: nil, bottom: nil, right: containerView.rightAnchor, paddingTop: 4, paddingLeft: 0, paddingBottom: 0, paddingRight: 8, width: 0, height: 0)
        
        configureActionButtons()
    }
   
    // MARK: - Handlers
    
    @objc func handleSaveTapped() {
        delegate?.handleSaveTapped(for: self)
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
    
    @objc func handleDoubleTapToLike() {
        delegate?.handleLikeTapped(for: self, isDoubleTap: true)
    }
    
    @objc func handleImageTap() {
        guard let post = post else { return }
        print("kava")
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            // Stampa l'URL del sito del feed nella console
            print("Opening URL: \(postUrl)")
            
            // Chiamata al delegato per aprire il BrowserViewController con l'URL
            delegate?.handleImageTapped(url: postUrl)
            print("primo passaggio")
        } else {
            print("Invalid or nil URL for post")
        }
    }
    
    func configureLikeButton() {
        delegate?.handleConfigureLikeButton(for: self)
    }
    
    func configureCommentIndicatorView() {
        delegate?.configureCommentIndicatorView(for: self)
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
        // StackView per profileImageView, likeButton e commentButton
        stackView = UIStackView(arrangedSubviews: [profileImageView, likeButton, commentButton])
        
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .equalSpacing
        
        containerView.addSubview(stackView)
        stackView.anchor(top: postImageView.bottomAnchor, left: containerView.leftAnchor, bottom: containerView.bottomAnchor, right: nil, paddingTop: 8, paddingLeft: 8, paddingBottom: 8, paddingRight: 0, width: 0, height: 50)
        
        containerView.addSubview(savePostButton)
        savePostButton.anchor(top: postImageView.bottomAnchor, left: nil, bottom: nil, right: containerView.rightAnchor, paddingTop: 12, paddingLeft: 0, paddingBottom: 0, paddingRight: 8, width: 20, height: 24)
    }
    
    func addCommentIndicatorView(toStackView stackView: UIStackView) {
        commentIndicatorView.isHidden = false
        
        stackView.addSubview(commentIndicatorView)
        commentIndicatorView.anchor(top: stackView.topAnchor, left: stackView.leftAnchor, bottom: nil, right: nil, paddingTop: 14, paddingLeft: 64, paddingBottom: 0, paddingRight: 0, width: 10, height: 10)
        commentIndicatorView.layer.cornerRadius = 10 / 2
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

