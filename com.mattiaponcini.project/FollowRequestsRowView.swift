//
//  FollowRequestsRowView.swift
//  Flotip
//
//  Sezione "Notifiche" della Libreria. Carosello orizzontale che mostra le
//  richieste di follow in pending: per ogni richiesta una card con avatar +
//  testo "[Nome] vuole seguirti" + due bottoni inline Accetta / Rifiuta.
//
//  Stile coerente con `LibraryItemsRowView` (titolo grande + collection
//  horizontal scroll), ma con cella `FollowRequestCardCell` custom invece
//  che `LibraryCoverCell`.
//
//  La sezione resta SEMPRE visibile in cima allo stack della Libreria,
//  con header "Notifiche" e riga di altezza fissa. Quando non ci sono
//  richieste pending viene mostrato un placeholder testuale minimal
//  ("Nessuna nuova notifica") al centro dell'area carosello, così
//  l'utente vede comunque la sezione e capisce dove arriveranno le
//  notifiche future.
//

import UIKit

// MARK: - FollowRequestsRowView

final class FollowRequestsRowView: UIView,
                                   UICollectionViewDataSource,
                                   UICollectionViewDelegate,
                                   UICollectionViewDelegateFlowLayout {

    /// Tap su Accetta su una card. Il controller chiama
    /// `FollowService.acceptFollowRequest`.
    var onAccept: ((UserProfile) -> Void)?
    /// Tap su Rifiuta su una card. Il controller chiama
    /// `FollowService.rejectFollowRequest`.
    var onReject: ((UserProfile) -> Void)?
    /// Tap su avatar/testo della card → apre il PublicProfileViewController
    /// del requester.
    var onSelectProfile: ((UserProfile) -> Void)?

    // MARK: - UI

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Notifiche"
        l.font = .systemFont(ofSize: 28, weight: .bold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let collectionView: UICollectionView

    /// Placeholder mostrato al centro dell'area carosello quando non ci
    /// sono richieste pending. La row resta a piena altezza e l'header
    /// "Notifiche" rimane visibile, così la sezione non "sparisce" mai.
    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "Nessuna nuova notifica"
        l.font = .preferredFont(forTextStyle: .footnote)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = false   // di default partiamo vuoti finché non arriva uno snapshot
        return l
    }()

    // MARK: - Data

    private var profiles: [UserProfile] = []

    // MARK: - Init

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: frame)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FollowRequestCardCell.self,
                                forCellWithReuseIdentifier: FollowRequestCardCell.reuseID)

        addSubview(titleLabel)
        addSubview(collectionView)
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: Self.cardHeight),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Empty label centrata sull'area del carosello (stesso rect della
            // collectionView). La row mantiene altezza fissa anche da vuota.
            emptyLabel.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            emptyLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - API

    /// Sostituisce la lista dei requester. La riga resta sempre nello stack
    /// del controller padre: quando la lista è vuota mostriamo un placeholder
    /// testuale al centro dell'area carosello (vedi `emptyLabel`).
    func setRequesters(_ profiles: [UserProfile]) {
        self.profiles = profiles
        emptyLabel.isHidden = !profiles.isEmpty
        collectionView.reloadData()
    }

    // MARK: - Layout constants

    /// Larghezza della card. Volutamente più larga di una copertina libro
    /// per ospitare avatar + testo a 2 righe + due bottoni inline.
    private static let cardWidth: CGFloat = 260
    /// Altezza fissa della collectionView e delle card.
    static let cardHeight: CGFloat = 130

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return profiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FollowRequestCardCell.reuseID,
            for: indexPath) as! FollowRequestCardCell
        let profile = profiles[indexPath.item]
        cell.configure(with: profile)
        cell.onAccept = { [weak self] in self?.onAccept?(profile) }
        cell.onReject = { [weak self] in self?.onReject?(profile) }
        cell.onSelectProfile = { [weak self] in self?.onSelectProfile?(profile) }
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: Self.cardWidth, height: Self.cardHeight)
    }
}

// MARK: - FollowRequestCardCell

