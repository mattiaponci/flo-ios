import UIKit
import WebKit
import CropViewController

class BrowserViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!
    var refreshControl: UIRefreshControl!
    var progressView: UIProgressView! // Barra di caricamento
    var initialURL: URL?
    var pendingURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configura il web view con una configurazione ottimizzata
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.suppressesIncrementalRendering = true
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .white
        webView.scrollView.showsVerticalScrollIndicator = false
        view.addSubview(webView)
        view.backgroundColor = .white

        // Osserva il progresso del caricamento della WebView
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        // Configura il pull-to-refresh
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)

        // Configura la navigation bar
        configureNavigationBar()

        // Configura la barra di progresso (sotto la tab bar)
        configureProgressBar()

        // Configura i constraints per la web view
        setupConstraints()

        tabBarController?.tabBar.isTranslucent = false
        tabBarController?.tabBar.barTintColor = .white

        // Carica una URL iniziale se disponibile
        if let url = URL(string: "https://www.google.com") {
            load(url: url)
        }
        
        
    }

    // Configura la barra di caricamento
    func configureProgressBar() {
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = UIColor.blue
        progressView.progressTintColor = UIColor.blue
        view.addSubview(progressView)

        // Imposta i constraints per la progressView
        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // Osserva il cambiamento del progresso di caricamento
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.progress = Float(webView.estimatedProgress)
            progressView.isHidden = webView.estimatedProgress >= 1.0
        }
    }

    func configureNavigationBar() {
        guard let navigationController = navigationController else { return }

        // Disabilita large titles
        navigationController.navigationBar.prefersLargeTitles = false

        // Configura l'aspetto della navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.isTranslucent = false

        // Configura il titolo come stack con i pulsanti vicini
        let titleStackView = UIStackView()
        titleStackView.axis = .horizontal
        titleStackView.alignment = .center
        titleStackView.spacing = 8 // Spaziatura minima tra gli elementi

        // Configura il pulsante "Back" (<) a sinistra del titolo
        let backButton = UIButton(type: .system)
        backButton.setTitle("<", for: .normal)
        backButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        backButton.setTitleColor(.black, for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        // Configura il pulsante "Forward" (>) a destra del titolo
        let forwardButton = UIButton(type: .system)
        forwardButton.setTitle(">", for: .normal)
        forwardButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        forwardButton.setTitleColor(.black, for: .normal)
        forwardButton.addTarget(self, action: #selector(forwardButtonTapped), for: .touchUpInside)

        // Configura il titolo "Home" come cliccabile
        let titleLabel = UILabel()
        titleLabel.text = "Home"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.textColor = .black
        titleLabel.isUserInteractionEnabled = true
        let titleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleHomeTapped))
        titleLabel.addGestureRecognizer(titleTapGesture)

        // Aggiungi i pulsanti e il titolo allo stack
        titleStackView.addArrangedSubview(backButton)
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(forwardButton)

        // Imposta lo stack come titleView
        self.navigationItem.titleView = titleStackView

        // Configura il pulsante "Folder" a destra
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "Folder"), style: .plain, target: self, action: #selector(handleShowMessages))
    }

    // Azione per il titolo "Home"
    @objc func handleHomeTapped() {
        if let url = URL(string: "https://www.google.com") {
            load(url: url)
        }
        print("Navigato a Google.com")
    }

    // MARK: - Azioni

    @objc func handleTitleTapped() {
        print("home")
    }

    func setupConstraints() {
        // Constraints per il web view
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc func toolbarAction() {
        captureWebViewScreenshot()
    }

    @objc func backButtonTapped() {
        if webView.canGoBack {
            webView.goBack()
        }
    }

    @objc func forwardButtonTapped() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    @objc func refreshWebView() {
        webView.reload()
        refreshControl.endRefreshing()
    }

    @objc func handleShowMessages() {
        // Implementazione per il pulsante "Folder"
        let messagesController = YourViewController()
        messagesController.delegate = self
        navigationController?.pushViewController(messagesController, animated: true)
    }

    func load(url: URL) {
        initialURL = url
        let request = URLRequest(url: url)
        webView.load(request)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let url = pendingURL {
            let request = URLRequest(url: url)
            webView.load(request)
            pendingURL = nil
        }
    }

    func captureWebViewScreenshot() {
        let snapshotConfiguration = WKSnapshotConfiguration()

        snapshotConfiguration.rect = webView.bounds
        snapshotConfiguration.afterScreenUpdates = true

        webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, error in
            guard let image = image else {
                print("Errore durante lo screenshot: \(String(describing: error))")
                return
            }

            let cropViewController = CropViewController(croppingStyle: .default, image: image)
            cropViewController.delegate = self
            let cropSquareSize = CGSize(width: self?.view.frame.width ?? 0, height: self?.view.frame.width ?? 0)
            cropViewController.customAspectRatio = cropSquareSize
            cropViewController.aspectRatioLockEnabled = true
            cropViewController.resetAspectRatioEnabled = false
            cropViewController.aspectRatioPickerButtonHidden = true
            
            cropViewController.cropView.cropBoxResizeEnabled = false
            cropViewController.toolbar.clampButtonHidden = true
            cropViewController.toolbar.rotateButton.isHidden = true
            cropViewController.toolbar.rotateClockwiseButton?.isHidden = true
            cropViewController.toolbar.resetButton.isHidden = true

            self?.present(cropViewController, animated: true, completion: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationItem.titleView?.isHidden = false
    }
}

extension BrowserViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true, completion: nil)

        let screenshotVC = SecondViewController()
        screenshotVC.screenshotImage = image
        screenshotVC.pageURL = webView.url
        screenshotVC.modalPresentationStyle = .fullScreen
        self.present(screenshotVC, animated: true, completion: nil)
    }

    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true, completion: nil)
    }
}

extension BrowserViewController: YourViewControllerDelegate {
    func didSelectWebsite(url: URL) {
        navigationController?.popViewController(animated: true)
        print("the url is \(url)")
        webView.load(URLRequest(url: url))
    }
}



