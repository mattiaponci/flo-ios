//
//  UserProfileHeader.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

//
//  UserProfileHeader.swift
//  flotipios
//
//  Created by mattia poncini on
import UIKit
import Firebase

class UserProfileHeader: UICollectionViewCell {
    
    // MARK: - Properties
    
    var delegate: UserProfileHeaderDelegate?
    
    var user: User? {
        didSet {
            setUserStats(for: user)
            nameLabel.text = user?.name
            usernameLabel.text = user?.username
            
            // Aggiorna la userRedLabel con l'username da Firebase
            if let username = user?.username {
                userRedLabel.text = username
            } else {
                userRedLabel.text = "" // Testo di fallback
            }
            
            // Carica l'immagine del profilo
            guard let profileImageUrl = user?.profileImageUrl else { return }
            profileImageView.loadImage(with: profileImageUrl)
            profileImageView.layer.cornerRadius = 50 // Tondo con metà larghezza/altezza
        }
    }
    
    // Badge Container
    private let badgeView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 6
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Profile Image
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    // User Label in Red
    let userRedLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Name Label
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()
    
    // Username Static Label
    let usernameStaticLabel: UILabel = {
        let label = UILabel()
        label.text = "Username"
        label.font = UIFont.italicSystemFont(ofSize: 12)
        label.textColor = .gray
        label.textAlignment = .center
        return label
    }()
    
    // Username Label (Dynamic)
    let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .gray
        label.textAlignment = .center
        return label
    }()
    
    // Posts Label
    let postsLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ])
        attributedText.append(NSAttributedString(string: "posts", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.lightGray
        ]))
        label.attributedText = attributedText
        return label
    }()
    
    // Followers Label
    lazy var followersLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ])
        attributedText.append(NSAttributedString(string: "followers", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.lightGray
        ]))
        label.attributedText = attributedText
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFollowersTapped))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tap)
        return label
    }()
    // Settings Button
    let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "gearshape"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleSettingsTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    // Following Label
    lazy var followingLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ])
        attributedText.append(NSAttributedString(string: "following", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.lightGray
        ]))
        label.attributedText = attributedText
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFollowingTapped))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(tap)
        return label
    }()
    
    // Saved Sites Label
    let savedSitesLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        let attributedText = NSMutableAttributedString(string: "0\n", attributes: [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ])
        attributedText.append(NSAttributedString(string: "saved sites", attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.lightGray
        ]))
        label.attributedText = attributedText
        return label
    }()
    
    // Stats Stack View
    private lazy var statsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [
            followersLabel,
            followingLabel,
            savedSitesLabel,
        ])
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(badgeView)
        badgeView.addSubview(profileImageView)
        badgeView.addSubview(userRedLabel) // Aggiungi la label "User"
        
        badgeView.addSubview(statsStackView)
        badgeView.addSubview(settingsButton) // Aggiungi il pulsante al badgeView

        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Helpers
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Badge View
            badgeView.centerXAnchor.constraint(equalTo: centerXAnchor),
            badgeView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            badgeView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.9),
            badgeView.heightAnchor.constraint(equalToConstant: 200),
            
            // Profile Image
            profileImageView.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            profileImageView.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 10),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalTo: profileImageView.widthAnchor),
            
            // User Label
            userRedLabel.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            userRedLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 8),
            
            // Stats Stack View
            statsStackView.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 15),
            statsStackView.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -15),
            statsStackView.bottomAnchor.constraint(equalTo: badgeView.bottomAnchor, constant: -10),
            statsStackView.heightAnchor.constraint(equalToConstant: 40),
            
            // Settings Button
            settingsButton.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 10), // Posizionato nell'angolo superiore destro del badge
            settingsButton.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10), // Margine destro
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalTo: settingsButton.widthAnchor)
        ])
    }   // MARK: - Delegate Actions
    
    @objc func handleFollowersTapped() {
        delegate?.handleFollowersTapped(for: self)
    }
    
    @objc func handleFollowingTapped() {
        delegate?.handleFollowingTapped(for: self)
    }
    
    func setUserStats(for user: User?) {
        delegate?.setUserStats(for: self)
    }
    @objc func handleSettingsTapped() {
        delegate?.handleEditFollowTapped(for: self) // Oppure esegui l'azione desiderata
    }
    
}
