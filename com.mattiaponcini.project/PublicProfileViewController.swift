//
//  PublicProfileViewController.swift
//  Flotip
//
//  Profilo pubblico di un altro utente in stile TikTok:
//
//   ┌────────────────────────────────────────────────┐
//   │ [<]   @handle                                  │  custom nav bar
//   │                                                │
//   │                  ⚪⚪⚪                         │  avatar centrato (anello oro)
//   │                                                │
//   │                @handle                         │
//   │             Mattia Poncini                     │
//   │           bio multi-line, centrata             │
//   │                                                │
//   │     12        4         128                    │  3 stat row
//   │  Following  Followers  Likes                   │
//   │                                                │
//   │  [ Segui ]    [ Messaggia ]                    │  CTA primary + secondary
//   │                                                │
//   │  ───────────  ▦  ───────────                   │  underline (1 tab)
//   │                                                │
//   │  ┌──┬──┬──┐                                    │
//   │  │9 │16│  │                                    │
//   │  └──┴──┴──┘                                    │
//   └────────────────────────────────────────────────┘
//
//  Riusa `ProfileTikTokGridCell` (definita in ProfileViewController.swift).
//  Tap su Following/Followers → sheet con lista profili (stesso pattern
//  del profilo personale).
//

import UIKit
import os.log
import FirebaseAuth
import FirebaseFirestore

private let publicProfLog = OSLog(subsystem: "com.mattiaponcini.project", category: "PublicProfileVC")

final class PublicProfileViewController: UIViewController {

    // MARK: - Input

    private let profile: UserProfile

    // MARK: - State

    private var posts: [Post] = []
    private var postsListener: ListenerRegistration?
    private var followListener: ListenerRegistration?
    private var followRequestListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?
    private var followingListener: ListenerRegistration?
    private var followersCount: Int? = nil
    private var followingCount: Int? = nil
    private var totalLikes: Int? = nil
    private var likesLoadToken: UUID?

    /// Tre stati possibili per il bottone follow sul profilo pubblico:
    /// - `.notFollowing`: non seguo; tap → invia richiesta.
    /// - `.requested`: ho una richiesta pending; tap → cancella richiesta.
    /// - `.following`: follow accettato; tap → unfollow.
    enum FollowButtonState { case notFollowing, requested, following }
    private var isFollowing: Bool = false { didSet { updateActionButtons() } }
    private var hasPendingRequest: Bool = false { didSet { updateActionButtons() } }
    private var followState: FollowButtonState {
        if isFollowing { return .following }
        if hasPendingRequest { return .requested }
        return .notFollowing
    }
    private var myProfile: UserProfile?

    private var myUid: String { Auth.auth().currentUser?.uid ?? "" }
    private var otherUid: String { profile.id ?? "" }

    // MARK: - Layout kinds (riusati dallo stesso namespace per coerenza)

    static let infoHeaderKind = "PublicProfileInfoHeaderKind"
    static let tabBarKind     = "PublicProfileTabBarKind"

