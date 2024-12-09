//
//  SearchUserCell.swift
//  flotipios
//
//  Created by mattia poncini on 29.09.2024.
//

import UIKit

class SearchUserCell: UITableViewCell {
    
    // MARK: - Properties
    
    var user: User? {
        didSet {
            guard let profileImageUrl = user?.profileImageUrl else {
                print("Profile image URL is nil")
                profileImageView.image = UIImage(named: "placeholder_profile_image")
                return
            }
            
            guard let username = user?.username else {
                print("Username is nil")
                self.textLabel?.text = "Unknown User"
                return
            }
            
            guard let fullName = user?.username else {
                print("Full name is nil")
                self.detailTextLabel?.text = ""
                return
            }
            
            // Modifica il caricamento dell'immagine rimuovendo la closure
            profileImageView.loadImage(with: profileImageUrl)
            
            self.textLabel?.text = username
                        self.textLabel?.textColor = .black
                        self.detailTextLabel?.text = fullName
                        self.detailTextLabel?.textColor = .black
        }
    }
    
    let profileImageView: CustomImageView = {
        let iv = CustomImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        
        // add profile image view
        addSubview(profileImageView)
        profileImageView.anchor(top: nil, left: leftAnchor, bottom: nil, right: nil, paddingTop: 0, paddingLeft: 8, paddingBottom: 0, paddingRight: 0, width: 48, height: 48)
        profileImageView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        profileImageView.layer.cornerRadius = 48 / 2
        
        // Text styles
               self.textLabel?.text = "Username"
               self.textLabel?.textColor = .black
               self.detailTextLabel?.text = "Full name"
               self.detailTextLabel?.textColor = .black
               self.selectionStyle = .none
               self.backgroundColor = .white
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Adjust text label and detail text label positions
        textLabel?.frame = CGRect(x: 68, y: textLabel!.frame.origin.y - 2, width: self.frame.width - 78, height: textLabel!.frame.height)
        textLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        
        detailTextLabel?.frame = CGRect(x: 68, y: detailTextLabel!.frame.origin.y, width: self.frame.width - 78, height: detailTextLabel!.frame.height)
        detailTextLabel?.textColor = .lightGray
        detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
