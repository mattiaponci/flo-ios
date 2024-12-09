//
//  SignUpVC.swift
//  flotipios
//
//  Created by mattia poncini on 24.09.2024.
//

import UIKit
import Firebase
import SafariServices
import UserNotifications

class SignUpVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MessagingDelegate {
    
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
        tf.attributedPlaceholder = NSAttributedString(string: "First Name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let lastNameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Last Name"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Last Name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.textColor = .black
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let usernameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Username"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Username", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.textColor = .black
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let dateOfBirthLabel: UILabel = {
        let label = UILabel()
        label.text = "Date of Birth"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .black
        return label
    }()

    let dateOfBirthBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.03)
        view.layer.cornerRadius = 5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let dateOfBirthPicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.translatesAutoresizingMaskIntoConstraints = false
        picker.addTarget(self, action: #selector(handleDateOfBirthChange), for: .valueChanged)
        return picker
    }()

    let emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Email", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = .black
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
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
        tf.attributedPlaceholder = NSAttributedString(string: "Re-enter Password", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.textColor = .black
        tf.borderStyle = .roundedRect
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // background color
        view.backgroundColor = .white
        
        view.addSubview(plusPhotoBtn)
        plusPhotoBtn.anchor(top: view.topAnchor, left: nil, bottom: nil, right: nil, paddingTop: 60, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 140, height: 140)
        plusPhotoBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        configureViewComponents()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        Messaging.messaging().delegate = self

        let tapGestureLabel = UITapGestureRecognizer(target: self, action: #selector(handleTermsTapped))
        termsLabel.addGestureRecognizer(tapGestureLabel)
        
       

    }

    @objc func handleCheckboxToggle() {
        isTermsAccepted = checkbox.isOn
        formValidation()
    }

    @objc func handleTermsTapped() {
        guard let url = URL(string: "https://www.flotip.com/terms.html") else { return }
        let safariVC = SFSafariViewController(url: url)
        present(safariVC, animated: true, completion: nil)
    }

    @objc func handleDateOfBirthChange() {
        formValidation()
    }
    
    @objc func formValidation() {
        guard
            firstNameTextField.hasText,
            lastNameTextField.hasText,
            usernameTextField.hasText,
            emailTextField.hasText,
            passwordTextField.hasText,
            repasswordTextField.hasText,
            isTermsAccepted,
            isDateOfBirthValid() else {
            updateSignUpButtonState(isFormValid: false)
            return
        }
        
        let isEmailValid = self.isEmailValid(emailTextField.text ?? "")
        let isPasswordValid = self.isPasswordValid(passwordTextField.text ?? "")
        let doPasswordsMatch = passwordTextField.text == repasswordTextField.text
        
        if isEmailValid && isPasswordValid && doPasswordsMatch && isTermsAccepted && isDateOfBirthValid() {
            updateSignUpButtonState(isFormValid: true)
        } else {
            updateSignUpButtonState(isFormValid: false)
        }
    }
    
    func updateSignUpButtonState(isFormValid: Bool) {
        signUpButton.isEnabled = isFormValid
        signUpButton.backgroundColor = isFormValid ? UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1) : UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
    }
    
    func isDateOfBirthValid() -> Bool {
        let calendar = Calendar.current
        let currentDate = Date()
        let birthDate = dateOfBirthPicker.date
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: currentDate)
        if let age = ageComponents.year, age >= 16 {
            return true
        } else {
            return false
        }
    }
    
    @objc func handleSelectProfilePhoto() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func togglePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        passwordTextField.isSecureTextEntry.toggle()
    }
    
    @objc func toggleRePasswordVisibility(_ sender: UIButton) {
        sender.isSelected.toggle()
        repasswordTextField.isSecureTextEntry.toggle()
    }
    
    func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        let minLength = password.count >= 8
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasSpecialCharacter = password.rangeOfCharacter(from: .symbols) != nil || password.rangeOfCharacter(from: .punctuationCharacters) != nil
        return minLength && hasUppercase && hasSpecialCharacter
    }
    
    func configureViewComponents() {
        let nameStackView = UIStackView(arrangedSubviews: [firstNameTextField, lastNameTextField])
        nameStackView.axis = .horizontal
        nameStackView.spacing = 10
        nameStackView.distribution = .fillEqually

        let dobStackView = UIStackView(arrangedSubviews: [dateOfBirthLabel, dateOfBirthPicker])
        dobStackView.axis = .horizontal
        dobStackView.spacing = 10
        dobStackView.distribution = .fill

        dateOfBirthPicker.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let termsStackView = UIStackView(arrangedSubviews: [checkbox, termsLabel])
        termsStackView.axis = .horizontal
        termsStackView.spacing = 10
        termsStackView.distribution = .fillProportionally

        let stackView = UIStackView(arrangedSubviews: [
            nameStackView,
            usernameTextField,
            dobStackView,
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
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let profileImage = info[.editedImage] as? UIImage else {
            imageSelected = false
            return
        }
        
        imageSelected = true
        
        plusPhotoBtn.layer.cornerRadius = plusPhotoBtn.frame.width / 2
        plusPhotoBtn.layer.masksToBounds = true
        plusPhotoBtn.layer.borderColor = UIColor.black.cgColor
        plusPhotoBtn.layer.borderWidth = 2
        plusPhotoBtn.setImage(profileImage.withRenderingMode(.alwaysOriginal), for: .normal)
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func handleSignUp() {
        guard let firstName = firstNameTextField.text, !firstName.isEmpty else { return }
        guard let lastName = lastNameTextField.text, !lastName.isEmpty else { return }
        guard let username = usernameTextField.text?.lowercased(), !username.isEmpty else { return }
        guard let email = emailTextField.text, !email.isEmpty else { return }
        guard let password = passwordTextField.text, !password.isEmpty else { return }

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
                   // guard let fcmToken = Messaging.messaging().fcmToken else { return }

                    
                    let dictionaryValues: [String: Any] = [
                        "firstName": firstName,
                        "lastName": lastName,
                        "username": username,
                        "profileImageUrl": profileImageUrl
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
}
