//
//  LibraryHostViewController.swift
//  Flotip
//
//  Container in stile "TikTok feed tabs" che ospita due schermate
//  swipeabili orizzontalmente:
//
//      [ Libreria ]   [ Notifiche ]
//          ▔▔▔▔
//
//  - Sfondo bianco (systemBackground) coerente con il resto dell'app.
//  - Top bar custom con due tab centrate orizzontalmente.
//  - Tab attivo: testo `.label` (nero in light mode) semibold + indicatore
//    underline corto in colore brand (Brand.goldPrimary) sotto il tab.
//  - Tab non attivo: testo grigio (`.tertiaryLabel`) regular.
//  - Swipe orizzontale tra i due tab gestito da UIPageViewController
//    (transitionStyle .scroll). Durante lo swipe l'underline si muove
//    in tempo reale agganciandosi al progress dello scroll view interno
//    (KVO sul `contentOffset`).
//  - Tap su un tab → transizione animata morbida (ease-out 0.32s).
//  - Bottone close (chevron.left) in alto a sinistra: chiude il fullscreen
//    con la stessa animazione push-from-left usata oggi dalla Libreria.
//
//  Sostituisce il vecchio entry-point su LibraryViewController: ora la
//  Libreria è solo uno dei due child VC (quello di default).
//

import UIKit

final class LibraryHostViewController: UIViewController {

    /// Tab che il container può mostrare. L'ordine dei case definisce
    /// l'ordine visivo dei tab da sinistra a destra (e l'ordine di paging
    /// orizzontale nel UIPageViewController).
    enum Tab: Int, CaseIterable {
        case library = 0
        case notifications = 1

        var title: String {
            switch self {
            case .library:       return "Libreria"
            case .notifications: return "Notifiche"
            }
        }
    }

    // MARK: - Public API

    /// Tab da mostrare al primo `viewDidAppear`. Default `.library`.
    private let initialTab: Tab