    // MARK: - UI

    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: "chevron.left",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)),
                   for: .normal)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let topBarTitle: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let topBarSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .Brand.goldPrimary
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let emptyOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let emptyIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "square.grid.3x3",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 48, weight: .light))
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyTitle: UILabel = {
        let l = UILabel()
        l.text = "Nessun post"
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    init(profile: UserProfile) {
        self.profile = profile
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        topBarTitle.text = "@\(ProfileHandle.handle(for: profile))"
        setupTopBar()
        setupCollectionView()
        setupEmptyOverlay()
        setupRefreshControl()
        wireActions()
        startObservingPosts()
        startObservingFollow()
        startObservingFollowCounts()
        loadMyProfile()
        refreshTotalLikes()
    }

    deinit {
        postsListener?.remove()
        followListener?.remove()
        followRequestListener?.remove()
        followersListener?.remove()
        followingListener?.remove()
    }

    // MARK: - Layout

    private func setupTopBar() {
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(topBarTitle)
        view.addSubview(topBarSeparator)
        view.addSubview(activityIndicator)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),

            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 12),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),

            topBarTitle.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            topBarTitle.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),

            topBarSeparator.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            topBarSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 24)
        ])
    }

    private func setupCollectionView() {
        let layout = makeCompositionalLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ProfileTikTokGridCell.self,
                                forCellWithReuseIdentifier: ProfileTikTokGridCell.reuseID)
        collectionView.register(PublicProfileTikTokHeaderView.self,
                                forSupplementaryViewOfKind: Self.infoHeaderKind,
                                withReuseIdentifier: PublicProfileTikTokHeaderView.reuseID)
        collectionView.register(PublicProfileTabUnderlineView.self,
                                forSupplementaryViewOfKind: Self.tabBarKind,
                                withReuseIdentifier: PublicProfileTabUnderlineView.reuseID)
        collectionView.contentInsetAdjustmentBehavior = .never
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: topBarSeparator.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeCompositionalLayout() -> UICollectionViewLayout {
        let infoHeader = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(440)
            ),
            elementKind: Self.infoHeaderKind,
            alignment: .top
        )

        let tabBar = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(46)
            ),
            elementKind: Self.tabBarKind,
            alignment: .top
        )
        tabBar.pinToVisibleBounds = true
        tabBar.zIndex = 2

        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            if sectionIndex == 0 {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(0.0001)
                ))
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .absolute(0.0001)
                    ),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [infoHeader]
                return section
            } else {
                let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0/3.0),
                    heightDimension: .fractionalHeight(1.0)
                ))
                item.contentInsets = NSDirectionalEdgeInsets(
                    top: 0.5, leading: 0.5, bottom: 0.5, trailing: 0.5
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1.0),
                        heightDimension: .fractionalWidth(16.0/27.0)
                    ),
                    subitems: [item]
                )
                let section = NSCollectionLayoutSection(group: group)
                section.boundarySupplementaryItems = [tabBar]
                return section
            }
        }
    }

    private func setupEmptyOverlay() {
        view.addSubview(emptyOverlay)
        emptyOverlay.addSubview(emptyIcon)
        emptyOverlay.addSubview(emptyTitle)
        NSLayoutConstraint.activate([
            emptyOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emptyOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emptyOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40),

            emptyIcon.topAnchor.constraint(equalTo: emptyOverlay.topAnchor),
            emptyIcon.centerXAnchor.constraint(equalTo: emptyOverlay.centerXAnchor),
            emptyIcon.widthAnchor.constraint(equalToConstant: 56),
            emptyIcon.heightAnchor.constraint(equalToConstant: 56),

            emptyTitle.topAnchor.constraint(equalTo: emptyIcon.bottomAnchor, constant: 16),
            emptyTitle.leadingAnchor.constraint(equalTo: emptyOverlay.leadingAnchor),
            emptyTitle.trailingAnchor.constraint(equalTo: emptyOverlay.trailingAnchor),
            emptyTitle.bottomAnchor.constraint(equalTo: emptyOverlay.bottomAnchor)
        ])
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = .Brand.goldPrimary
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func wireActions() {
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
    }

    // MARK: - Data

    private func loadMyProfile() {
        AuthService.shared.fetchCurrentUserProfile { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let p) = result { self?.myProfile = p }
            }
        }
    }

    private func startObservingPosts() {
        postsListener?.remove()
        guard !otherUid.isEmpty else { return }
        let db = Firestore.firestore()
        postsListener = db.collection("posts")
            .whereField("authorId", isEqualTo: otherUid)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    os_log("posts listener error: %{public}@",
                           log: publicProfLog, type: .error, error.localizedDescription)
                    DispatchQueue.main.async {
                        self.posts = []
                        self.reloadAll()
                    }
                    return
                }
                let parsed: [Post] = snapshot?.documents.compactMap {
                    try? $0.data(as: Post.self)
                } ?? []
                DispatchQueue.main.async {
                    self.posts = parsed
                    self.reloadAll()
                }
            }
    }

    private func startObservingFollow() {
        followListener?.remove()
        followRequestListener?.remove()
        guard !otherUid.isEmpty else { return }
        followListener = FollowService.shared.observeIsFollowing(otherUid) {
            [weak self] following in
            DispatchQueue.main.async {
                self?.isFollowing = following
            }
        }
        followRequestListener = FollowService.shared.observeFollowRequest(to: otherUid) {
            [weak self] pending in
            DispatchQueue.main.async {
                self?.hasPendingRequest = pending
            }
        }
    }

    private func startObservingFollowCounts() {
        followersListener?.remove()
        followingListener?.remove()
        guard !otherUid.isEmpty else { return }
        followersListener = FollowService.shared.observeFollowersCount(for: otherUid) {
            [weak self] n in
            DispatchQueue.main.async {
                self?.followersCount = n
                self?.reloadHeader()
            }
        }
        followingListener = FollowService.shared.observeFollowingCount(for: otherUid) {
            [weak self] n in
            DispatchQueue.main.async {
                self?.followingCount = n
                self?.reloadHeader()
            }
        }
    }

    private func refreshTotalLikes() {
        guard !otherUid.isEmpty else { return }
        let token = UUID()
        likesLoadToken = token
        totalLikes = nil
        reloadHeader()
        PostService.shared.fetchTotalLikesCount(for: otherUid) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.likesLoadToken == token else { return }
                switch result {
                case .success(let n): self.totalLikes = n
                case .failure(let err):
                    NSLog("[PublicProfileVC] fetchTotalLikesCount: \(err.localizedDescription)")
                    self.totalLikes = 0
                }
                self.reloadHeader()
            }
        }
    }

    // MARK: - Reload

    private func reloadHeader() {
        if let header = collectionView.supplementaryView(
            forElementKind: Self.infoHeaderKind, at: IndexPath(item: 0, section: 0))
            as? PublicProfileTikTokHeaderView {
            header.configure(with: makeHeaderModel())
        }
        collectionView.collectionViewLayout.invalidateLayout()
    }

    private func reloadAll() {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
        emptyOverlay.isHidden = !posts.isEmpty
    }

    private func updateActionButtons() {
        if let header = collectionView.supplementaryView(
            forElementKind: Self.infoHeaderKind, at: IndexPath(item: 0, section: 0))
            as? PublicProfileTikTokHeaderView {
            header.setFollowState(followState, animated: true)
        }
    }

    private func makeHeaderModel() -> PublicProfileTikTokHeaderView.Model {
        return PublicProfileTikTokHeaderView.Model(
            profile: profile,
            handle: ProfileHandle.handle(for: profile),
            followingCount: followingCount,
            followersCount: followersCount,
            totalLikes: totalLikes,
            followState: followState
        )
    }

    // MARK: - Actions

    @objc private func handleBack() {
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.30
            transition.type = .push
            transition.subtype = .fromLeft
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        dismiss(animated: false)
    }

    @objc private func handleRefresh() {
        refreshTotalLikes()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    fileprivate func handleFollowToggle() {
        guard !otherUid.isEmpty else { return }
        let previousState = followState
        // Optimistic UI: anticipiamo il prossimo stato in base a quello attuale.
        switch previousState {
        case .notFollowing:
            // notFollowing → requested (creiamo richiesta)
            hasPendingRequest = true
        case .requested:
            // requested → notFollowing (cancelliamo richiesta)
            hasPendingRequest = false
        case .following:
            // following → notFollowing (unfollow vero)
            isFollowing = false
        }

        let onResult: (Result<Void, Error>) -> Void = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success:
                    break
                case .failure(let error):
                    os_log("follow toggle failed: %{public}@",
                           log: publicProfLog, type: .error, error.localizedDescription)
                    // Rollback optimistic state.
                    switch previousState {
                    case .notFollowing: self.hasPendingRequest = false
                    case .requested:    self.hasPendingRequest = true
                    case .following:    self.isFollowing = true
                    }
                    let alert = UIAlertController(
                        title: "Errore",
                        message: "Operazione non riuscita: \(error.localizedDescription)\n\nVerifica le regole Firestore: per le richieste di follow servono permessi su users/{uid}/followRequests.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }

        switch previousState {
        case .notFollowing:
            FollowService.shared.requestFollow(otherUid, completion: onResult)
        case .requested:
            FollowService.shared.cancelFollowRequest(otherUid, completion: onResult)
        case .following:
            FollowService.shared.unfollow(otherUid, completion: onResult)
        }
    }

    fileprivate func handleMessageTap() {
        guard let me = myProfile else {
            AuthService.shared.fetchCurrentUserProfile { [weak self] result in
                DispatchQueue.main.async {
                    if case .success(let p) = result {
                        self?.myProfile = p
                        self?.handleMessageTap()
                    }
                }
            }
            return
        }
        ChatService.shared.findOrCreateConversation(with: profile, myProfile: me) {
            [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let conv):
                    let thread = ChatThreadViewController(conversation: conv)
                    thread.modalPresentationStyle = .fullScreen
                    if let window = self.view.window {
                        let transition = CATransition()
                        transition.duration = 0.30
                        transition.type = .push
                        transition.subtype = .fromRight
                        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        window.layer.add(transition, forKey: kCATransition)
                    }
                    self.present(thread, animated: false)
                case .failure(let error):
                    os_log("findOrCreateConversation failed: %{public}@",
                           log: publicProfLog, type: .error, error.localizedDescription)
                    let alert = UIAlertController(
                        title: "Errore",
                        message: "Impossibile aprire la chat.\n\n\(error.localizedDescription)",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    fileprivate func handleFollowingTap() {
        guard !otherUid.isEmpty else { return }
        let uid = otherUid
        let vc = FollowListViewController(title: "Seguiti") { completion in
            FollowService.shared.fetchFollowingProfiles(for: uid, completion: completion)
        }
        present(vc, animated: true)
    }

    fileprivate func handleFollowersTap() {
        guard !otherUid.isEmpty else { return }
        let uid = otherUid
        let vc = FollowListViewController(title: "Follower") { completion in
            FollowService.shared.fetchFollowersProfiles(for: uid, completion: completion)
        }
        present(vc, animated: true)
    }

    fileprivate func openPostAt(_ indexPath: IndexPath) {
        guard indexPath.item < posts.count else { return }
        let detail = PostDetailViewController(post: posts[indexPath.item])
        detail.modalPresentationStyle = .fullScreen
        present(detail, animated: true)
    }
}

// MARK: - Data source / delegate

extension PublicProfileViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return 0 }
        return posts.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ProfileTikTokGridCell.reuseID,
            for: indexPath) as! ProfileTikTokGridCell
        // Grid 3-colonne: usiamo la thumb 1080px se disponibile
        // (vedi `Post.previewImageURL`), fallback all'originale per i
        // post legacy / appena pubblicati.
        cell.configure(imageURL: posts[indexPath.item].previewImageURL,
                       likesCount: nil,
                       showOverlay: true)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == Self.infoHeaderKind {
            let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: PublicProfileTikTokHeaderView.reuseID,
                for: indexPath) as! PublicProfileTikTokHeaderView
            header.configure(with: makeHeaderModel())
            header.onFollowTap = { [weak self] in self?.handleFollowToggle() }
            header.onMessageTap = { [weak self] in self?.handleMessageTap() }
            header.onFollowingTap = { [weak self] in self?.handleFollowingTap() }
            header.onFollowersTap = { [weak self] in self?.handleFollowersTap() }
            return header
        } else {
            let bar = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: PublicProfileTabUnderlineView.reuseID,
                for: indexPath) as! PublicProfileTabUnderlineView
            return bar
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        openPostAt(indexPath)
    }
}

