//
//  ScreenshotViewController.swift
//  com.mattiaponcini.project
//

import UIKit
import WebKit

class ScreenshotViewController: UIViewController {

    // MARK: - UI

    /// Costruzione esplicita della webview con una `WKWebViewConfiguration`
    /// che imposta `applicationNameForUserAgent` con la firma di Safari
    /// Mobile. Motivazioni:
    ///   1. Alcuni siti (in particolare youtube.com) servono una
    ///      "interstitial app open" o un layout degradato quando vedono
    ///      lo user agent default di WKWebView; con un UA Safari-like ci
    ///      restituiscono il sito web standard, niente deeplink suggeriti.
    ///   2. Lo user agent va settato PRIMA dell'init della WKWebView:
    ///      `applicationNameForUserAgent` è un campo della config, non
    ///      può essere cambiato a runtime con effetto retroattivo sulle
    ///      richieste già partite.
    /// In aggiunta, registriamo il VC come `uiDelegate` (oltre che
    /// `navigationDelegate`) per poter intercettare i `_blank` link e
    /// caricarli nella stessa webview invece di lasciarli "evaporare"
    /// (default: WKWebView non apre nuove window e li ignora, peggio:
    /// alcuni innescano un fallback a UIApplication.open).
    private lazy var webView: WKWebView = {
        let cfg = WKWebViewConfiguration()
        // Stringa stile "AppleWebKit/.../Safari/...": WKWebView la
        // appende dopo il blocco "Mozilla/5.0 (iPhone; ...)" generato
        // automaticamente dal sistema, ottenendo uno UA finale che i
        // siti riconoscono come Safari Mobile.
        cfg.applicationNameForUserAgent = "Version/17.0 Mobile/15E148 Safari/604.1"
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.translatesAutoresizingMaskIntoConstraints = false
        // `allowsLinkPreview = false`: il preview 3D-Touch/long-press di
        // default offre un "Open in Safari" che porterebbe fuori
        // dall'app. Lo disabilitiamo per coerenza con il resto della
        // logica di confinamento in-app.
        wv.allowsLinkPreview = false
        return wv
    }()