    init(initialTab: Tab = .library) {
        self.initialTab = initialTab
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Children

    /// Manteniamo le istanze stabili per non ricaricare i listener Firestore
    /// ogni volta che si swippa.
    private lazy var notificationsVC: NotificationsViewController = NotificationsViewController()
    private lazy var libraryVC: LibraryViewController = {
        let vc = LibraryViewController()
        // Il dismiss della libreria è gestito dal container, non più dalla
        // child VC stessa.
        vc.embedsInHostContainer = true
        return vc
    }()

    /// Ordine dei child VC nel pager. DEVE coincidere con l'ordine dei case
    /// di `Tab`: Tab.library.rawValue = 0 (sinistra), Tab.notifications = 1
    /// (destra). Il `Tab.rawValue` è quindi l'indice in questo array.
    private var orderedChildren: [UIViewController] {
        return [libraryVC, notificationsVC]
    }

    // MARK: - Page VC

    private lazy var pageVC: UIPageViewController = {
        let vc = UIPageViewController(transitionStyle: .scroll,
                                      navigationOrientation: .horizontal,
                                      options: [UIPageViewController.OptionsKey.interPageSpacing: 0])
        vc.dataSource = self
        vc.delegate = self
        return vc
    }()

    /// Lo scroll view interno al UIPageViewController. Lo recuperiamo per
    /// osservarne il `contentOffset` e muovere l'underline in tempo reale
    /// durante il drag. UIPageViewController in modalità .scroll usa
    /// internamente una UIScrollView a "tre pagine" centrate sull'attuale.
    private weak var pageScrollView: UIScrollView?
    private var pageScrollObservation: NSKeyValueObservation?

    // MARK: - UI

    /// Bottone in alto a sinistra per chiudere il fullscreen.
    /// Stile coerente con il dismiss precedente di `LibraryViewController`:
    /// chevron a sinistra su pillola grigia chiara.
    private let dismissBtn: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = .label
        b.backgroundColor = UIColor.systemGray5
        b.layer.cornerRadius = 16
        b.layer.cornerCurve = .continuous
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    /// Container in alto: contiene i due tab + underline.
    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Stack orizzontale dei tab, centrato orizzontalmente nel topBar.
    private let tabsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.distribution = .fill
        s.spacing = 28
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    /// Una label per tab. Index in `orderedChildren` → label.
    private var tabLabels: [UILabel] = []

    /// Underline animato (3pt). Posizione/larghezza calcolate sul tab attivo
    /// e interpolate durante lo swipe. Su sfondo bianco usiamo il gold
    /// "scuro" (Brand.goldPrimary) per contrasto.
    private let underline: UIView = {
        let v = UIView()
        v.backgroundColor = .Brand.goldPrimary
        v.layer.cornerRadius = 1.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    /// Vincoli dinamici dell'underline (centro X + larghezza). Aggiornati
    /// quando cambia il tab attivo o durante il drag.
    private var underlineCenterX: NSLayoutConstraint!
    private var underlineWidth: NSLayoutConstraint!

    /// Container per il page view controller, sotto la top bar.
    private let pageContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - State

    /// Indice del tab attualmente "ancorato". Aggiornato a fine transizione
    /// (sia tap che swipe completato).
    private var currentIndex: Int = 0

    /// Flag per evitare callback ricorsive durante i tap programmatici.
    private var isProgrammaticPaging = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Sfondo bianco (systemBackground) coerente con LibraryViewController
        // standalone: l'utente vede i due tab e poi il contenuto della libreria
        // sullo stesso sfondo, senza salti cromatici durante lo swipe.
        view.backgroundColor = .systemBackground

        currentIndex = initialTab.rawValue
        setupLayout()
        setupTabs()
        setupPageVC()

        // Posizioniamo l'underline sul tab iniziale dopo che il layout è risolto.
        view.layoutIfNeeded()
        updateTabAppearance(activeIndex: currentIndex)
        updateUnderline(toIndex: CGFloat(currentIndex), animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // I tab hanno larghezze diverse a seconda del testo: ricalcoliamo
        // l'underline ogni volta che il layout cambia (rotazione, ecc.).
        updateUnderline(toIndex: CGFloat(currentIndex), animated: false)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        // Sfondo chiaro → testo scuro nella status bar (in light mode).
        return .default
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(topBar)
        topBar.addSubview(dismissBtn)
        topBar.addSubview(tabsStack)
        topBar.addSubview(underline)
        view.addSubview(pageContainer)

        dismissBtn.addTarget(self, action: #selector(handleDismiss), for: .touchUpInside)

        let safe = view.safeAreaLayoutGuide

        // Vincoli dinamici dell'underline: partiamo a 0/0, verranno
        // riassegnati al primo updateUnderline.
        underlineCenterX = underline.centerXAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 0)
        underlineWidth = underline.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: safe.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 52),

            dismissBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            dismissBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            dismissBtn.widthAnchor.constraint(equalToConstant: 32),
            dismissBtn.heightAnchor.constraint(equalToConstant: 32),

            tabsStack.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            tabsStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            tabsStack.heightAnchor.constraint(equalToConstant: 32),

            underline.topAnchor.constraint(equalTo: tabsStack.bottomAnchor, constant: 4),
            underline.heightAnchor.constraint(equalToConstant: 3),
            underlineCenterX,
            underlineWidth,

            pageContainer.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            pageContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTabs() {
        for (idx, tab) in Tab.allCases.enumerated() {
            let label = makeTabLabel(text: tab.title, index: idx)
            tabsStack.addArrangedSubview(label)
            tabLabels.append(label)
        }
    }

    private func makeTabLabel(text: String, index: Int) -> UILabel {
        let l = UILabel()
        l.text = text
        // Lo stato attivo/inattivo è gestito da `updateTabAppearance` che
        // anima font weight + textColor. Qui mettiamo i default (regular,
        // grigio) — verranno sovrascritti subito dopo viewDidLoad in base
        // al tab iniziale.
        l.font = .systemFont(ofSize: 17, weight: .regular)
        l.textColor = .tertiaryLabel
        l.textAlignment = .center
        l.isUserInteractionEnabled = true
        l.tag = index
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTabTap(_:)))
        l.addGestureRecognizer(tap)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func setupPageVC() {
        addChild(pageVC)
        pageContainer.addSubview(pageVC.view)
        pageVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageVC.view.topAnchor.constraint(equalTo: pageContainer.topAnchor),
            pageVC.view.leadingAnchor.constraint(equalTo: pageContainer.leadingAnchor),
            pageVC.view.trailingAnchor.constraint(equalTo: pageContainer.trailingAnchor),
            pageVC.view.bottomAnchor.constraint(equalTo: pageContainer.bottomAnchor)
        ])
        pageVC.didMove(toParent: self)

        // Pagina iniziale.
        let initialVC = orderedChildren[currentIndex]
        pageVC.setViewControllers([initialVC], direction: .forward, animated: false)

