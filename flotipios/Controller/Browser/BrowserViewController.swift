import UIKit
import WebKit
import CropViewController

class BrowserViewController: UIViewController, WKNavigationDelegate, TOCropViewControllerDelegate {

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
        guard let webView = webView else {
            print("webView is nil. Cannot load URL.")
          return
        }
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
        let snapshotConfig = WKSnapshotConfiguration()
        snapshotConfig.rect = webView.bounds
        snapshotConfig.afterScreenUpdates = true

        webView.takeSnapshot(with: snapshotConfig) { [weak self] image, error in
            guard let self = self else { return }
            guard let screenshot = image else {
                print("Failed to capture screenshot: \(String(describing: error))")
                return
            }

            let cropViewController = CustomCropViewController(croppingStyle: .default, image: screenshot)
            cropViewController.delegate = self
            cropViewController.aspectRatioLockEnabled = true
            cropViewController.customAspectRatio = CGSize(width: self.view.frame.width, height: self.view.frame.width)
            cropViewController.toolbar.clampButtonHidden = true
            cropViewController.toolbar.rotateButton.isHidden = true
            cropViewController.toolbar.resetButton.isHidden = true
            cropViewController.rotateClockwiseButtonHidden = true // Nasconde il pulsante di rotazione

            self.present(cropViewController, animated: true)
        }
    }

    // MARK: - TOCropViewControllerDelegate
    func cropViewController(_ cropViewController: TOCropViewController, didCropTo image: UIImage, with cropRect: CGRect, angle: Int) {
        print("Crop completed. Preparing to present SecondViewController.")
        
        cropViewController.dismiss(animated: true) {
            let screenshotVC = SecondViewController()
            screenshotVC.screenshotImage = image
            screenshotVC.pageURL = self.webView.url
            screenshotVC.modalPresentationStyle = .fullScreen

            self.present(screenshotVC, animated: true) {
                print("SecondViewController presented")
            }
        }
    }

    func cropViewController(_ cropViewController: TOCropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true) {
            print("Crop cancelled.")
        }
    }
}

    class CustomCropViewController: TOCropViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)

            // Trova lo UIScrollView all'interno di TOCropView
            if let scrollView = cropView.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                scrollView.maximumZoomScale = 1.0 // Disabilita lo zoom massimo
                scrollView.minimumZoomScale = 1.0 // Disabilita lo zoom minimo
                scrollView.isScrollEnabled = true // Mantieni lo scroll abilitato
            }
        }
    }

   





extension BrowserViewController: YourViewControllerDelegate {
    func didSelectWebsite(url: URL) {
        navigationController?.popViewController(animated: true)
        print("the url is \(url)")
        webView.load(URLRequest(url: url))
    }
}



