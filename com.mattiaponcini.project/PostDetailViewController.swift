//
//  PostDetailViewController.swift
//  Flotip
//
//  Vista fullscreen di un singolo post, presentata dal tap su una
//  copertina della Libreria. Mostra immagine grande + caption, in
//  uno stile coerente con la FeedCell ma su una sola pagina.
//

import UIKit

final class PostDetailViewController: UIViewController {

    // MARK: - Input
    private let post: Post

    // MARK: - UI

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let captionContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let captionLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor.white.withAlphaComponent(0.92)
        l.numberOfLines = 6
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let closeBtn: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.down",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
                   for: .normal)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let authorLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = .white
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Init

    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupLayout()
        loadContent()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(imageView)
        view.addSubview(spinner)
        view.addSubview(topBar)
        topBar.addSubview(closeBtn)
        topBar.addSubview(authorLabel)
        view.addSubview(captionContainer)
        captionContainer.addSubview(captionLabel)

        closeBtn.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            // Top bar
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 56),

            closeBtn.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            closeBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),

            authorLabel.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            authorLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            // Image
            imageView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: captionContainer.topAnchor),

            spinner.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),

            // Caption
            captionContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captionContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captionContainer.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            captionLabel.topAnchor.constraint(equalTo: captionContainer.topAnchor, constant: 12),
            captionLabel.bottomAnchor.constraint(equalTo: captionContainer.bottomAnchor, constant: -12),
            captionLabel.leadingAnchor.constraint(equalTo: captionContainer.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: captionContainer.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Data

    private func loadContent() {
        authorLabel.text = "@\(post.authorName)"

        if post.caption.isEmpty {
            captionLabel.text = nil
            captionContainer.isHidden = true
        } else {
            captionLabel.text = post.caption
            captionContainer.isHidden = false
        }

        guard let url = URL(string: post.imageURL) else { return }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            imageView.image = cached
            return
        }
        spinner.startAnimating()
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            self?.spinner.stopAnimating()
            if let image = image {
                self?.imageView.image = image
            }
        }
    }

    // MARK: - Actions

    @objc private func handleClose() {
        dismiss(animated: true)
    }
}
