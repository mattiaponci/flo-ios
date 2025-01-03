//
//  UserProfileHeader.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import UIKit
import Firebase

class UserProfileHeader: UICollectionViewCell {
    
    // MARK: - Properties
    
    //var isFromFollowers: Bool = false
    
    var isFromFollowLikeVC: Bool = false
    
    var delegate: UserProfileHeaderDelegate?
    private var cachedSavedSitesCount: Int = 0 // Cache for saved sites count
    private var cachedFollowerCount: Int = 0 // Cache per il conteggio dei follower
    private var cachedFollowingCount: Int = 0 // Cache for following count

    var user: User? {
        didSet {
            setUserStats(for: user)
            nameLabel.text = user?.name
            usernameLabel.text = user?.username
            
            // Update the userRedLabel with the username
            userRedLabel.text = user?.username ?? ""
            
            // Load profile image
            if let profileImageUrl = user?.profileImageUrl {
                profileImageView.loadImage(with: profileImageUrl)
                profileImageView.layer.cornerRadius = 50
            }
            
            // Update saved sites count
            updateSavedSitesCount(for: user)
            
            // Aggiorna il conteggio dei follower & following
            updateFollowerCount(for: user)
            updateFollowingCount(for: user)

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
    // Add Friend Button
    let addFriendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleAddFriendTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Nascondi inizialmente
        return button
    }()
    // Name Label
    let nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 14)
        label.textAlignment = .center
        return label
    }()
    
    // Username Label
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
    
    // Back Button
    let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.backward"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(handleBackToSearchTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // Nascondi inizialmente
        return button
    }()


    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(badgeView)
        badgeView.addSubview(profileImageView)
        badgeView.addSubview(userRedLabel)
        badgeView.addSubview(statsStackView)
        badgeView.addSubview(settingsButton)
        badgeView.addSubview(backButton) // Aggiungi il pulsante Indietro
        badgeView.addSubview(addFriendButton)



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
            badgeView.topAnchor.constraint(equalTo: topAnchor, constant: 25),
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
            settingsButton.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 10),
            settingsButton.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10),
            settingsButton.widthAnchor.constraint(equalToConstant: 30),
            settingsButton.heightAnchor.constraint(equalTo: settingsButton.widthAnchor),
            
            // Back Button
            backButton.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: badgeView.leadingAnchor, constant: 10),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalTo: backButton.widthAnchor),
            
            // Add Friend Button
            addFriendButton.topAnchor.constraint(equalTo: badgeView.topAnchor, constant: 10),
            addFriendButton.trailingAnchor.constraint(equalTo: badgeView.trailingAnchor, constant: -10), // Stesso
            addFriendButton.widthAnchor.constraint(equalToConstant: 30),
            addFriendButton.heightAnchor.constraint(equalTo: addFriendButton.widthAnchor),
        ])
    }
    @objc func handleAddFriendTapped() {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Nessun utente corrente trovato.")
            return
        }

        guard let viewedUserId = user?.uid else {
            print("Nessun utente visualizzato trovato.")
            return
        }

        let followersRef = Database.database().reference().child("followers").child(viewedUserId)
        let followingRef = Database.database().reference().child("following").child(currentUserId)

        // Controlla se l'utente è già un follower
        followersRef.child(currentUserId).observeSingleEvent(of: .value) { snapshot in
            if snapshot.exists() {
                // Rimuovi l'utente dai follower
                followersRef.child(currentUserId).removeValue { error, _ in
                    if let error = error {
                        print("Errore durante la rimozione del follower: \(error.localizedDescription)")
                        return
                    }
                    print("Follower rimosso con successo.")

                    // Rimuovi anche dai "following" del corrente utente
                    followingRef.child(viewedUserId).removeValue { error, _ in
                        if let error = error {
                            print("Errore durante la rimozione del following: \(error.localizedDescription)")
                            return
                        }
                        print("Following rimosso con successo.")
                    }

                    DispatchQueue.main.async {
                        self.addFriendButton.setImage(UIImage(systemName: "plus"), for: .normal)
                    }
                }
            } else {
                // Aggiungi l'utente ai follower
                followersRef.child(currentUserId).setValue(1) { error, _ in
                    if let error = error {
                        print("Errore durante l'aggiunta del follower: \(error.localizedDescription)")
                        return
                    }
                    print("Follower aggiunto con successo.")

                    // Aggiungi anche nei "following" del corrente utente
                    followingRef.child(viewedUserId).setValue(1) { error, _ in
                        if let error = error {
                            print("Errore durante l'aggiunta del following: \(error.localizedDescription)")
                            return
                        }
                        print("Following aggiunto con successo.")
                    }

                    DispatchQueue.main.async {
                        self.addFriendButton.setImage(UIImage(systemName: "checkmark"), for: .normal)
                    }
                }
            }
        }
    }
    private func updateSavedSitesCount(for user: User?) {
        guard let userId = user?.uid else { return }
        
        // Use cached value if available
        if cachedSavedSitesCount > 0 {
            updateSavedSitesLabel(with: cachedSavedSitesCount)
        }
        
        // Listen to Firebase updates
        Database.database().reference().child("user_posts_sites").child(userId).observe(.value) { snapshot in
            let count = snapshot.childrenCount
            self.cachedSavedSitesCount = Int(count)
            self.updateSavedSitesLabel(with: self.cachedSavedSitesCount)
        }
    }
    
    private func updateSavedSitesLabel(with count: Int) {
        DispatchQueue.main.async {
            let attributedText = NSMutableAttributedString(string: "\(count)\n", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
            attributedText.append(NSAttributedString(string: "saved sites", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.lightGray
            ]))
            self.savedSitesLabel.attributedText = attributedText
        }
    }
    
    // MARK: - Delegate Actions
    
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
        delegate?.handleEditFollowTapped(for: self)
    }
    
    func configureHeader(for user: User?, isFromSearch: Bool, isFromFeed: Bool, isFromFollowLikeVC: Bool) {
        self.user = user
        self.isFromFollowLikeVC = isFromFollowLikeVC // Assegna il valore alla proprietà
        
        let isCurrentUser = user?.uid == Auth.auth().currentUser?.uid

        // Mostra il pulsante "Indietro" se l'utente è diverso dall'utente corrente
        // oppure se si proviene da FeedVC, SearchVC o FollowLikeVC
        backButton.isHidden = !(isFromSearch || isFromFeed || isFromFollowLikeVC || !isCurrentUser)
        
        // Nascondi il pulsante "Impostazioni" se non è l'utente corrente
        settingsButton.isHidden = !isCurrentUser

        // Mostra il pulsante "Aggiungi Amico" solo per utenti diversi dall'utente corrente
        // e se si proviene da FeedVC, SearchVC o FollowLikeVC
        addFriendButton.isHidden = isCurrentUser || !(isFromSearch || isFromFeed || isFromFollowLikeVC)
        
        // Verifica se l'utente è già seguito e aggiorna l'icona del pulsante "Aggiungi Amico"
        if let currentUserId = Auth.auth().currentUser?.uid, let viewedUserId = user?.uid {
            let followersRef = Database.database().reference().child("followers").child(viewedUserId)
            followersRef.child(currentUserId).observeSingleEvent(of: .value) { snapshot in
                let isFollowing = snapshot.exists()
                DispatchQueue.main.async {
                    let buttonImage = isFollowing ? UIImage(systemName: "checkmark") : UIImage(systemName: "plus")
                    self.addFriendButton.setImage(buttonImage, for: .normal)
                }
            }
        }
    }
    

    @objc func handleBackToSearchTapped() {
        delegate?.didTapBackToSearch()
    }
    
    private func updateFollowerCount(for user: User?) {
        guard let userId = user?.uid else { return }

        // Usa il valore in cache se disponibile
        if cachedFollowerCount > 0 {
            updateFollowerLabel(with: cachedFollowerCount)
        }

        // Ascolta gli aggiornamenti su Firebase
        Database.database().reference().child("followers").child(userId).observe(.value) { snapshot in
            let count = snapshot.childrenCount
            self.cachedFollowerCount = Int(count)
            self.updateFollowerLabel(with: self.cachedFollowerCount)
        }
    }

    private func updateFollowerLabel(with count: Int) {
        DispatchQueue.main.async {
            let attributedText = NSMutableAttributedString(string: "\(count)\n", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
            attributedText.append(NSAttributedString(string: "followers", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.lightGray
            ]))
            self.followersLabel.attributedText = attributedText
        }
    }
    private func updateFollowingCount(for user: User?) {
        guard let userId = user?.uid else { return }

        // Use cached value if available
        if cachedFollowingCount > 0 {
            updateFollowingLabel(with: cachedFollowingCount)
        }

        // Listen for updates from Firebase
        Database.database().reference().child("following").child(userId).observe(.value) { snapshot in
            let count = snapshot.childrenCount
            self.cachedFollowingCount = Int(count)
            self.updateFollowingLabel(with: self.cachedFollowingCount)
        }
    }

    private func updateFollowingLabel(with count: Int) {
        DispatchQueue.main.async {
            let attributedText = NSMutableAttributedString(string: "\(count)\n", attributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ])
            attributedText.append(NSAttributedString(string: "following", attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.lightGray
            ]))
            self.followingLabel.attributedText = attributedText
        }
    }
    
}
