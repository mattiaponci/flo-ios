import UIKit
import Firebase
import SafariServices
import UserNotifications

class SignUpVC: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, MessagingDelegate {
    
    // MARK: - Properties
    var isTermsAccepted = false
    var imageSelected = false
    var didFocusOnRepassword = false // variabile per sapere quando l'utente ha selezionato il campo Re-enter Password
    
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
        return tf
    }()
    
    let firstNameValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "empty field"
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    let lastNameTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Last Name"
        tf.backgroundColor = UIColor(white: 0, alpha: 0.03)
        tf.attributedPlaceholder = NSAttributedString(string: "Last Name", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        tf.textColor = .black
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 14)
        return tf
    }()
    
    let lastNameValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "empty field"
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
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
    
    let usernameValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "empty field"
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()
    
    let dateOfBirthLabel: UILabel = {
        let label = UILabel()
        label.text = "Date of Birth"
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .black
        return label
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
        tf.addTarget(self, action: #selector(handleEmailBeginEditing), for: .editingDidBegin)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        return tf
    }()
    
    let emailValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "wrong email"
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
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
        
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
        showHideButton.addTarget(self, action: #selector(togglePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        return tf
    }()
    
    let passwordValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "wrong password"
        label.font = UIFont.systemFont(ofSize: 8)
        label.textColor = .red
        label.numberOfLines = 0
        label.isHidden = true
        return label
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
        // Quando l'utente inizia a modificare Re-enter Password
        tf.addTarget(self, action: #selector(handleRePasswordBeginEditing), for: .editingDidBegin)
        tf.addTarget(self, action: #selector(formValidation), for: .editingChanged)
        
        let showHideButton = UIButton(type: .custom)
        showHideButton.setImage(UIImage(systemName: "eye"), for: .normal)
        showHideButton.setImage(UIImage(systemName: "eye.slash"), for: .selected)
        showHideButton.addTarget(self, action: #selector(toggleRePasswordVisibility), for: .touchUpInside)
        tf.rightView = showHideButton
        tf.rightViewMode = .always
        return tf
    }()
    
    let rePasswordValidationLabel: UILabel = {
        let label = UILabel()
        label.text = "passoword don't match"
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

        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        view.addSubview(plusPhotoBtn)
        plusPhotoBtn.anchor(top: view.topAnchor, left: nil, bottom: nil, right: nil, paddingTop: 60, paddingLeft: 0, paddingBottom: 0, paddingRight: 0, width: 90, height: 90)
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

   /* @objc func handleDateOfBirthChange() {
        formValidation()
    }*/
    
    @objc func handleDateOfBirthChange() {
        // Ogni volta che l'utente modifica la data, ricalcolo la validità del form
        formValidation()
    }


    
    @objc func handleEmailBeginEditing() {
        let firstNameEmpty = !(firstNameTextField.hasText)
        let lastNameEmpty = !(lastNameTextField.hasText)
        let usernameEmpty = !(usernameTextField.hasText)
        
        firstNameValidationLabel.isHidden = !firstNameEmpty
        lastNameValidationLabel.isHidden = !lastNameEmpty
        usernameValidationLabel.isHidden = !usernameEmpty
    }
    
    @objc func handleRePasswordBeginEditing() {
        didFocusOnRepassword = true
        let password = passwordTextField.text ?? ""
        let passwordIsValid = isPasswordValid(password)
        // Se la password non rispetta i criteri e non è vuota, mostra l'errore quando l'utente entra in re-enter password
        if !passwordIsValid && !password.isEmpty {
            passwordValidationLabel.isHidden = false
        }
    }
    
    @objc func formValidation() {
        // Nascondo tutti gli errori
        emailValidationLabel.isHidden = true
        passwordValidationLabel.isHidden = true
        rePasswordValidationLabel.isHidden = true
        
        let email = emailTextField.text ?? ""
        let password = passwordTextField.text ?? ""
        let repassword = repasswordTextField.text ?? ""
        
        let emailIsValid = isEmailValid(email)
        let passwordsMatch = (password == repassword)
        let passwordIsValid = isPasswordValid(password)
        
        // Mostra errore email se non valida e non vuota
        if !email.isEmpty && !emailIsValid {
            emailValidationLabel.text = "wrong email"
            emailValidationLabel.isHidden = false
        }
        
        // Se l'utente ha focalizzato il campo re-enter password
        if didFocusOnRepassword {
            // Se la password non rispetta i criteri e non è vuota
            if !passwordIsValid && !password.isEmpty {
                passwordValidationLabel.text = "At least a capital letter, a lowercase letter, a number and a special character"
                passwordValidationLabel.isHidden = false
            }
            
            // Se l'utente ha scritto almeno 8 caratteri in re-enter password e le due password non coincidono, mostra "non coincidono"
            if repassword.count >= 8 && !passwordsMatch {
                rePasswordValidationLabel.isHidden = false
            }
        }

        // Controlla se tutti i campi sono presenti, l'email è valida, la password è valida, le password coincidono,
        // l’utente ha accettato i termini e la data di nascita è valida (più di 16 anni)
        let allFieldsPresent = !email.isEmpty && !password.isEmpty && !repassword.isEmpty
        let allConditionsMet = allFieldsPresent && emailIsValid && passwordIsValid && passwordsMatch && isTermsAccepted && isDateOfBirthValid()
        
        updateSignUpButtonState(isFormValid: allConditionsMet)
    }
    func updateSignUpButtonState(isFormValid: Bool) {
        signUpButton.isEnabled = isFormValid
        signUpButton.backgroundColor = isFormValid ?
            UIColor(red: 17/255, green: 154/255, blue: 237/255, alpha: 1) :
            UIColor(red: 149/255, green: 204/255, blue: 244/255, alpha: 1)
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
        let hasDigit = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialCharacter = password.rangeOfCharacter(from: .symbols) != nil ||
                                  password.rangeOfCharacter(from: .punctuationCharacters) != nil
        
        return minLength && hasUppercase && hasDigit && hasSpecialCharacter
    }
    
    func configureViewComponents() {
        
        let dobStackView = UIStackView(arrangedSubviews: [dateOfBirthLabel, dateOfBirthPicker])
        dobStackView.axis = .horizontal
        dobStackView.spacing = 10
        dobStackView.distribution = .fill
        dateOfBirthPicker.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let termsStackView = UIStackView(arrangedSubviews: [checkbox, termsLabel])
        termsStackView.axis = .horizontal
        termsStackView.spacing = 10
        termsStackView.distribution = .fillProportionally


        signUpButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let stackView = UIStackView(arrangedSubviews: [
            firstNameTextField,
            firstNameValidationLabel,
            lastNameTextField,
            lastNameValidationLabel,
            usernameTextField,
            usernameValidationLabel,
            dobStackView,
            emailTextField,
            emailValidationLabel,
            passwordTextField,
            passwordValidationLabel,
            repasswordTextField,
            rePasswordValidationLabel,
            signUpButton,
            termsStackView
        ])
        
        stackView.axis = .vertical
        stackView.spacing = 10
        stackView.distribution = .fill
        view.addSubview(stackView)
        
        stackView.anchor(top: plusPhotoBtn.bottomAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 24, paddingLeft: 40, paddingBottom: 0, paddingRight: 40, width: 0, height: 0)
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
