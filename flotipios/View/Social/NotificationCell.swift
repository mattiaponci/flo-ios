import UIKit



class NotificationCell: UITableViewCell, UITextViewDelegate {
    
    // MARK: - Proprietà
    
    weak var delegate: NotificationCellDelegate?
    
    private lazy var notificationTextView: UITextView = {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isUserInteractionEnabled = true
        textView.isScrollEnabled = false
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textColor = .black
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.blue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        textView.delegate = self
        return textView
    }()
    
    private var username: String?

    // MARK: - Inizializzazione
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupTextView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configurazione UI
    
    private func setupTextView() {
        selectionStyle = .none
        backgroundColor = .white
        contentView.addSubview(notificationTextView)
        
        notificationTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            notificationTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notificationTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notificationTextView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            notificationTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Configurazione Contenuto

    func configure(with notification: (username: String, userId: String)) {
        self.username = notification.username
        let text = "You started to follow "
        let attributedString = NSMutableAttributedString(string: text)
        
        let link = NSAttributedString(string: notification.username, attributes: [
            .link: URL(string: "userId://\(notification.userId)")!, // Use userId in the URL
            .foregroundColor: UIColor.blue,
            .font: UIFont.boldSystemFont(ofSize: 14),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        
        attributedString.append(link)
        notificationTextView.attributedText = attributedString
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView,
                  shouldInteractWith URL: URL,
                  in characterRange: NSRange,
                  interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "userId", let userId = URL.host {
            delegate?.didTapUsername(username: userId) // Pass userId instead of username
            return false
        }
        return true
    }
}
