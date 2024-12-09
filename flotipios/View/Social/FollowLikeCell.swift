//
//  FollowLikeCell.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import UIKit
import Firebase

class FollowLikeCell: UITableViewCell {
    
    // MARK: - Properties
    
    var delegate: FollowCellDelegate?
    
    var user: User? {
        didSet {
            // Assicurati che tutti i dati siano correttamente recuperati
            guard let profileImageUrl = user?.profileImageUrl else {
                print("DEBUG: Profile image URL is nil")
                profileImageView.image = UIImage(named: "placeholder_profile_image")
                return
            }
            
            guard let username = user?.username else {
                print("DEBUG: Username is nil")
                self.textLabel?.text = "Unknown User"
                return
            }
            
            // Gestione del fullName
            if let fullName = user?.username {
                self.detailTextLabel?.text = fullName
            } else {
                print("DEBUG: Full name is nil")
                self.detailTextLabel?.text = "No name provided" // Valore di fallback
            }
            
            // Debug: Stampa i dati per verificare se sono corretti
            print("DEBUG: Profile Image URL: \(profileImageUrl)")
            print("DEBUG: Username: \(username)")
            
            // Carica l'immagine del profilo
            profileImageView.loadImage(with: profileImageUrl)
            
            // Imposta il nome utente e il nome completo
            self.textLabel?.text = username
            self.textLabel?.textColor = .black
            self.detailTextLabel?.textColor = .black
            
            // Aggiorna layout
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        return iv
    }()
    
    /*
    lazy var followButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Loading", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)
        button.addTarget(self, action: #selector(handleFollowTapped), for: .touchUpInside)
        button.layer.cornerRadius = 3
        return button
    }()
    */
    
    // MARK: - Handlers
    
    /*
    @objc func handleFollowTapped() {
        print("DEBUG: Follow button tapped")
        delegate?.handleFollowTapped(for: self)
    }
    */
    
    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
        addSubview(profileImageView)
        profileImageView.anchor(top: nil, left: leftAnchor, bottom: nil, right: nil, paddingTop: 0, paddingLeft: 8, paddingBottom: 0, paddingRight: 0, width: 48, height: 48)
        profileImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        profileImageView.layer.cornerRadius = 48 / 2
        
        // Aggiungi il pulsante follow solo se necessario in futuro
        /*
        addSubview(followButton)
        followButton.anchor(top: nil, left: nil, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 12, width: 90, height: 30)
        followButton.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        */
        
        textLabel?.text = "Username"
        detailTextLabel?.text = "Full name"
        
        self.selectionStyle = .none
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let textLabel = textLabel {
            textLabel.frame = CGRect(x: 68, y: textLabel.frame.origin.y - 2, width: contentView.frame.width - 108, height: textLabel.frame.height)
            textLabel.font = UIFont.boldSystemFont(ofSize: 12)
        }
        
        if let detailTextLabel = detailTextLabel {
            detailTextLabel.frame = CGRect(x: 68, y: detailTextLabel.frame.origin.y, width: contentView.frame.width - 108, height: detailTextLabel.frame.height)
            detailTextLabel.textColor = .lightGray
            detailTextLabel.font = UIFont.systemFont(ofSize: 12)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