        // Per muovere l'underline in tempo reale durante il drag manuale
        // ascoltiamo il contentOffset della UIScrollView interna del
        // UIPageViewController via KVO. NOTA: NON sostituiamo il delegate
        // dello scroll view (UIPageViewController stesso lo usa
        // internamente per gestire la transizione di pagina); il KVO è
        // safe e non interferisce con il comportamento di paging.
        if let sv = pageVC.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            pageScrollView = sv
            pageScrollObservation = sv.observe(\.contentOffset, options: [.new]) {
                [weak self] scrollView, _ in
                self?.handlePageScroll(scrollView)
            }
        }
    }

    /// `UIPageViewController(.scroll)` usa una scroll view a 3 pagine: la
    /// pagina corrente è centrata, e l'offset durante un drag varia tra
    /// `(width)` (centro = pagina corrente) e `2*width` (drag verso destra,
    /// pagina successiva) o `0` (drag verso sinistra, pagina precedente).
    /// Convertiamo questo offset in un indice float `currentIndex ± delta`
    /// e lo passiamo all'underline così si muove proporzionalmente.
    private func handlePageScroll(_ scrollView: UIScrollView) {
        guard !isProgrammaticPaging else { return }
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }
        let delta = (scrollView.contentOffset.x - pageWidth) / pageWidth
        // Bound delta a [-1, 1] perché ai bordi il bounce può sforare.
        let clamped = max(-1.0, min(1.0, delta))
        let indicatorIndex = CGFloat(currentIndex) + clamped
        // Aggiorniamo senza animazione: stiamo seguendo il dito.
        updateUnderline(toIndex: indicatorIndex, animated: false)
    }

    // MARK: - Public tab switching

    /// Porta il container direttamente sul tab Notifiche, con la stessa
    /// animazione che userebbe un tap manuale sull'etichetta. Chiamato
    /// dall'AppDelegate quando l'utente tappa una push notification.
    func switchToNotificationsTab() {
        let target = Tab.notifications.rawValue
        guard target != currentIndex else { return }
        let direction: UIPageViewController.NavigationDirection = .forward
        let targetVC = orderedChildren[target]
        currentIndex = target
        isProgrammaticPaging = true
        pageVC.setViewControllers([targetVC], direction: direction, animated: true) { [weak self] _ in
            guard let self = self else { return }
            self.isProgrammaticPaging = false
            self.updateUnderline(toIndex: CGFloat(target), animated: false)
        }
        animateUnderline(toIndex: target)
        updateTabAppearance(activeIndex: target, animated: true)
    }

    // MARK: - Tab interactions

    @objc private func handleTabTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel else { return }
        let target = label.tag
        guard target != currentIndex else { return }
        guard target >= 0, target < orderedChildren.count else { return }

        let direction: UIPageViewController.NavigationDirection =
            (target > currentIndex) ? .forward : .reverse
        let targetVC = orderedChildren[target]

        // Aggiorniamo subito `currentIndex` così che eventuali callback
        // KVO sul contentOffset (durante la transizione programmatica)
        // calcolino il delta dal NUOVO indice, non dal vecchio. Senza
        // questo l'underline poteva "saltare" alla fine della transizione.
        currentIndex = target

        isProgrammaticPaging = true
        pageVC.setViewControllers([targetVC], direction: direction, animated: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.isProgrammaticPaging = false
            // Snap finale su `target` per coprire eventuali piccoli scarti.
            self.updateUnderline(toIndex: CGFloat(target), animated: false)
        }
        // L'underline e i colori dei tab li animiamo subito (non aspettiamo
        // la fine della transizione di pagina) → feedback visivo immediato.
        animateUnderline(toIndex: target)
        updateTabAppearance(activeIndex: target, animated: true)

        // Haptic leggero per dare un "tick" al cambio tab — coerente con
        // gli altri tap nell'app.
        let gen = UISelectionFeedbackGenerator()
        gen.selectionChanged()
    }

    @objc private func handleDismiss() {
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

    // MARK: - Underline placement

    /// Calcola il rect (in coordinate `topBar`) del label corrispondente al
    /// tab `index`, ritornando centerX e larghezza del testo. Usiamo
    /// `intrinsicContentSize.width` perché lo stack riempie verticalmente i
    /// label ma ne lascia la larghezza naturale → l'underline è corto come
    /// il testo (stile TikTok).
    private func tabMetrics(at index: Int) -> (centerX: CGFloat, width: CGFloat)? {
        guard index >= 0, index < tabLabels.count else { return nil }
        let label = tabLabels[index]
        // Forziamo un layout pass per avere frame attendibili.
        topBar.layoutIfNeeded()
        let frameInTopBar = label.convert(label.bounds, to: topBar)
        let textWidth = label.intrinsicContentSize.width
        let centerX = frameInTopBar.midX
        return (centerX, max(20, textWidth))
    }

    /// Aggiorna istantaneamente (o con animazione) la posizione/larghezza
    /// dell'underline sul tab `index`. Per `index` non intero interpola
    /// linearmente tra i due tab adiacenti — usato durante lo swipe.
    /// Quando `animated == false` (drag in corso) avvolgiamo l'aggiornamento
    /// in una `CATransaction` con animazioni disabilitate per evitare
    /// micro-jitter dovuti ad animazioni implicite di Core Animation.
    private func updateUnderline(toIndex index: CGFloat, animated: Bool) {
        let lower = Int(floor(index))
        let upper = Int(ceil(index))
        let frac = index - CGFloat(lower)

        guard let lo = tabMetrics(at: lower), let hi = tabMetrics(at: upper) else { return }
        let center = lo.centerX + (hi.centerX - lo.centerX) * frac
        let width = lo.width + (hi.width - lo.width) * frac

        underlineCenterX.constant = center
        underlineWidth.constant = width

        if animated {
            // Spring morbida: damping alto = poco overshoot. Durata breve
            // (0.32s) → l'utente sente il feedback immediato sul tap.
            UIView.animate(withDuration: 0.32,
                           delay: 0,
                           usingSpringWithDamping: 0.92,
                           initialSpringVelocity: 0.4,
                           options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
                           animations: { self.topBar.layoutIfNeeded() },
                           completion: nil)
        } else {
            // Sync col dito: niente animazioni implicite.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            topBar.layoutIfNeeded()
            CATransaction.commit()
        }
    }

    private func animateUnderline(toIndex index: Int) {
        updateUnderline(toIndex: CGFloat(index), animated: true)
    }

    /// Aggiorna lo stato visivo dei label in base al tab attivo:
    /// - attivo: testo `.label` (nero in light mode), font semibold
    /// - inattivo: testo `.tertiaryLabel` (grigio), font regular
    /// Animazione con `transition(crossDissolve)` per un cambio colore/peso
    /// più morbido (l'animazione UIView.animate non interpola textColor).
    private func updateTabAppearance(activeIndex: Int, animated: Bool = false) {
        let apply: (UILabel, Bool) -> Void = { label, isActive in
            label.textColor = isActive ? .label : .tertiaryLabel
            label.font = .systemFont(ofSize: 17,
                                     weight: isActive ? .semibold : .regular)
        }
        for (i, label) in tabLabels.enumerated() {
            let isActive = (i == activeIndex)
            if animated {
                UIView.transition(with: label,
                                  duration: 0.22,
                                  options: [.transitionCrossDissolve, .beginFromCurrentState],
                                  animations: { apply(label, isActive) },
                                  completion: nil)
            } else {
                apply(label, isActive)
            }
        }
    }

    // MARK: - Helpers

    private func index(of vc: UIViewController) -> Int? {
        return orderedChildren.firstIndex(where: { $0 === vc })
    }
}

// MARK: - UIPageViewControllerDataSource / Delegate

extension LibraryHostViewController: UIPageViewControllerDataSource,
                                     UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let i = index(of: viewController), i - 1 >= 0 else { return nil }
        return orderedChildren[i - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let i = index(of: viewController), i + 1 < orderedChildren.count else { return nil }
        return orderedChildren[i + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        if let visible = pageViewController.viewControllers?.first,
           let i = index(of: visible) {
            if completed {
                // Lo swipe ha cambiato pagina con successo: aggiorniamo
                // `currentIndex` e snappiamo subito l'underline al tab nuovo.
                // Niente animazione: durante il drag il KVO ha già seguito
                // il dito fino a `i`, animare ancora introdurrebbe overshoot.
                currentIndex = i
                updateTabAppearance(activeIndex: i, animated: true)
                updateUnderline(toIndex: CGFloat(i), animated: false)
            } else {
                // Drag annullato (l'utente non ha superato il threshold):
                // riportiamo l'underline al tab corrente con una breve
                // animazione di rientro.
                animateUnderline(toIndex: currentIndex)
            }
        }
        // Haptic alla fine dello swipe completo.
        if completed {
            let gen = UISelectionFeedbackGenerator()
            gen.selectionChanged()
        }
    }
}

