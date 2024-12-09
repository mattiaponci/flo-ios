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
    
    lazy var savePostButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(named: "flag") ?? UIImage(systemName: "flag.fill") // Fallback to system image if not found
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
        button.setImage(#imageLiteral(resourceName: "star"), for: .normal)
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
        view.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
        view.layer.cornerRadius = 15
        view.clipsToBounds = true
        return view
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(containerView)
        containerView.anchor(top: topAnchor, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 0)
        
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
        //delegate?.handleSaveTapped(for: self)
    }
    
    @objc func handleUsernameTapped() {
       // delegate?.handleUsernameTapped(for: self)
    }
    
    @objc func handleOptionsTapped() {
       // delegate?.handleOptionsTapped(for: self)
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
      //  delegate?.handleLikeTapped(for: self, isDoubleTap: true)
    }
    
    @objc func handleImageTap() {
        guard let post = post else { return }
        print("kava")
        if let postUrlString = post.link, let postUrl = URL(string: postUrlString) {
            // Stampa l'URL del sito del feed nella console
            print("Opening URL: \(postUrl)")
            
            // Chiamata al delegato per aprire il BrowserViewController con l'URL
           delegate?.handleImageclicked(url: postUrl)
            
            print("primo passaggio")

        } else {
            print("Invalid or nil URL for post")
        }    }
    
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
