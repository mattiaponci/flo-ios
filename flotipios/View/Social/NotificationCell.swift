import UIKit


class NotificationCell: UITableViewCell, UITextViewDelegate {
    
    // MARK: - Proprietà
    var notification: NotificationModel? // Modello della notifica associato alla cella
        
    weak var delegate: NotificationCellDelegate?
    
    // MARK: - Inizializzazione
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configurazione UI
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .white
    }

    // MARK: - Configurazione Contenuto
    func configure(with notification: NotificationModel) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        self.notification = notification
        switch notification.type {
        case .follow:
            configureFollowNotification(notification: notification)
        case .newPost:
            configureNewPostNotification(notification: notification)
        }
        
        // Aggiungi un gesture recognizer per l'intera cella
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCellTap))
        contentView.addGestureRecognizer(tapGesture)
        contentView.isUserInteractionEnabled = true
    }

    @objc private func handleCellTap() {
        print("handleCellTap called!")
        guard let notification = notification else {
            print("Nessuna notifica associata alla cella!")
            return
        }
        delegate?.didTapCell(for: notification)
    }

    // MARK: - Configurazione Notifica Follow
    private func configureFollowNotification(notification: NotificationModel) {
        let text = "You started to follow "
        let attributedString = NSMutableAttributedString(string: text)
        
        if let username = notification.username, let userId = notification.userId {
            let link = NSAttributedString(
                string: username,
                attributes: [
                    .link: URL(string: "userId://\(userId)")!,
                    .foregroundColor: UIColor.blue,
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            attributedString.append(link)
        }
        
        // Usa UITextView per rendere cliccabile il nome utente
        let notificationTextView = UITextView()
        notificationTextView.attributedText = attributedString
        notificationTextView.isEditable = false
        notificationTextView.isSelectable = true
        notificationTextView.isScrollEnabled = false
        notificationTextView.textContainerInset = .zero
        notificationTextView.textContainer.lineFragmentPadding = 0
        notificationTextView.backgroundColor = .clear
        notificationTextView.linkTextAttributes = [
            .foregroundColor: UIColor.blue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        notificationTextView.delegate = self
        notificationTextView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(notificationTextView)
        
        NSLayoutConstraint.activate([
            notificationTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notificationTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notificationTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            notificationTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Configurazione Notifica New Post
    private func configureNewPostNotification(notification: NotificationModel) {
        // Crea una stack view per organizzare immagine e testo orizzontalmente
        let horizontalStackView = UIStackView()
        horizontalStackView.axis = .horizontal
        horizontalStackView.alignment = .top // Allineamento in alto
        horizontalStackView.spacing = 16 // Spazio tra immagine e testo
        horizontalStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(horizontalStackView)
        
        // Configura l'immagine del post (se esiste)
        if let imageUrl = notification.postImageUrl, let url = URL(string: imageUrl) {
            let postImageView = UIImageView()
            postImageView.contentMode = .scaleAspectFill
            postImageView.clipsToBounds = true
            postImageView.layer.cornerRadius = 10
            postImageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Caricamento immagine
            postImageView.loadImage(from: url)
            
            // Imposta le dimensioni dell'immagine
            NSLayoutConstraint.activate([
                postImageView.widthAnchor.constraint(equalToConstant: 100),
                postImageView.heightAnchor.constraint(equalToConstant: 100)
            ])
            
            // Aggiungi l'immagine alla stack view
            horizontalStackView.addArrangedSubview(postImageView)
        }
        
        // Configura il testo della notifica
        let label = UILabel()
        if let username = notification.username {
            let attributedText = NSMutableAttributedString()
            
            // Aggiungi il nome dell'utente in grassetto e blu
            attributedText.append(NSAttributedString(
                string: username,
                attributes: [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.blue
                ]
            ))
            
            // Aggiungi il resto del testo normale
            attributedText.append(NSAttributedString(
                string: " posted a new image",
                attributes: [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
            ))
            
            label.attributedText = attributedText
        } else {
            label.text = "You posted a new image"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .black
        }
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // Aggiungi il label alla stack view
        horizontalStackView.addArrangedSubview(label)
        
        // Imposta i vincoli della stack view
        NSLayoutConstraint.activate([
            horizontalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            horizontalStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            horizontalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            horizontalStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - UITextViewDelegate
   
    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "userId", let userId = URL.host {
            delegate?.didTapUsername(username: userId) // Passa userId al delegate
            return false
        }
        return true
    }
}

extension UIImageView {
    func loadImage(from url: URL) {
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = image
                }
            }
        }
    }
}