/// Cella card per una singola richiesta di follow.
///
/// Layout:
///   ┌────────────────────────────────────────┐
///   │  ⚪⚪   Mattia Poncini                   │
///   │  ⚪⚪   vuole seguirti                   │
///   │                                        │
///   │  [ Accetta ]   [ Rifiuta ]             │
///   └────────────────────────────────────────┘
///
/// Tap sull'area avatar/testo → callback `onSelectProfile` per aprire il
/// profilo pubblico del requester. I due bottoni hanno hit area dedicata
/// e non triggherano la callback `onSelectProfile`.
final class FollowRequestCardCell: UICollectionViewCell {

    static let reuseID = "FollowRequestCardCell"

    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?
    var onSelectProfile: (() -> Void)?

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamSurface
        v.layer.cornerRadius = 14
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 0.5
        v.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamBorder
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .label
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "vuole seguirti"
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let acceptButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Accetta", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.tintColor = .white
        b.backgroundColor = .Brand.goldPrimary
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let rejectButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Rifiuta", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        b.setTitleColor(.label, for: .normal)
        b.tintColor = .label
        b.backgroundColor = .systemBackground
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    /// Area sensibile al tap che copre avatar + testo, ma NON i bottoni
    /// (i bottoni gestiscono il proprio touch dentro `addTarget`). Senza
    /// questo overlay un tap sull'avatar non veniva intercettato perché
    /// le UIImageView/UILabel hanno `isUserInteractionEnabled = false` di
    /// default e il tap finiva nel `card` background, dove non c'è handler.
    private let tapOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var currentAvatarURL: URL?
    private var avatarTask: URLSessionDataTask?

    private static let avatarSize: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(card)
        card.addSubview(avatarImageView)
        card.addSubview(nameLabel)
        card.addSubview(subtitleLabel)
        card.addSubview(acceptButton)
        card.addSubview(rejectButton)
        card.addSubview(tapOverlay)

        // Tap overlay sopra avatar/testo apre il profilo pubblico.
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleProfileTap))
        tapOverlay.addGestureRecognizer(tap)

        acceptButton.addTarget(self, action: #selector(handleAccept), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(handleReject), for: .touchUpInside)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            avatarImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            nameLabel.topAnchor.constraint(equalTo: avatarImageView.topAnchor, constant: 2),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            // Bottoni inline allineati a baseline orizzontale, ancorati in basso.
            acceptButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            acceptButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            acceptButton.heightAnchor.constraint(equalToConstant: 32),
            acceptButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 78),

            rejectButton.leadingAnchor.constraint(equalTo: acceptButton.trailingAnchor, constant: 8),
            rejectButton.centerYAnchor.constraint(equalTo: acceptButton.centerYAnchor),
            rejectButton.heightAnchor.constraint(equalToConstant: 32),
            rejectButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 78),
            rejectButton.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -14),

            // Overlay copre avatar + testo (parte alta), NON i bottoni.
            tapOverlay.topAnchor.constraint(equalTo: card.topAnchor),
            tapOverlay.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            tapOverlay.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            tapOverlay.bottomAnchor.constraint(equalTo: acceptButton.topAnchor, constant: -4)
        ])

        avatarImageView.layer.cornerRadius = Self.avatarSize / 2
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .Brand.goldSecondary
        currentAvatarURL = nil
        avatarTask?.cancel()
        avatarTask = nil
        onAccept = nil
        onReject = nil
        onSelectProfile = nil
    }

    func configure(with profile: UserProfile) {
        let displayName = profile.fullName.trimmingCharacters(in: .whitespaces)
        nameLabel.text = displayName.isEmpty
            ? "@\(ProfileHandle.handle(for: profile))"
            : displayName
        loadAvatar(from: profile.photoURL)
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .Brand.goldSecondary
            currentAvatarURL = nil
            return
        }
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarImageView.image = cached
            currentAvatarURL = url
            return
        }
        currentAvatarURL = url
        avatarTask = ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.currentAvatarURL == url,
                  let image = image else { return }
            self.avatarImageView.image = image
        }
    }

    @objc private func handleAccept() { onAccept?() }
    @objc private func handleReject() { onReject?() }
    @objc private func handleProfileTap() { onSelectProfile?() }
}