// MARK: - PublicProfileTikTokHeaderView

/// Header del profilo pubblico in stile TikTok: avatar centrato + handle +
/// nome + bio + 3 stat (Following / Followers / Likes) + Follow / Messaggia.
final class PublicProfileTikTokHeaderView: UICollectionReusableView {

    static let reuseID = "PublicProfileTikTokHeaderView"

    struct Model {
        var profile: UserProfile
        var handle: String
        var followingCount: Int?
        var followersCount: Int?
        var totalLikes: Int?
        var followState: PublicProfileViewController.FollowButtonState
    }

    var onFollowTap: (() -> Void)?
    var onMessageTap: (() -> Void)?
    var onFollowingTap: (() -> Void)?
    var onFollowersTap: (() -> Void)?

    private let avatarRing: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.borderWidth = 2.5
        v.layer.borderColor = UIColor.Brand.goldPrimary.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .Brand.creamSurface
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = .Brand.goldSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let handleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .Brand.goldPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bioLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let followingStat = TikTokStatButton(label: "Following")
    private let followersStat = TikTokStatButton(label: "Followers")
    private let likesStat     = TikTokStatButton(label: "Likes")

    private let statSep1: UIView = { let v = UIView(); v.backgroundColor = .Brand.creamBorder; v.translatesAutoresizingMaskIntoConstraints = false; return v }()
    private let statSep2: UIView = { let v = UIView(); v.backgroundColor = .Brand.creamBorder; v.translatesAutoresizingMaskIntoConstraints = false; return v }()

