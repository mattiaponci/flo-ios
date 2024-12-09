//
//  PhotoCell.swift
//  flotipios
//
//  Created by mattia poncini on 09.12.2024.
//

//
//  PhotoCell.swift
//  flotipios
//
//  Created by mattia poncini on 26.09.2024.
//

import UIKit


class PhotoCell: UICollectionViewCell {

    // MARK: - Properties

    var delegate: PhotoCellDelegate?

    var photo: Photo? {
        didSet {
            configure()
        }
    }

    private let profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        return iv
    }()

    private let usernameButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Username", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
        button.setTitleColor(.black, for: .normal)
        button.addTarget(self, action: #selector(handleUsernameTapped), for: .touchUpInside)
        return button
    }()

    private let optionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.addTarget(self, action: #selector(handleOptionsTapped), for: .touchUpInside)
        return button
    }()

    private let postImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .lightGray
        iv.isUserInteractionEnabled = true
        return iv
    }()

    private let likeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "heart"), for: .normal)
        button.addTarget(self, action: #selector(handleLikeTapped), for: .touchUpInside)
        return button
    }()

    private let commentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "message"), for: .normal)
        button.addTarget(self, action: #selector(handleCommentTapped), for: .touchUpInside)
        return button
    }()

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "bookmark"), for: .normal)
        button.addTarget(self, action: #selector(handleSaveTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Selectors

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

    @objc func handleSaveTapped() {
        delegate?.handleSaveTapped(for: self)
    }

    // MARK: - Helpers

    func configureUI() {
        addSubview(profileImageView)
        addSubview(usernameButton)
        addSubview(optionsButton)
        addSubview(postImageView)
        addSubview(likeButton)
        addSubview(commentButton)
        addSubview(saveButton)

        // Layout code goes here
    }

    func configure() {
        guard let photo = photo else { return }
        // Configure the cell with the photo data
    }
}
