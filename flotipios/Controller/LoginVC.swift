import UIKit

class LoginVC: UIViewController {

    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return tf
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // colourß® background
        view.backgroundColor = .white
        
        print("hello")

        // add textField
       view.addSubview(emailTextField)

        // Auto Layout
        setupConstraints()
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
}
