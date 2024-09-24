import UIKit

class LoginVC: UIViewController {
    
    
    
    let logoContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        let logoImageView = UIImageView(image: #imageLiteral(resourceName: "Flotip_Helvetia"))
        logoImageView.contentMode = .scaleAspectFit
        view.addSubview(logoImageView)
        logoImageView.anchor(top: nil, left: nil, bottom: nil, right: nil, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 200, height: 120)
        logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        view.backgroundColor = UIColor.white
        return view
    }()
    

    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder

        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
        tf.textColor = .black  // Imposta il colore del testo
        tf.keyboardType = .emailAddress


        return tf
    }()
    let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.attributedPlaceholder = NSAttributedString(string: "Password", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder

        tf.isSecureTextEntry = true
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
      //  tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
      //  showHideButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        tf.textColor = .black  // Imposta il colore del testo

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
       // button.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        return button
    }()
    
    let dontHaveAccountButton: UIButton = {
        let button = UIButton(type: .system)
        let attributedTitle = NSMutableAttributedString(string: "Don't have an account?  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Sign Up", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)]))
      //  button.addTarget(self, action: #selector(handleShowSignUp), for: .touchUpInside)
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

        // colourß® background
        view.backgroundColor = .white
        
        //add logo
        view.addSubview(logoContainerView)
        logoContainerView.anchor(top: view.topAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 50, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 500, height: 100)

        // add textField
        configureViewComponents()
        
        view.addSubview(dontHaveAccountButton)
        dontHaveAccountButton.anchor(top: nil, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 50)
        
        //button forgot password
      //  view.addSubview(forgotPassword)
       // forgotPassword.anchor(top: loginButton.topAnchor, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 10, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 50)

        // Auto Layout
      //  setupConstraints()
        
        // dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    func setupConstraints() {
        emailTextField.translatesAutoresizingMaskIntoConstraints = false

        // Imposta le ancore (utilizzando NSLayoutConstraint)
        NSLayoutConstraint.activate([
            emailTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            emailTextField.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            emailTextField.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
            emailTextField.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func handleForgotPassword() {
            let forgotPasswordVC = ForgotPasswordVC()
            navigationController?.pushViewController(forgotPasswordVC, animated: true)
        }

    
    func configureViewComponents() {
        let stackView = UIStackView(arrangedSubviews: [
            emailTextField,
            // emailValidationLabel,
            passwordTextField,
            // passwordValidationLabel,
            loginButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        stackView.anchor(top: logoContainerView.bottomAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 40, paddingLeft: 40, paddingBottom: 50, paddingRight: 40, width: 0, height: 0)
        
        // Aggiungi forgotPassword sotto il loginButton
        view.addSubview(forgotPassword)
        forgotPassword.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            forgotPassword.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 10),
            forgotPassword.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forgotPassword.heightAnchor.constraint(equalToConstant: 30)
        ])
        
    }
}