    private let topBar: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var backBtn    = makeBtn("chevron.left",    #selector(goBack))
    private lazy var forwardBtn = makeBtn("chevron.right",   #selector(goForward))
    private lazy var refreshBtn = makeBtn("arrow.clockwise", #selector(doRefresh))
    private lazy var libraryBtn = makeBtn("books.vertical.fill", #selector(openLibrary))

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        // 1. Top bar (status bar + barra dei controlli) — la posizioniamo
        //    PRIMA della webview così possiamo ancorare la webview al suo
        //    bottom e il contenuto web non finisce nascosto sotto la barra.
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44)
        ])

        // 2. Webview — parte SOTTO la top bar (no più contenuto coperto
        //    dalla barra opaca bianca). Occupa tutto il resto dello schermo.
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        webView.navigationDelegate = self
        // uiDelegate serve per gestire i link con target="_blank" /
        // window.open: senza, WKWebView NON apre la nuova window e il
        // tap viene perso (oppure dirottato a UIApplication.open dal
        // sistema). Il nostro createWebViewWith forza il caricamento
        // nella stessa webview così l'utente non esce mai dall'app.
        webView.uiDelegate = self
        webView.scrollView.delegate = self
        // Disabilita aggiustamenti automatici dell'inset: ora il top della
        // webview è già posizionato sotto la barra, niente aggiustamenti
        // ulteriori che farebbero comparire margini bianchi extra.
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Separatore
        let sep = UIView()
        sep.backgroundColor = UIColor.systemGray5
        sep.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: topBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: topBar.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: topBar.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        // Stack bottoni nella zona sotto la status bar
        let stack = UIStackView(arrangedSubviews: [backBtn, forwardBtn, refreshBtn])
        stack.axis = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -4),
            stack.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Bottone "Libreria" in alto a destra
        topBar.addSubview(libraryBtn)
        NSLayoutConstraint.activate([
            libraryBtn.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -8),
            libraryBtn.bottomAnchor.constraint(equalTo: topBar.bottomAnchor, constant: -4),
            libraryBtn.heightAnchor.constraint(equalToConstant: 36)
        ])

        // Carica URL
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
        updateBtns()
    }

    // MARK: - Helpers

    private func makeBtn(_ icon: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setImage(UIImage(systemName: icon,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium)),
                   for: .normal)
        b.tintColor = .label
        b.translatesAutoresizingMaskIntoConstraints = false
        b.widthAnchor.constraint(equalToConstant: 44).isActive = true
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    private func updateBtns() {
        backBtn.isEnabled    = webView.canGoBack
        forwardBtn.isEnabled = webView.canGoForward
        backBtn.alpha    = webView.canGoBack    ? 1 : 0.3
        forwardBtn.alpha = webView.canGoForward ? 1 : 0.3
    }

    // MARK: - Actions

    @objc private func goBack()    { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func doRefresh() { webView.reload() }

    @objc private func openLibrary() {
        // Apriamo il container TikTok-style con tab Notifiche/Libreria.
        // Tab attivo di default: `.library` (l'utente preme l'icona libri,
        // si aspetta di vedere prima la libreria; può swippare a sinistra
        // per le notifiche).
        let vc = LibraryHostViewController(initialTab: .library)
        // Modale fullscreen → la tab bar resta nascosta dietro
        // (la presentazione fullscreen copre tutta la finestra).
        vc.modalPresentationStyle = .fullScreen

        // Animazione personalizzata: slide da destra verso sinistra.
        if let window = view.window {
            let transition = CATransition()
            transition.duration = 0.35
            transition.type = .push
            transition.subtype = .fromRight
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.layer.add(transition, forKey: kCATransition)
        }
        present(vc, animated: false)
    }

    // MARK: - Top bar show/hide

    private var lastY: CGFloat = 0
    private var barVisible = true

    private func setBar(_ visible: Bool) {
        guard visible != barVisible else { return }
        barVisible = visible
        UIView.animate(withDuration: 0.2, delay: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: {
            self.topBar.alpha = visible ? 1 : 0
            self.topBar.transform = visible ? .identity
                                            : CGAffineTransform(translationX: 0, y: -self.topBar.bounds.height)
        })
    }

    // MARK: - Snapshot (chiamato da MainTabBarController)

    func takeWebViewSnapshot() {
        let cfg = WKSnapshotConfiguration()
        cfg.rect = webView.bounds
        // Cattura l'URL corrente al momento dello scatto: verrà passato al
        // composer per essere salvato sul documento Firestore. Così il post
        // ricorda da quale pagina è stato preso lo screenshot.
        let capturedURL = webView.url?.absoluteString
        webView.takeSnapshot(with: cfg) { [weak self] img, err in
            guard let self, let img, err == nil else { return }
            DispatchQueue.main.async {
                let vc = ScreenshotPreviewViewController(image: img, sourceURL: capturedURL)
                vc.modalPresentationStyle = .overFullScreen
                vc.modalTransitionStyle   = .crossDissolve
                self.present(vc, animated: true)
            }
        }
    }

    // MARK: - URL programmatico

    /// Carica l'URL fornito nella webview. Usato dal doppio tap su un post
    /// (Feed o Libreria) per riaprire la pagina sorgente nella tab Cattura.
    func loadURL(_ url: URL) {
        // Se la view non è ancora stata caricata, viewDidLoad caricherà
        // google.com — quindi forziamo il caricamento dopo che la view è ready.
        loadViewIfNeeded()
        webView.load(URLRequest(url: url))
    }
}

// MARK: - WKNavigationDelegate

extension ScreenshotViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { updateBtns() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { updateBtns() }

