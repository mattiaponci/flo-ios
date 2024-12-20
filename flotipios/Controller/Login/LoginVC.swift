import UIKit
import Firebase

class LoginVC: UIViewController {

    var failedLoginAttempts = 0 // Track number of failed login attempts
    let lockDuration: TimeInterval = 3600 // Lock duration in seconds (1 hour)

    let logoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        let logoImageView = UIImageView(image: #imageLiteral(resourceName: "Flotip_Helvetia"))
        logoImageView.contentMode = .scaleAspectFit
        view.addSubview(logoImageView)
        logoImageView.anchor(top: nil, left: nil, bottom: nil, right: nil, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 350, height: 250)
        logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        view.backgroundColor = UIColor.white
        return view
    }()
    
    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        return tf
    }()

    
    let emailErrorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .red
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "Insert a valid e-mail"
        label.isHidden = true // Nascondere di default
        return label
    }()
    let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.isSecureTextEntry = true
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Password", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.textColor = .black
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        tf.autocapitalizationType = .none
        
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
        showHideButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        return tf
    }()
    
    let loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Login", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
        button.layer.cornerRadius = 5
        button.isEnabled = false
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        return button
    }()
    
    let dontHaveAccountButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: "Don't have an account?  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Sign Up", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)]))
        button.addTarget(self, action: #selector(handleShowSignUp), for: .touchUpInside)
        button.isEnabled = true
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }()
    
    let forgotPassword: UIButton = {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: "Forgot  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Password?", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)]))
        button.addTarget(self, action: #selector(handleForgotPassword), for: .touchUpInside)
        button.isEnabled = true
        button.setAttributedTitle(attributedTitle, for: .normal)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .white
        view.addSubview(logoContainerView)
        logoContainerView.anchor(top: view.topAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 80, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 600, height: 100)

        configureViewComponents()
        
        view.addSubview(dontHaveAccountButton)
        dontHaveAccountButton.anchor(top: nil, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 50)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        checkIfLockedOut()
    }
    
    @objc func togglePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        passwordTextField.isSecureTextEntry.toggle()
    }
    
    @objc func handleLogin() {
        // Check if locked out
        if isLockedOut() {
            AlertManager.showPopup()
            return
        }
        
        // properties
        guard let email = emailTextField.text, let password = passwordTextField.text else { return }
        
        // sign user in with email and password
        Auth.auth().signIn(withEmail: email, password: password) { (result, error) in
            
            // handle error
            if let error = error {
                print("Unable to sign user in with error", error.localizedDescription)
                self.failedLoginAttempts += 1
                
                // If user fails once or twice, show top alert
                if self.failedLoginAttempts <= 2 {
                    AlertManager.showTopAlert()
                }
                
                // If user fails three times, lock out
                if self.failedLoginAttempts == 3 {
                    self.lockOutUser()
                    AlertManager.showTopAlert()
                    self.failedLoginAttempts = 0 // Reset after showing alert
                }
                return
            }
            
            // Reset failed attempts on successful login
            self.failedLoginAttempts = 0
            
            guard let mainTabVC = UIApplication.shared.keyWindow?.rootViewController as? MainTabVC else { return }
            mainTabVC.configureViewControllers()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPredicate.evaluate(with: email)
    }

    @objc func formValidation() {
        guard let email = emailTextField.text else { return }

        // Validazione dell'email
        if !isValidEmail(email) {
            emailErrorLabel.isHidden = false
        } else {
            emailErrorLabel.isHidden = true
        }

        // Validazione per login button
        guard emailTextField.hasText, passwordTextField.hasText, isValidEmail(email) else {
            loginButton.isEnabled = false
            loginButton.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
            return
        }

        emailErrorLabel.isHidden = true
        loginButton.isEnabled = true
        loginButton.backgroundColor = UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func handleForgotPassword() {
        let forgotPasswordVC = ForgotPasswordVC()
        navigationController?.pushViewController(forgotPasswordVC, animated: true)
    }
    
    @objc func handleShowSignUp() {
        let signUpVC = SignUpVC()
        navigationController?.pushViewController(signUpVC, animated: true)
    }
    
    func configureViewComponents() {
        let stackView = UIStackView(arrangedSubviews: [
            emailTextField,
            emailErrorLabel, // Aggiungi la label
            passwordTextField,
            loginButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fill // Assicura che il contenuto si adatti
        stackView.alignment = .fill    // Allinea tutti gli elementi alla larghezza massima
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Aggiungi lo stackView alla view principale
        view.addSubview(stackView)
        stackView.anchor(top: logoContainerView.bottomAnchor,
                         left: view.leftAnchor,
                         bottom: nil,
                         right: view.rightAnchor,
                         paddingTop: 40,
                         paddingLeft: 40,
                         paddingBottom: 0,
                         paddingRight: 40,
                         width: 0,
                         height: 0)

        // Aggiungi il bottone 'forgotPassword' separatamente
        view.addSubview(forgotPassword)
        forgotPassword.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            forgotPassword.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 10),
            forgotPassword.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forgotPassword.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    func lockOutUser() {
        let lockOutTime = Date().addingTimeInterval(lockDuration)
        UserDefaults.standard.set(lockOutTime, forKey: "lockOutTime")
    }
    
    func isLockedOut() -> Bool {
        if let lockOutTime = UserDefaults.standard.object(forKey: "lockOutTime") as? Date {
            if Date() < lockOutTime {
                return true
            } else {
                UserDefaults.standard.removeObject(forKey: "lockOutTime")
                return false
            }
        }
        return false
    }
    
    func checkIfLockedOut() {
        if isLockedOut() {
            AlertManager.showPopup()
            print("")
        }
    }
}
