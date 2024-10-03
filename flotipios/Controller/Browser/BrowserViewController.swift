import UIKit
import WebKit
import CropViewController
protocol YourViewControllerDelegate: AnyObject {
    func didSelectWebsite(url: URL)
}
class BrowserViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!
    var toolBar: UIToolbar!
    var refreshControl: UIRefreshControl!
    var progressView: UIProgressView! // Barra di caricamento
    var initialURL: URL?
    var pendingURL: URL?
    
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!

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
        view.addSubview(webView)
        view.backgroundColor = .white

        // Osserva il progresso del caricamento della WebView
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        // Configura il pull-to-refresh
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)

        // Configura la barra degli strumenti
        configureToolbar()

        // Configura la navigation bar
        configureNavigationBar()

        // Configura la barra di progresso (sotto la tab bar)
        configureProgressBar()

        // Configura i constraints per la web view e la barra degli strumenti
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
        progressView.trackTintColor = UIColor.lightGray
        progressView.progressTintColor = UIColor.gray
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

    // Configura la barra degli strumenti
    func configureToolbar() {
        toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.barTintColor = .white
        toolBar.isTranslucent = false
        view.addSubview(toolBar)

        backButton = UIBarButtonItem(title: "<", style: .plain, target: self, action: #selector(backButtonTapped))
        forwardButton = UIBarButtonItem(title: ">", style: .plain, target: self, action: #selector(forwardButtonTapped))
        forwardButton.isEnabled = false
        backButton.isEnabled = false

        let actionButton = UIBarButtonItem(image: UIImage(named: "flag"), style: .plain, target: self, action: #selector(toolbarAction))

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolBar.setItems([backButton, flexibleSpace, actionButton, flexibleSpace, forwardButton], animated: false)
    }

    // Configura la navigation bar
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

        // Aggiungi il pulsante "Folder" e imposta il titolo
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "Folder"), style: .plain, target: self, action: #selector(handleShowMessages))
       // self.navigationItem.rightBarButtonItem?.tintColor = .red
        self.navigationItem.title = "Surf"
    }

    func setupConstraints() {
        // Constraints per la barra degli strumenti
        NSLayoutConstraint.activate([
            toolBar.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            toolBar.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            toolBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Constraints per il web view
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolBar.topAnchor)
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
       // messagesController.delegate = self  // Imposta 'self' come delegato
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

    // Funzione per catturare screenshot del WebView
    func captureWebViewScreenshot() {
        let snapshotConfiguration = WKSnapshotConfiguration()
        
        // Definisci l'area da catturare (intera pagina)
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
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }
}

extension BrowserViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true, completion: nil)
        
        // Configura e presenta ScreenshotViewController
        let screenshotVC = SecondViewController()
        screenshotVC.screenshotImage = image
        screenshotVC.pageURL = webView.url  // Passa l'URL corrente della web view
        screenshotVC.modalPresentationStyle = .fullScreen
        self.present(screenshotVC, animated: true, completion: nil)
    }
    
    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true, completion: nil)
    }
}

extension BrowserViewController: YourViewControllerDelegate {
    func didSelectWebsite(url: URL) {
        navigationController?.popViewController(animated: true)  // Torna indietro
        webView.load(URLRequest(url: url))  // Carica l'URL
    }
    
    
    
}
