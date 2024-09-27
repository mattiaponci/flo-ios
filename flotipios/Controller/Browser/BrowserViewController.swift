import UIKit
import WebKit
import CropViewController

class BrowserViewController: UIViewController, WKNavigationDelegate {

    var webView: WKWebView!
    var toolBar: UIToolbar!
    var refreshControl: UIRefreshControl!
    var initialURL: URL?
    var pendingURL: URL?
    
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Configura il web view con una configurazione ottimizzata
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.suppressesIncrementalRendering = true // Carica la pagina solo quando il contenuto è completo
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .white
        view.addSubview(webView)
        view.backgroundColor = .white

        // Configura il pull-to-refresh
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshWebView), for: .valueChanged)
        webView.scrollView.addSubview(refreshControl)

        // Configura la barra degli strumenti
        configureToolbar()

        // Configura la navigation bar
        configureNavigationBar()

        // Configura i constraints per la web view e la barra degli strumenti
        setupConstraints()
        
        tabBarController?.tabBar.isTranslucent = false
        tabBarController?.tabBar.barTintColor = .white

        // Carica una URL iniziale se disponibile
        if let url = URL(string: "https://www.google.com") {
            load(url: url)
        }
    }

    func configureToolbar() {
        // Configura la barra degli strumenti
        toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolBar)

        // Pulsante "Back"
        backButton = UIBarButtonItem(title: "<", style: .plain, target: self, action: #selector(backButtonTapped))
        backButton.isEnabled = false

        // Pulsante "Forward"
        forwardButton = UIBarButtonItem(title: ">", style: .plain, target: self, action: #selector(forwardButtonTapped))
        forwardButton.isEnabled = false

        // Pulsante "Action"
        let actionButton = UIBarButtonItem(image: UIImage(named: "flag"), style: .plain, target: self, action: #selector(toolbarAction))

        // Spaziatore flessibile
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // Aggiungi i pulsanti alla barra degli strumenti
        toolBar.setItems([backButton, flexibleSpace, actionButton, flexibleSpace, forwardButton], animated: false)
    }

    func configureNavigationBar() {
        guard let navigationController = navigationController else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.black]

        navigationController.navigationBar.standardAppearance = appearance
        navigationController.navigationBar.scrollEdgeAppearance = appearance
        navigationController.navigationBar.isTranslucent = false

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "folder"), style: .plain, target: self, action: #selector(handleShowMessages))
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
        // Implementazione di una funzione che mostra un altro controller
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
        webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, error in
            guard let image = image else { return }
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
    
    // Aggiorna i pulsanti di navigazione
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }
}

extension BrowserViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true, completion: nil)
        // Gestione dell'immagine croppata
    }

    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true, completion: nil)
    }
}
