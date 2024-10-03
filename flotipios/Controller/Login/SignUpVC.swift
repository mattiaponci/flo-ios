//
//  SignUpVC.swift
//  flotipios
//
//  Created by mattia poncini on 24.09.2024.
//

import UIKit
import Firebase
import SafariServices


class SignUpVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Properties
    var isTermsAccepted = false
    var imageSelected = false
    
    let plusPhotoBtn: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(#imageLiteral(resourceName: "plus_photo").withRenderingMode(.alwaysOriginal), for: .normal)
        button.addTarget(self, action: #selector(handleSelectProfilePhoto), for: .touchUpInside)
        return button
    }()
    
    let firstNameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "First Name"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "First Name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black  // Imposta il colore del testo
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let lastNameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Last Name"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Last Name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.textColor = .black  // Imposta il colore del testo
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black  // Imposta il colore del testo

        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let usernameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Username"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Username", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.textColor = .black  // Imposta il colore del testo
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black  // Imposta il colore del testo

        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let passwordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Password"
        tf.isSecureTextEntry = true
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Password", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.textColor = .black  // Imposta il colore del testo
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black  // Imposta il colore del testo

        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
        showHideButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        return tf
    }()
    
    let repasswordTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Re-enter Password"
        tf.isSecureTextEntry = true
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Re-enter Password", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])  // Colore del placeholder
        tf.textColor = .black  // Imposta il colore del testo
        tf.borderStyle = .roundedRect
        tf.textColor = .black  // Imposta il colore del testo

        tf.font = UIFont.systemFont(ofSize: 14)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
        showHideButton.addTarget(self, action: #selector(toggleRePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        return tf
    }()
    
    let emailValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "Inserisci un'email valida."
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    let passwordValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "8 caratteri, almeno un maiuscolo e un carattere speciale."
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
  
    let passwordMismatchLabel: UILabel = {
        let label = UILabel()
        label.text = "Le password non coincidono."
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
  
    let signUpButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Sign Up", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
        button.layer.cornerRadius = 5
        button.isEnabled = false
        button.addTarget(self, action: #selector(handleSignUp), for: .touchUpInside)
        return button
    }()
    
    // Checkbox for accepting Terms & Conditions
        let checkbox: UISwitch = {
            let checkbox = UISwitch()
            checkbox.onTintColor = .systemBlue
            checkbox.addTarget(self, action: #selector(handleCheckboxToggle), for: .valueChanged)
            return checkbox
        }()
        
    let termsLabel: UILabel = {
        let label = UILabel()
        let attributedText = NSMutableAttributedString(string: "I accept the ", attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.black,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
        ])
        
        attributedText.append(NSAttributedString(string: "Terms & Conditions", attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.systemBlue,
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14)
        ]))
        
        label.attributedText = attributedText
        label.isUserInteractionEnabled = true
        
        // Aggiungi il tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsTapped))
        label.addGestureRecognizer(tapGesture)
        
        return label
    }()
    
  /*  let alreadyHaveAccountButton: UIButton = {
        let button = UIButton(type: .system)
        
        let attributedTitle = NSMutableAttributedString(string: "Already have an account?  ", attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        attributedTitle.append(NSAttributedString(string: "Sign In", attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 14), NSAttributedString.Key.foregroundColor: UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)]))
        button.addTarget(self, action: #selector(handleShowLogin), for: .touchUpInside)
        button.setAttributedTitle(attributedTitle, for: .normal)
        
        return button
    }()*/

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // background color
        view.backgroundColor = .white
        
        view.addSubview(plusPhotoBtn)
        plusPhotoBtn.anchor(top: view.topAnchor, left: nil, bottom: nil, right: nil, paddingTop: 60, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 140, height: 140)
        plusPhotoBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        configureViewComponents()
        
       /* view.addSubview(alreadyHaveAccountButton)
        alreadyHaveAccountButton.anchor(top: nil, left: view.leftAnchor, bottom: view.bottomAnchor, right: view.rightAnchor, paddingTop: 0, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 0, height: 50)*/
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        // Aggiungi il gesto dopo l'aggiunta della label alla gerarchia
           let tapGestureLabel = UITapGestureRecognizer(target: self, action: #selector(handleTermsTapped))
           termsLabel.addGestureRecognizer(tapGestureLabel)
        
    }
    @objc func handleCheckboxToggle() {
            isTermsAccepted = checkbox.isOn
            updateSignUpButtonState()
        }

        @objc func handleTermsTapped() {
            
            print("Terms tapped")
            guard let url = URL(string: "https://www.flotip.com/terms.html") else { return }
            let safariVC = SFSafariViewController(url: url)
            present(safariVC, animated: true, completion: nil)
        }    // MARK: - UIImagePickerController
    
    /// function that handles selecting image from camera roll
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        // selected image
        guard let profileImage = info[.editedImage] as? UIImage else {
            imageSelected = false
            return
        }
        
        // set imageSelected to true
        imageSelected = true
        
        // configure plusPhotoBtn with selected image
        plusPhotoBtn.layer.cornerRadius = plusPhotoBtn.frame.width / 2
        plusPhotoBtn.layer.masksToBounds = true
        plusPhotoBtn.layer.borderColor = UIColor.black.cgColor
        plusPhotoBtn.layer.borderWidth = 2
        plusPhotoBtn.setImage(profileImage.withRenderingMode(.alwaysOriginal), for: .normal)
        
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Handlers
    
    @objc func handleSelectProfilePhoto() {
        
        // configure image picker
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        
        // present image picker
        self.present(imagePicker, animated: true, completion: nil)
        
    }
    
    @objc func handleShowLogin() {
        _ = navigationController?.popViewController(animated: true)
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func updateSignUpButtonState() {
          let isFormValid = firstNameTextField.hasText &&
                            lastNameTextField.hasText &&
                            usernameTextField.hasText &&
                            emailTextField.hasText &&
                            passwordTextField.hasText &&
                            repasswordTextField.hasText &&
                            isTermsAccepted

          signUpButton.isEnabled = isFormValid
          signUpButton.backgroundColor = isFormValid ? UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1) : UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
      }
    
    @objc func formValidation() {
        guard
            firstNameTextField.hasText,
            lastNameTextField.hasText,
            usernameTextField.hasText,
            emailTextField.hasText,
            passwordTextField.hasText,
            repasswordTextField.hasText else {
            return
        }
        
        signUpButton.isEnabled = true
        signUpButton.backgroundColor = UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1)
        
        let isEmailValid = self.isEmailValid(emailTextField.text ?? "")
        let isPasswordValid = self.isPasswordValid(passwordTextField.text ?? "")
        let doPasswordsMatch = passwordTextField.text == repasswordTextField.text
        
        emailValidationLabel.isHidden = isEmailValid
        passwordValidationLabel.isHidden = isPasswordValid && doPasswordsMatch
        passwordMismatchLabel.isHidden = doPasswordsMatch && isEmailValid
        
        if !isEmailValid {
            signUpButton.isEnabled = false
            signUpButton.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
            passwordMismatchLabel.isHidden = true
            return
        }
        
        if !isPasswordValid {
            //showAlert(title: "Invalid Password", message: "Password must be at least 8 characters long, contain at least one uppercase letter and one special character.")
            signUpButton.isEnabled = false
            signUpButton.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
            return
        }
        
        if !doPasswordsMatch {
            signUpButton.isEnabled = false
            signUpButton.backgroundColor = UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
            return
        }
    }
    
    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    @objc func togglePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        passwordTextField.isSecureTextEntry.toggle()
    }
    
    @objc func toggleRePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        repasswordTextField.isSecureTextEntry.toggle()
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        let minLength = password.count >= 8
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialCharacter = password.rangeOfCharacter(from: .symbols) != nil || password.rangeOfCharacter(from: .punctuationCharacters) != nil
        return minLength && hasUppercase && hasSpecialCharacter
    }
    
    @objc func handleSignUp() {
        guard let firstName = firstNameTextField.text else { return }
        guard let lastName = lastNameTextField.text else { return }
        guard let username = usernameTextField.text?.lowercased() else { return }
        guard let email = emailTextField.text else { return }
        guard let password = passwordTextField.text else { return }
              
        
        Auth.auth().createUser(withEmail: email, password: password) { (authResult, error) in
            if let error = error {
                print("DEBUG: Failed to create user with error: ", error.localizedDescription)
                return
            }
            
            guard let profileImg = self.plusPhotoBtn.imageView?.image else { return }
            guard let uploadData = profileImg.jpegData(compressionQuality: 0.3) else { return }
            
            let filename = NSUUID().uuidString
            let storageRef = Storage.storage().reference().child("profile_images").child(filename)
            
            storageRef.putData(uploadData, metadata: nil, completion: { (metadata, error) in
                if let error = error {
                    print("Failed to upload image to Firebase Storage with error", error.localizedDescription)
                    return
                }
                
                storageRef.downloadURL(completion: { (downloadURL, error) in
                    guard let profileImageUrl = downloadURL?.absoluteString else {
                        print("DEBUG: Profile image url is nil")
                        return
                    }

                    guard let uid = authResult?.user.uid else { return }
                    guard let fcmToken = Messaging.messaging().fcmToken else { return }

                    let dictionaryValues = ["firstName": firstName,
                                            "lastName": lastName,
                                            "fcmToken": fcmToken,
                                            "username": username,
                                            "profileImageUrl": profileImageUrl,
                                            ]
                    let values = [uid: dictionaryValues]

                    USER_REF.updateChildValues(values, withCompletionBlock: { (error, ref) in
                        guard let mainTabVC = UIApplication.shared.keyWindow?.rootViewController as? MainTabVC else { return }
                        mainTabVC.configureViewControllers()
                        mainTabVC.isInitialLoad = true
                        self.dismiss(animated: true, completion: nil)
                    })
                })
            })
        }
    }
    
    func showAlert(title: String, message: String) {
       let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
       let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
       alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
   }
    
    func configureViewComponents() {
        let nameStackView = UIStackView(arrangedSubviews: [firstNameTextField, lastNameTextField])
        nameStackView.axis = .horizontal
        nameStackView.spacing = 10
        nameStackView.distribution = .fillEqually
        
        // Crea lo stack per checkbox e label Terms & Conditions
           let termsStackView = UIStackView(arrangedSubviews: [checkbox, termsLabel])
           termsStackView.axis = .horizontal
           termsStackView.spacing = 10
           termsStackView.distribution = .fillProportionally
        
        let stackView = UIStackView(arrangedSubviews: [
            nameStackView,
            usernameTextField,
            emailTextField,
            emailValidationLabel,
            passwordTextField,
            passwordValidationLabel,
            repasswordTextField,
            passwordMismatchLabel,
            signUpButton,
            termsStackView
        ])
        
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fillEqually
        
        view.addSubview(stackView)
        stackView.anchor(top: plusPhotoBtn.bottomAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 24, paddingLeft: 40, paddingBottom: 0, paddingRight: 40, width: 0, height: 0)
        
        emailValidationLabel.translatesAutoresizingMaskIntoConstraints = false
        emailValidationLabel.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 3).isActive = true
        emailValidationLabel.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor).isActive = true
        emailValidationLabel.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor).isActive = true
        
        passwordMismatchLabel.translatesAutoresizingMaskIntoConstraints = false
        passwordMismatchLabel.topAnchor.constraint(equalTo: repasswordTextField.bottomAnchor, constant: 3).isActive = true
        passwordMismatchLabel.leadingAnchor.constraint(equalTo: repasswordTextField.leadingAnchor).isActive = true
        passwordMismatchLabel.trailingAnchor.constraint(equalTo: repasswordTextField.trailingAnchor).isActive = true
    }
}