    private let followButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let messageButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Messaggia", for: .normal)
        b.setTitleColor(.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        b.backgroundColor = .Brand.creamSurface
        b.layer.cornerRadius = 8
        b.layer.cornerCurve = .continuous
        b.layer.borderWidth = 0.5
        b.layer.borderColor = UIColor.Brand.creamBorder.cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var actionsRow: UIStackView!

    private var lastPhotoURL: String?
    private static let avatarSize: CGFloat = 96

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        setupLayout()
        followButton.addTarget(self, action: #selector(handleFollow), for: .touchUpInside)
        messageButton.addTarget(self, action: #selector(handleMessage), for: .touchUpInside)
        followingStat.addTarget(self, action: #selector(handleFollowingStat), for: .touchUpInside)
        followersStat.addTarget(self, action: #selector(handleFollowersStat), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupLayout() {
        addSubview(avatarRing)
        avatarRing.addSubview(avatarImageView)
        addSubview(handleLabel)
        addSubview(nameLabel)
        addSubview(bioLabel)

        let statsRow = UIView()
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        statsRow.addSubview(followingStat)
        statsRow.addSubview(statSep1)
        statsRow.addSubview(followersStat)
        statsRow.addSubview(statSep2)
        statsRow.addSubview(likesStat)
        addSubview(statsRow)

        actionsRow = UIStackView(arrangedSubviews: [followButton, messageButton])
        actionsRow.axis = .horizontal
        actionsRow.spacing = 8
        actionsRow.distribution = .fillEqually
        actionsRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionsRow)

        let ringSize = Self.avatarSize + 8

        NSLayoutConstraint.activate([
            avatarRing.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            avatarRing.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatarRing.widthAnchor.constraint(equalToConstant: ringSize),
            avatarRing.heightAnchor.constraint(equalToConstant: ringSize),

            avatarImageView.centerXAnchor.constraint(equalTo: avatarRing.centerXAnchor),
            avatarImageView.centerYAnchor.constraint(equalTo: avatarRing.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: Self.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: Self.avatarSize),

            handleLabel.topAnchor.constraint(equalTo: avatarRing.bottomAnchor, constant: 12),
            handleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            handleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            nameLabel.topAnchor.constraint(equalTo: handleLabel.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            bioLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            bioLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),

            statsRow.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 16),
            statsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            statsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            statsRow.heightAnchor.constraint(equalToConstant: 48),

            followingStat.leadingAnchor.constraint(equalTo: statsRow.leadingAnchor),
            followingStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            followingStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),

            statSep1.leadingAnchor.constraint(equalTo: followingStat.trailingAnchor),
            statSep1.centerYAnchor.constraint(equalTo: statsRow.centerYAnchor),
            statSep1.widthAnchor.constraint(equalToConstant: 0.5),
            statSep1.heightAnchor.constraint(equalToConstant: 28),

            followersStat.leadingAnchor.constraint(equalTo: statSep1.trailingAnchor),
            followersStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            followersStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),
            followersStat.widthAnchor.constraint(equalTo: followingStat.widthAnchor),

            statSep2.leadingAnchor.constraint(equalTo: followersStat.trailingAnchor),
            statSep2.centerYAnchor.constraint(equalTo: statsRow.centerYAnchor),
            statSep2.widthAnchor.constraint(equalToConstant: 0.5),
            statSep2.heightAnchor.constraint(equalToConstant: 28),

            likesStat.leadingAnchor.constraint(equalTo: statSep2.trailingAnchor),
            likesStat.trailingAnchor.constraint(equalTo: statsRow.trailingAnchor),
            likesStat.topAnchor.constraint(equalTo: statsRow.topAnchor),
            likesStat.bottomAnchor.constraint(equalTo: statsRow.bottomAnchor),
            likesStat.widthAnchor.constraint(equalTo: followingStat.widthAnchor),

            actionsRow.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: 16),
            actionsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            actionsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionsRow.heightAnchor.constraint(equalToConstant: 36),
            actionsRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])