    /// Decide se permettere o meno una navigazione. Logica:
    ///
    /// - Tutti gli URL `http(s)` sono concessi e gestiti dalla webview
    ///   (`.allow`) — non chiamiamo MAI `UIApplication.shared.open(url)`.
    ///   È proprio questo a impedire l'uscita verso l'app YouTube
    ///   nativa: iOS apre l'app esterna SOLO se l'app chiama
    ///   esplicitamente `UIApplication.open` su un URL coperto da un
    ///   universal link. Restando in `.allow`, WKWebView gestisce la
    ///   pagina internamente come una normale richiesta web.
    ///
    /// - Schemi non-HTTP (`tel:`, `mailto:`, `sms:`, `itms-apps:` ecc.)
    ///   non sono navigabili da WKWebView: per quelli il delegato di
    ///   default li lascerebbe cadere, qui esplicitiamo `.cancel` così
    ///   non finiscono in errori silenziosi della webview. Volutamente
    ///   NON deleghiamo a UIApplication.open: il vincolo dell'utente è
    ///   "non uscire dall'app", e quegli schemi porterebbero comunque
    ///   fuori (Telefono, Mail, App Store, ecc.). Se in futuro vogliamo
    ///   abilitare solo `tel:` o `mailto:`, basta whitelistarli qui.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        if scheme == "http" || scheme == "https" || scheme == "about" {
            // Caso "_blank": targetFrame è nil quando il link ha
            // target="_blank" o quando window.open non ha un frame
            // nominato. WKWebView normalmente NON crea automaticamente
            // un nuovo frame e la navigazione si perde. Forziamo il
            // caricamento nella stessa webview così la pagina resta
            // visibile in-app.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }
        // Schemi non-web: non navigabili e non li deleghiamo al sistema
        // (che aprirebbe app esterne). Annulliamo silenziosamente.
        decisionHandler(.cancel)
    }
}

// MARK: - WKUIDelegate

extension ScreenshotViewController: WKUIDelegate {
    /// Chiamato quando il JS (o un link `target="_blank"`) richiede una
    /// nuova WKWebView. Non vogliamo aprire una window separata né
    /// uscire dall'app: carichiamo la richiesta nella webview esistente
    /// e ritorniamo `nil` — segnale standard per "ho gestito io,
    /// niente nuova window".
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

// MARK: - UIScrollViewDelegate

extension ScreenshotViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y
        let d = y - lastY
        if d > 8  && y > 50 { setBar(false) }
        if d < -8            { setBar(true)  }
        lastY = y
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { setBar(true) }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        if !willDecelerate { setBar(true) }
    }
}

// MARK: - ScreenshotPreviewViewController

class ScreenshotPreviewViewController: UIViewController {

    private let capturedImage: UIImage
    private let sourceURL: String?

    init(image: UIImage, sourceURL: String?) {
        self.capturedImage = image
        self.sourceURL = sourceURL
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.88)

        let iv = UIImageView(image: capturedImage)
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(iv)

        let okFG = UIColor(red: 0.17, green: 0.13, blue: 0, alpha: 1) // testo scuro su oro chiaro
        let ok = makeBtn("Pubblica", bg: .Brand.goldOnDark, fg: okFG, action: #selector(okTapped))
        let discard = makeBtn("Scarta", bg: UIColor.white.withAlphaComponent(0.15),
                              fg: .white, action: #selector(discardTapped))
        view.addSubview(ok)
        view.addSubview(discard)

        NSLayoutConstraint.activate([
            iv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            iv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            iv.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            iv.bottomAnchor.constraint(equalTo: ok.topAnchor, constant: -24),

            ok.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            ok.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            ok.bottomAnchor.constraint(equalTo: discard.topAnchor, constant: -12),
            ok.heightAnchor.constraint(equalToConstant: 50),

            discard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            discard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            discard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            discard.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func makeBtn(_ title: String, bg: UIColor, fg: UIColor, action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        b.backgroundColor = bg
        b.setTitleColor(fg, for: .normal)
        b.layer.cornerRadius = 12
        b.translatesAutoresizingMaskIntoConstraints = false
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc private func okTapped() {
        let composer = PostViewController(image: capturedImage, sourceURL: sourceURL)
        let nav = UINavigationController(rootViewController: composer)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func discardTapped() { dismiss(animated: true) }
}