        avatarRing.layer.cornerRadius = (Self.avatarSize + 8) / 2
        avatarImageView.layer.cornerRadius = Self.avatarSize / 2
    }

    func configure(with model: Model) {
        handleLabel.text = "@\(model.handle)"
        nameLabel.text = model.profile.fullName.isEmpty ? "Profilo" : model.profile.fullName
        if let bio = model.profile.bio,
           !bio.trimmingCharacters(in: .whitespaces).isEmpty {
            bioLabel.text = bio
            bioLabel.isHidden = false
        } else {
            bioLabel.text = nil
            bioLabel.isHidden = true
        }
        followingStat.setValueText(model.followingCount.map(ProfileHandle.compactCount) ?? "—")
        followersStat.setValueText(model.followersCount.map(ProfileHandle.compactCount) ?? "—")
        likesStat.setValueText(model.totalLikes.map(ProfileHandle.compactCount) ?? "—")
        loadAvatar(from: model.profile.photoURL)
        setFollowState(model.followState, animated: false)
    }

    /// Aggiorna l'aspetto del bottone follow + visibilità del bottone messaggia
    /// in base allo stato (3 valori). Il bottone messaggia compare solo a
    /// follow accettato — finché siamo in pending o non-follow, non ha senso
    /// chattare con un utente che non ti ha ancora aggiunto.
    func setFollowState(_ state: PublicProfileViewController.FollowButtonState,
                        animated: Bool) {
        let title: String
        let bg: UIColor
        let fg: UIColor
        let borderWidth: CGFloat
        let messageHidden: Bool

        switch state {
        case .notFollowing:
            title = "Segui"
            bg = .Brand.goldPrimary
            fg = .white
            borderWidth = 0
            messageHidden = true
        case .requested:
            title = "Richiesta inviata"
            bg = .Brand.creamSurface
            fg = .secondaryLabel
            borderWidth = 0.5
            messageHidden = true
        case .following:
            title = "Smetti di seguire"
            bg = .Brand.creamSurface
            fg = .label
            borderWidth = 0.5
            messageHidden = false
        }

        let block = {
            self.followButton.setTitle(title, for: .normal)
            self.followButton.backgroundColor = bg
            self.followButton.tintColor = fg
            self.followButton.setTitleColor(fg, for: .normal)
            self.followButton.layer.borderWidth = borderWidth
            self.followButton.layer.borderColor = UIColor.Brand.creamBorder.cgColor
            self.messageButton.isHidden = messageHidden
        }
        if animated {
            UIView.animate(withDuration: 0.18, animations: block)
        } else {
            block()
        }
    }

    private func loadAvatar(from urlString: String?) {
        guard let s = urlString, !s.isEmpty, let url = URL(string: s) else {
            avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarImageView.tintColor = .Brand.goldSecondary
            return
        }
        if lastPhotoURL == s, avatarImageView.image != nil { return }
        lastPhotoURL = s
        if let cached = ImageCache.shared.cachedImage(for: url) {
            avatarImageView.image = cached
            return
        }
        ImageCache.shared.loadImage(from: url) { [weak self] image in
            guard let self = self,
                  self.lastPhotoURL == s,
                  let image = image else { return }
            self.avatarImageView.image = image
        }
    }

    @objc private func handleFollow() { onFollowTap?() }
    @objc private func handleMessage() { onMessageTap?() }
    @objc private func handleFollowingStat() { onFollowingTap?() }
    @objc private func handleFollowersStat() { onFollowersTap?() }
}

// MARK: - PublicProfileTabUnderlineView

/// Singola "tab" stile TikTok per il profilo pubblico: solo l'icona post +
/// underline statico. Niente switch perché mostriamo solo i post pubblici.
final class PublicProfileTabUnderlineView: UICollectionReusableView {

    static let reuseID = "PublicProfileTabUnderlineView"

    private let icon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "square.grid.3x3",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
        iv.tintColor = .label
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let topSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let underline: UIView = {
        let v = UIView()
        v.backgroundColor = .label
        v.layer.cornerRadius = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let bottomSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.creamBorder
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .systemBackground
        addSubview(topSeparator)
        addSubview(icon)
        addSubview(underline)
        addSubview(bottomSeparator)
        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 22),

            underline.centerXAnchor.constraint(equalTo: centerXAnchor),
            underline.bottomAnchor.constraint(equalTo: bottomSeparator.topAnchor),
            underline.heightAnchor.constraint(equalToConstant: 2),
            underline.widthAnchor.constraint(equalToConstant: 60),

            bottomSeparator.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomSeparator.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomSeparator.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomSeparator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
