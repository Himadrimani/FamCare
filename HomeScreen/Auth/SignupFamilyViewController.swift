import UIKit
import Supabase

// vMARK: - SignupFamilyViewController
// Pushed from LoginSignupViewController to let users choose their onboarding path.
final class SignupFamilyViewController: UIViewController {

    var onSignupComplete: (() -> Void)?

    // MARK: - Views
    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 18
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.05
        v.layer.shadowRadius = 14
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let headerStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Join Your Family"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose how you would like to get started"
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var joinCard: UIView = makeOptionCard(
        icon: "person.2.fill",
        title: "Join Existing Family",
        description: "Enter a code shared by a family member",
        action: #selector(joinFamilyTapped)
    )

    private lazy var createCard: UIView = makeOptionCard(
        icon: "house.fill",
        title: "Create New Family",
        description: "Start a new family group and invite others",
        action: #selector(createFamilyTapped)
    )

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Sign Up"
        navigationController?.navigationBar.tintColor = .systemBlue

        view.addSubview(cardView)
        cardView.addSubview(headerStack)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        cardView.addSubview(joinCard)
        cardView.addSubview(createCard)

        let pad: CGFloat = 20
        NSLayoutConstraint.activate([
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: pad),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -pad),

            headerStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            headerStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            headerStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),

            joinCard.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 28),
            joinCard.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            joinCard.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),

            createCard.topAnchor.constraint(equalTo: joinCard.bottomAnchor, constant: 14),
            createCard.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            createCard.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            createCard.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -28)
        ])
    }

    // MARK: - Actions
    @objc private func joinFamilyTapped() {
        let joinVC = JoinFamilyViewController()
        joinVC.onSignupComplete = onSignupComplete
        navigationController?.pushViewController(joinVC, animated: true)
    }

    @objc private func createFamilyTapped() {
        let createVC = CreateFamilyViewController()
        createVC.onSignupComplete = onSignupComplete
        navigationController?.pushViewController(createVC, animated: true)
    }

    // MARK: - Option Card Factory
    private func makeOptionCard(icon: String, title: String, description: String, action: Selector) -> UIView {
        let card = UIButton(type: .custom)
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addTarget(self, action: action, for: .touchUpInside)

        let iconBg = UIView()
        iconBg.backgroundColor = .systemBlue.withAlphaComponent(0.08)
        iconBg.layer.cornerRadius = 20
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.isUserInteractionEnabled = false

        let iconImage = UIImageView()
        iconImage.image = UIImage(systemName: icon)
        iconImage.tintColor = .systemBlue
        iconImage.contentMode = .scaleAspectFit
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconImage)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLbl.textColor = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let descLbl = UILabel()
        descLbl.text = description
        descLbl.font = .systemFont(ofSize: 13, weight: .regular)
        descLbl.textColor = .secondaryLabel
        descLbl.numberOfLines = 2
        descLbl.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView()
        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit
        chevron.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconBg)
        card.addSubview(titleLbl)
        card.addSubview(descLbl)
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 84),

            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),

            iconImage.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            iconImage.widthAnchor.constraint(equalToConstant: 20),
            iconImage.heightAnchor.constraint(equalToConstant: 20),

            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLbl.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            descLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 2),
            descLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            descLbl.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 14),
            chevron.heightAnchor.constraint(equalToConstant: 14)
        ])

        return card
    }
}

// MARK: - JoinFamilyViewController
final class JoinFamilyViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var onSignupComplete: (() -> Void)?
    private var isProcessing = false
    private let avatars = ["my_image", "sister_image", "father_image", "mother_image"]
    private var selectedAvatar = "my_image" {
        didSet { updateAvatarSelection() }
    }
    private var avatarImageViews: [UIImageView] = []
    private var customSelectedImage: UIImage?

    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 18
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.05
        v.layer.shadowRadius = 14
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Join Your Family"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter your referral code and profile details to get synced"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var referralTextField = makeTextField(placeholder: "Referral code (6 characters)", contentType: .none, keyboard: .default, isSecure: false)
    
    private let avatarSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "CHOOSE AVATAR OR CLICK CAMERA TO ADD PHOTO"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let avatarStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment = .center
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var nameTextField = makeTextField(placeholder: "Full name", contentType: .name, keyboard: .default, isSecure: false)
    private lazy var emailTextField = makeTextField(placeholder: "Email address", contentType: .emailAddress, keyboard: .emailAddress, isSecure: false)
    private lazy var passwordTextField = makeTextField(placeholder: "Password (min 6 chars)", contentType: .newPassword, keyboard: .default, isSecure: true)
    private lazy var confirmPasswordTextField = makeTextField(placeholder: "Confirm password", contentType: .password, keyboard: .default, isSecure: true)

    private lazy var dobTextField: UITextField = {
        let tf = makeTextField(placeholder: "Date of Birth (YYYY-MM-DD)", contentType: .none, keyboard: .default, isSecure: false)
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .wheels
        dp.maximumDate = Date()
        dp.addTarget(self, action: #selector(dobChanged(_:)), for: .valueChanged)
        tf.inputView = dp
        return tf
    }()

    @objc private func dobChanged(_ sender: UIDatePicker) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        dobTextField.text = formatter.string(from: sender.date)
    }

    private lazy var heightTextField = makeTextField(placeholder: "Height (cm)", contentType: .none, keyboard: .decimalPad, isSecure: false)
    private lazy var weightTextField = makeTextField(placeholder: "Weight (kg)", contentType: .none, keyboard: .decimalPad, isSecure: false)
    
    private let genderSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Male", "Female", "Others"])
        sc.selectedSegmentIndex = 2
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let signupButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Join Family & Sign Up", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()

        referralTextField.delegate = self
        nameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Join Family"

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(cardView)

        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(referralTextField)
        cardView.addSubview(avatarSectionLabel)
        cardView.addSubview(avatarStackView)
        setupAvatarPicker()

        cardView.addSubview(nameTextField)
        cardView.addSubview(emailTextField)
        cardView.addSubview(passwordTextField)
        cardView.addSubview(confirmPasswordTextField)
        cardView.addSubview(dobTextField)
        cardView.addSubview(heightTextField)
        cardView.addSubview(weightTextField)
        cardView.addSubview(genderSegment)

        signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        cardView.addSubview(signupButton)
        signupButton.addSubview(spinner)
        cardView.addSubview(statusLabel)

        let pad: CGFloat = 18

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),

            referralTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            referralTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            referralTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            referralTextField.heightAnchor.constraint(equalToConstant: 48),

            avatarSectionLabel.topAnchor.constraint(equalTo: referralTextField.bottomAnchor, constant: 18),
            avatarSectionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad + 4),

            avatarStackView.topAnchor.constraint(equalTo: avatarSectionLabel.bottomAnchor, constant: 8),
            avatarStackView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            avatarStackView.heightAnchor.constraint(equalToConstant: 62),

            nameTextField.topAnchor.constraint(equalTo: avatarStackView.bottomAnchor, constant: 18),
            nameTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            nameTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            nameTextField.heightAnchor.constraint(equalToConstant: 48),

            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 12),
            emailTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            emailTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            emailTextField.heightAnchor.constraint(equalToConstant: 48),

            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 12),
            passwordTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            passwordTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            passwordTextField.heightAnchor.constraint(equalToConstant: 48),

            confirmPasswordTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 12),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 48),

            dobTextField.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 12),
            dobTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            dobTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            dobTextField.heightAnchor.constraint(equalToConstant: 48),

            heightTextField.topAnchor.constraint(equalTo: dobTextField.bottomAnchor, constant: 12),
            heightTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            heightTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            heightTextField.heightAnchor.constraint(equalToConstant: 48),

            weightTextField.topAnchor.constraint(equalTo: heightTextField.bottomAnchor, constant: 12),
            weightTextField.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            weightTextField.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            weightTextField.heightAnchor.constraint(equalToConstant: 48),

            genderSegment.topAnchor.constraint(equalTo: weightTextField.bottomAnchor, constant: 12),
            genderSegment.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            genderSegment.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            genderSegment.heightAnchor.constraint(equalToConstant: 36),

            signupButton.topAnchor.constraint(equalTo: genderSegment.bottomAnchor, constant: 24),
            signupButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            signupButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            signupButton.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerYAnchor.constraint(equalTo: signupButton.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: signupButton.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: signupButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            statusLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -24)
        ])
    }

    private func setupAvatarPicker() {
        // Standard Avatars
        for avatar in avatars {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView()
            imageView.image = UIImage(named: avatar)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 22
            imageView.layer.borderWidth = 3
            imageView.layer.borderColor = UIColor.clear.cgColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isUserInteractionEnabled = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
            imageView.addGestureRecognizer(tap)
            imageView.accessibilityIdentifier = avatar

            container.addSubview(imageView)
            avatarStackView.addArrangedSubview(container)
            avatarImageViews.append(imageView)

            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 50),
                container.heightAnchor.constraint(equalToConstant: 50),
                imageView.widthAnchor.constraint(equalToConstant: 44),
                imageView.heightAnchor.constraint(equalToConstant: 44),
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }

        // Camera / Custom photo button
        let customContainer = UIView()
        customContainer.translatesAutoresizingMaskIntoConstraints = false

        let customImageView = UIImageView()
        customImageView.image = UIImage(systemName: "camera.fill")
        customImageView.tintColor = .systemBlue
        customImageView.contentMode = .center
        customImageView.backgroundColor = .systemBlue.withAlphaComponent(0.08)
        customImageView.clipsToBounds = true
        customImageView.layer.cornerRadius = 22
        customImageView.layer.borderWidth = 3
        customImageView.layer.borderColor = UIColor.clear.cgColor
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        customImageView.isUserInteractionEnabled = true

        let customTap = UITapGestureRecognizer(target: self, action: #selector(customAvatarTapped(_:)))
        customImageView.addGestureRecognizer(customTap)
        customImageView.accessibilityIdentifier = "custom"

        customContainer.addSubview(customImageView)
        avatarStackView.addArrangedSubview(customContainer)
        avatarImageViews.append(customImageView)

        NSLayoutConstraint.activate([
            customContainer.widthAnchor.constraint(equalToConstant: 50),
            customContainer.heightAnchor.constraint(equalToConstant: 50),
            customImageView.widthAnchor.constraint(equalToConstant: 44),
            customImageView.heightAnchor.constraint(equalToConstant: 44),
            customImageView.centerXAnchor.constraint(equalTo: customContainer.centerXAnchor),
            customImageView.centerYAnchor.constraint(equalTo: customContainer.centerYAnchor)
        ])

        updateAvatarSelection()
    }

    @objc private func avatarTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? UIImageView, let avatar = view.accessibilityIdentifier else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        selectedAvatar = avatar
    }

    @objc private func customAvatarTapped(_ gesture: UITapGestureRecognizer) {
        let alert = UIAlertController(title: "Add Profile Photo", message: "Take a photo or choose from library", preferredStyle: .actionSheet)
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .camera
                self.present(picker, animated: true, completion: nil)
            } else {
                let err = UIAlertController(title: "Error", message: "Camera not available", preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(err, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true, completion: nil)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func updateAvatarSelection() {
        for imageView in avatarImageViews {
            let isCustom = imageView.accessibilityIdentifier == "custom"
            let isSelected = imageView.accessibilityIdentifier == selectedAvatar
            
            UIView.animate(withDuration: 0.2) {
                imageView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                imageView.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
                
                if isCustom {
                    if let img = self.customSelectedImage {
                        imageView.image = img
                        imageView.contentMode = .scaleAspectFill
                    } else {
                        imageView.image = UIImage(systemName: "camera.fill")
                        imageView.contentMode = .center
                    }
                }
            }
        }
    }

    // Image Picker Delegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                self.customSelectedImage = image
                self.selectedAvatar = "custom"
                self.updateAvatarSelection()
            }
        }
    }

    private func makeTextField(placeholder: String, contentType: UITextContentType?, keyboard: UIKeyboardType, isSecure: Bool) -> UITextField {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 16, weight: .medium)
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        tf.backgroundColor = .secondarySystemGroupedBackground
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.textContentType = contentType
        tf.keyboardType = keyboard
        tf.isSecureTextEntry = isSecure
        tf.autocapitalizationType = isSecure ? .none : .words
        tf.autocorrectionType = isSecure ? .no : .default
        tf.returnKeyType = .next
        tf.translatesAutoresizingMaskIntoConstraints = false

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always

        return tf
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        scrollView.contentInset.bottom = inset + 12
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: - Signup Action
    @objc private func signupTapped() {
        guard !isProcessing else { return }
        let confirm = confirmPasswordTextField.text ?? ""
        let code = referralTextField.text ?? ""

        let dobStr = dobTextField.text ?? ""
        let heightStr = heightTextField.text ?? ""
        let weightStr = weightTextField.text ?? ""
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dobDate = formatter.date(from: dobStr) ?? Date()
        
        let height = Double(heightStr) ?? 170.0
        let weight = Double(weightStr) ?? 70.0
        
        let genderEnum: Gender
        switch genderSegment.selectedSegmentIndex {
        case 0: genderEnum = .male
        case 1: genderEnum = .female
        default: genderEnum = .others
        }

        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty, !code.isEmpty else {
            showStatus("Enter the family referral code.", isError: true)
            return
        }

        guard let fullName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !fullName.isEmpty else {
            showStatus("Enter your full name.", isError: true)
            return
        }

        guard AuthValidator.isValidEmail(email) else {
            showStatus("Enter a valid email address.", isError: true)
            return
        }

        if let passwordError = AuthValidator.passwordValidationError(password) {
            showStatus(passwordError, isError: true)
            return
        }

        guard password == confirm else {
            showStatus("Passwords do not match.", isError: true)
            return
        }

        setLoading(true)
        showStatus("Verifying referral code...", isError: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                // Pre-auth referral lookup via a SECURITY DEFINER RPC. Direct reads of the
                // Families / Profiles tables are no longer allowed for unauthenticated users
                // (row-level security), so we validate the code and read the current member
                // count through this function, which only exposes the target family's name
                // and member count — never the whole table.
                struct JoinFamilyInfo: Decodable {
                    let family_id: UUID
                    let family_name: String
                    let member_count: Int
                }

                let lookupResp = try await SupabaseManager.shared.client
                    .rpc("join_family_info", params: ["code": code.uppercased()])
                    .execute()

                let matches = try self.supabaseDecoder().decode([JoinFamilyInfo].self, from: lookupResp.data)
                guard let info = matches.first else {
                    self.showStatus("Invalid referral code. No family found.", isError: true)
                    self.setLoading(false)
                    return
                }

                // Enforce max 4 members per family
                if info.member_count >= 4 {
                    self.showStatus("This family already has 4 members (max limit). Cannot join.", isError: true)
                    self.setLoading(false)
                    return
                }

                let targetFamily = Family(
                    familyId: info.family_id,
                    familyName: info.family_name,
                    sharableCode: code.uppercased(),
                    createdBy: nil,
                    createdAt: Date(),
                    lastUpdatedAt: Date(),
                    isSynced: true
                )

                self.showStatus("Family found! Creating account...", isError: false)
                
                var profile = try await DataManager.shared.signUp(
                    fullName: fullName,
                    email: email,
                    password: password,
                    dob: dobDate,
                    heightCm: height,
                    weightKg: weight,
                    gender: genderEnum,
                    profilePicUrl: nil,
                    targetFamily: targetFamily
                )
                
                // Upload custom photo if selected
                var finalPhotoPath = "person.circle"
                if self.selectedAvatar == "custom", let customImage = self.customSelectedImage {
                    self.showStatus("Uploading photo...", isError: false)
                    if let uploadedURL = await ImageManager.shared.uploadImageToSupabase(customImage, for: profile.profileId) {
                        finalPhotoPath = uploadedURL
                    } else {
                        let localFilename = "profile_\(profile.profileId.uuidString).jpg"
                        if self.saveImageToDocumentsDirectory(customImage, fileName: localFilename) {
                            finalPhotoPath = localFilename
                        }
                    }
                } else {
                    finalPhotoPath = self.selectedAvatar
                }
                
                profile.profilePic = finalPhotoPath
                DataManager.shared.updateProfile(profile)
                
                self.showStatus("Welcome to \(targetFamily.familyName)! 🎉", isError: false)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.requestHealthKitPermissionAndComplete()
                }

            } catch {
                print("JoinFamily [error]: \(error)")
                let friendlyMessage = self.friendlyAuthErrorMessage(from: error)
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.showStatus(friendlyMessage, isError: true)
                    let alert = UIAlertController(title: "Couldn't Join Family", message: friendlyMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func saveImageToDocumentsDirectory(_ image: UIImage, fileName: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save image to doc dir: \(error)")
            return false
        }
    }

    private func requestHealthKitPermissionAndComplete() {
        self.showStatus("Requesting HealthKit permission...", isError: false)
        self.promptAppleHealthPermission { [weak self] in
            DispatchQueue.main.async {
                self?.onSignupComplete?()
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        isProcessing = loading
        signupButton.isEnabled = !loading
        signupButton.alpha = loading ? 0.65 : 1

        if loading {
            spinner.startAnimating()
            signupButton.setTitle("Processing...", for: .normal)
        } else {
            spinner.stopAnimating()
            signupButton.setTitle("Join Family & Sign Up", for: .normal)
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }

    private func splitName(_ fullName: String) -> (firstName: String, lastName: String) {
        let parts = fullName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        guard let firstName = parts.first else { return ("", "") }
        return (firstName, parts.dropFirst().joined(separator: " "))
    }

    private func supabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardISO = ISO8601DateFormatter()
        standardISO.formatOptions = [.withInternetDateTime]
        
        let fallbackFormats = [
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let fallbackFormatters: [DateFormatter] = fallbackFormats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let date = fractionalISO.date(from: raw) { return date }
            if let date = standardISO.date(from: raw) { return date }
            
            for formatter in fallbackFormatters {
                if let date = formatter.date(from: raw) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return decoder
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case referralTextField:
            nameTextField.becomeFirstResponder()
        case nameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            confirmPasswordTextField.becomeFirstResponder()
        case confirmPasswordTextField:
            textField.resignFirstResponder()
            signupTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - CreateFamilyViewController
final class CreateFamilyViewController: UIViewController, UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var onSignupComplete: (() -> Void)?
    private var isProcessing = false
    private let avatars = ["my_image", "sister_image", "father_image", "mother_image"]
    private var selectedAvatar = "my_image" {
        didSet { updateAvatarSelection() }
    }
    private var avatarImageViews: [UIImageView] = []
    private var customSelectedImage: UIImage?

    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 18
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.05
        v.layer.shadowRadius = 14
        v.layer.shadowOffset = CGSize(width: 0, height: 6)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Main Form Stack
    private let formContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Create Your Family"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Create a new family group, setup your account, and invite members"
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var familyNameTextField = makeTextField(placeholder: "Family name (e.g. The Sharmas)", contentType: .none, keyboard: .default, isSecure: false)

    private let avatarSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "CHOOSE AVATAR OR CLICK CAMERA TO ADD PHOTO"
        label.font = .systemFont(ofSize: 10, weight: .bold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let avatarStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .equalSpacing
        sv.alignment = .center
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var nameTextField = makeTextField(placeholder: "Full name", contentType: .name, keyboard: .default, isSecure: false)
    private lazy var emailTextField = makeTextField(placeholder: "Email address", contentType: .emailAddress, keyboard: .emailAddress, isSecure: false)
    private lazy var passwordTextField = makeTextField(placeholder: "Password (min 6 chars)", contentType: .newPassword, keyboard: .default, isSecure: true)
    private lazy var confirmPasswordTextField = makeTextField(placeholder: "Confirm password", contentType: .password, keyboard: .default, isSecure: true)

    private lazy var dobTextField: UITextField = {
        let tf = makeTextField(placeholder: "Date of Birth (YYYY-MM-DD)", contentType: .none, keyboard: .default, isSecure: false)
        let dp = UIDatePicker()
        dp.datePickerMode = .date
        dp.preferredDatePickerStyle = .wheels
        dp.maximumDate = Date()
        dp.addTarget(self, action: #selector(dobChanged(_:)), for: .valueChanged)
        tf.inputView = dp
        return tf
    }()

    @objc private func dobChanged(_ sender: UIDatePicker) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        dobTextField.text = formatter.string(from: sender.date)
    }

    private lazy var heightTextField = makeTextField(placeholder: "Height (cm)", contentType: .none, keyboard: .decimalPad, isSecure: false)
    private lazy var weightTextField = makeTextField(placeholder: "Weight (kg)", contentType: .none, keyboard: .decimalPad, isSecure: false)
    
    private let genderSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Male", "Female", "Others"])
        sc.selectedSegmentIndex = 2
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let signupButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Create Family & Sign Up", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let spinner: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Inline Success View Components
    private let successContainer: UIView = {
        let v = UIView()
        v.isHidden = true
        v.alpha = 0
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let checkmarkIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = .systemGreen
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let successTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Your Family is All Set! 🏡💛"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let successSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Take care of your beloved family's wellness — share this referral code so they can join your wellness circle and stay connected, always."
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let codeDisplayView: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemGroupedBackground
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.text = "CODE12"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy Code", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let getStartedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Get Started", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()

        familyNameTextField.delegate = self
        nameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
    }

    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        title = "Create Family"

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(cardView)

        // Add Form Container
        cardView.addSubview(formContainer)
        formContainer.addSubview(titleLabel)
        formContainer.addSubview(subtitleLabel)
        formContainer.addSubview(familyNameTextField)
        formContainer.addSubview(avatarSectionLabel)
        formContainer.addSubview(avatarStackView)
        setupAvatarPicker()

        formContainer.addSubview(nameTextField)
        formContainer.addSubview(emailTextField)
        formContainer.addSubview(passwordTextField)
        formContainer.addSubview(confirmPasswordTextField)
        formContainer.addSubview(dobTextField)
        formContainer.addSubview(heightTextField)
        formContainer.addSubview(weightTextField)
        formContainer.addSubview(genderSegment)

        signupButton.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        formContainer.addSubview(signupButton)
        signupButton.addSubview(spinner)
        formContainer.addSubview(statusLabel)

        // Add Success Container
        cardView.addSubview(successContainer)
        successContainer.addSubview(checkmarkIcon)
        successContainer.addSubview(successTitleLabel)
        successContainer.addSubview(successSubtitleLabel)
        successContainer.addSubview(codeDisplayView)
        codeDisplayView.addSubview(codeLabel)
        codeDisplayView.addSubview(copyButton)
        successContainer.addSubview(getStartedButton)

        copyButton.addTarget(self, action: #selector(copyCodeTapped), for: .touchUpInside)
        getStartedButton.addTarget(self, action: #selector(getStartedTapped), for: .touchUpInside)

        let pad: CGFloat = 18

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: pad),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -pad),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            // Form constraints
            formContainer.topAnchor.constraint(equalTo: cardView.topAnchor),
            formContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            formContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            formContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            titleLabel.topAnchor.constraint(equalTo: formContainer.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            titleLabel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            subtitleLabel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),

            familyNameTextField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 20),
            familyNameTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            familyNameTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            familyNameTextField.heightAnchor.constraint(equalToConstant: 48),

            avatarSectionLabel.topAnchor.constraint(equalTo: familyNameTextField.bottomAnchor, constant: 18),
            avatarSectionLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad + 4),

            avatarStackView.topAnchor.constraint(equalTo: avatarSectionLabel.bottomAnchor, constant: 8),
            avatarStackView.centerXAnchor.constraint(equalTo: formContainer.centerXAnchor),
            avatarStackView.heightAnchor.constraint(equalToConstant: 62),

            nameTextField.topAnchor.constraint(equalTo: avatarStackView.bottomAnchor, constant: 18),
            nameTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            nameTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            nameTextField.heightAnchor.constraint(equalToConstant: 48),

            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 12),
            emailTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            emailTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            emailTextField.heightAnchor.constraint(equalToConstant: 48),

            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 12),
            passwordTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            passwordTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            passwordTextField.heightAnchor.constraint(equalToConstant: 48),

            confirmPasswordTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 12),
            confirmPasswordTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            confirmPasswordTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 48),

            dobTextField.topAnchor.constraint(equalTo: confirmPasswordTextField.bottomAnchor, constant: 12),
            dobTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            dobTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            dobTextField.heightAnchor.constraint(equalToConstant: 48),

            heightTextField.topAnchor.constraint(equalTo: dobTextField.bottomAnchor, constant: 12),
            heightTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            heightTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            heightTextField.heightAnchor.constraint(equalToConstant: 48),

            weightTextField.topAnchor.constraint(equalTo: heightTextField.bottomAnchor, constant: 12),
            weightTextField.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            weightTextField.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            weightTextField.heightAnchor.constraint(equalToConstant: 48),

            genderSegment.topAnchor.constraint(equalTo: weightTextField.bottomAnchor, constant: 12),
            genderSegment.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            genderSegment.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            genderSegment.heightAnchor.constraint(equalToConstant: 36),

            signupButton.topAnchor.constraint(equalTo: genderSegment.bottomAnchor, constant: 24),
            signupButton.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            signupButton.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            signupButton.heightAnchor.constraint(equalToConstant: 52),

            spinner.centerYAnchor.constraint(equalTo: signupButton.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: signupButton.trailingAnchor, constant: -16),

            statusLabel.topAnchor.constraint(equalTo: signupButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: formContainer.leadingAnchor, constant: pad),
            statusLabel.trailingAnchor.constraint(equalTo: formContainer.trailingAnchor, constant: -pad),
            statusLabel.bottomAnchor.constraint(equalTo: formContainer.bottomAnchor, constant: -24),

            // Success View constraints
            successContainer.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 40),
            successContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: pad),
            successContainer.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -pad),
            successContainer.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -40),

            checkmarkIcon.topAnchor.constraint(equalTo: successContainer.topAnchor),
            checkmarkIcon.centerXAnchor.constraint(equalTo: successContainer.centerXAnchor),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 72),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 72),

            successTitleLabel.topAnchor.constraint(equalTo: checkmarkIcon.bottomAnchor, constant: 20),
            successTitleLabel.leadingAnchor.constraint(equalTo: successContainer.leadingAnchor),
            successTitleLabel.trailingAnchor.constraint(equalTo: successContainer.trailingAnchor),

            successSubtitleLabel.topAnchor.constraint(equalTo: successTitleLabel.bottomAnchor, constant: 12),
            successSubtitleLabel.leadingAnchor.constraint(equalTo: successContainer.leadingAnchor),
            successSubtitleLabel.trailingAnchor.constraint(equalTo: successContainer.trailingAnchor),

            codeDisplayView.topAnchor.constraint(equalTo: successSubtitleLabel.bottomAnchor, constant: 24),
            codeDisplayView.leadingAnchor.constraint(equalTo: successContainer.leadingAnchor),
            codeDisplayView.trailingAnchor.constraint(equalTo: successContainer.trailingAnchor),
            codeDisplayView.heightAnchor.constraint(equalToConstant: 80),

            codeLabel.centerYAnchor.constraint(equalTo: codeDisplayView.centerYAnchor, constant: -10),
            codeLabel.leadingAnchor.constraint(equalTo: codeDisplayView.leadingAnchor, constant: 16),
            codeLabel.trailingAnchor.constraint(equalTo: codeDisplayView.trailingAnchor, constant: -16),

            copyButton.topAnchor.constraint(equalTo: codeLabel.bottomAnchor, constant: 2),
            copyButton.centerXAnchor.constraint(equalTo: codeDisplayView.centerXAnchor),

            getStartedButton.topAnchor.constraint(equalTo: codeDisplayView.bottomAnchor, constant: 32),
            getStartedButton.leadingAnchor.constraint(equalTo: successContainer.leadingAnchor),
            getStartedButton.trailingAnchor.constraint(equalTo: successContainer.trailingAnchor),
            getStartedButton.heightAnchor.constraint(equalToConstant: 52),
            getStartedButton.bottomAnchor.constraint(equalTo: successContainer.bottomAnchor)
        ])
    }

    private func setupAvatarPicker() {
        // Standard Avatars
        for avatar in avatars {
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false

            let imageView = UIImageView()
            imageView.image = UIImage(named: avatar)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 22
            imageView.layer.borderWidth = 3
            imageView.layer.borderColor = UIColor.clear.cgColor
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.isUserInteractionEnabled = true

            let tap = UITapGestureRecognizer(target: self, action: #selector(avatarTapped(_:)))
            imageView.addGestureRecognizer(tap)
            imageView.accessibilityIdentifier = avatar

            container.addSubview(imageView)
            avatarStackView.addArrangedSubview(container)
            avatarImageViews.append(imageView)

            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 50),
                container.heightAnchor.constraint(equalToConstant: 50),
                imageView.widthAnchor.constraint(equalToConstant: 44),
                imageView.heightAnchor.constraint(equalToConstant: 44),
                imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }

        // Camera / Custom photo button
        let customContainer = UIView()
        customContainer.translatesAutoresizingMaskIntoConstraints = false

        let customImageView = UIImageView()
        customImageView.image = UIImage(systemName: "camera.fill")
        customImageView.tintColor = .systemBlue
        customImageView.contentMode = .center
        customImageView.backgroundColor = .systemBlue.withAlphaComponent(0.08)
        customImageView.clipsToBounds = true
        customImageView.layer.cornerRadius = 22
        customImageView.layer.borderWidth = 3
        customImageView.layer.borderColor = UIColor.clear.cgColor
        customImageView.translatesAutoresizingMaskIntoConstraints = false
        customImageView.isUserInteractionEnabled = true

        let customTap = UITapGestureRecognizer(target: self, action: #selector(customAvatarTapped(_:)))
        customImageView.addGestureRecognizer(customTap)
        customImageView.accessibilityIdentifier = "custom"

        customContainer.addSubview(customImageView)
        avatarStackView.addArrangedSubview(customContainer)
        avatarImageViews.append(customImageView)

        NSLayoutConstraint.activate([
            customContainer.widthAnchor.constraint(equalToConstant: 50),
            customContainer.heightAnchor.constraint(equalToConstant: 50),
            customImageView.widthAnchor.constraint(equalToConstant: 44),
            customImageView.heightAnchor.constraint(equalToConstant: 44),
            customImageView.centerXAnchor.constraint(equalTo: customContainer.centerXAnchor),
            customImageView.centerYAnchor.constraint(equalTo: customContainer.centerYAnchor)
        ])

        updateAvatarSelection()
    }

    @objc private func avatarTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? UIImageView, let avatar = view.accessibilityIdentifier else { return }
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        selectedAvatar = avatar
    }

    @objc private func customAvatarTapped(_ gesture: UITapGestureRecognizer) {
        let alert = UIAlertController(title: "Add Profile Photo", message: "Take a photo or choose from library", preferredStyle: .actionSheet)
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                picker.sourceType = .camera
                self.present(picker, animated: true, completion: nil)
            } else {
                let err = UIAlertController(title: "Error", message: "Camera not available", preferredStyle: .alert)
                err.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(err, animated: true)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true, completion: nil)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    private func updateAvatarSelection() {
        for imageView in avatarImageViews {
            let isCustom = imageView.accessibilityIdentifier == "custom"
            let isSelected = imageView.accessibilityIdentifier == selectedAvatar
            
            UIView.animate(withDuration: 0.2) {
                imageView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
                imageView.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
                
                if isCustom {
                    if let img = self.customSelectedImage {
                        imageView.image = img
                        imageView.contentMode = .scaleAspectFill
                    } else {
                        imageView.image = UIImage(systemName: "camera.fill")
                        imageView.contentMode = .center
                    }
                }
            }
        }
    }

    // Image Picker Delegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                self.customSelectedImage = image
                self.selectedAvatar = "custom"
                self.updateAvatarSelection()
            }
        }
    }

    private func makeTextField(placeholder: String, contentType: UITextContentType?, keyboard: UIKeyboardType, isSecure: Bool) -> UITextField {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 16, weight: .medium)
        tf.textColor = .label
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        tf.backgroundColor = .secondarySystemGroupedBackground
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.textContentType = contentType
        tf.keyboardType = keyboard
        tf.isSecureTextEntry = isSecure
        tf.autocapitalizationType = isSecure ? .none : .words
        tf.autocorrectionType = isSecure ? .no : .default
        tf.returnKeyType = .next
        tf.translatesAutoresizingMaskIntoConstraints = false

        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always

        return tf
    }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func keyboardWillShow(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let inset = frame.height - view.safeAreaInsets.bottom
        scrollView.contentInset.bottom = inset + 12
        scrollView.verticalScrollIndicatorInsets.bottom = inset
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }

    private func generate6DigitReferralCode() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    private func saveImageToDocumentsDirectory(_ image: UIImage, fileName: String) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent(fileName)
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Failed to save image to doc dir: \(error)")
            return false
        }
    }

    // MARK: - Signup Action
    @objc private func signupTapped() {
        guard !isProcessing else { return }
        view.endEditing(true)

        let familyName = familyNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let fullName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !fullName.isEmpty else {
            showStatus("Enter your full name.", isError: true)
            return
        }

        guard let email = emailTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              AuthValidator.isValidEmail(email) else {
            showStatus("Enter a valid email address.", isError: true)
            return
        }

        guard let password = passwordTextField.text else {
            showStatus("Password must be at least 6 characters.", isError: true)
            return
        }
        if let passwordError = AuthValidator.passwordValidationError(password) {
            showStatus(passwordError, isError: true)
            return
        }

        guard passwordTextField.text == confirmPasswordTextField.text else {
            showStatus("Passwords do not match.", isError: true)
            return
        }

        let dobStr = dobTextField.text ?? ""
        let heightStr = heightTextField.text ?? ""
        let weightStr = weightTextField.text ?? ""
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dobDate = formatter.date(from: dobStr) ?? Date()
        
        let height = Double(heightStr) ?? 170.0
        let weight = Double(weightStr) ?? 70.0
        
        let genderEnum: Gender
        switch genderSegment.selectedSegmentIndex {
        case 0: genderEnum = .male
        case 1: genderEnum = .female
        default: genderEnum = .others
        }

        setLoading(true)
        showStatus("Creating your family...", isError: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                // Generate alphanumeric 6 digit referral code
                let customReferralCode = self.generate6DigitReferralCode()

                var profile = try await DataManager.shared.signUp(
                    fullName: fullName,
                    email: email,
                    password: password,
                    dob: dobDate,
                    heightCm: height,
                    weightKg: weight,
                    gender: genderEnum,
                    profilePicUrl: nil
                )

                // Upload custom photo if selected
                var finalPhotoPath = "person.circle"
                if self.selectedAvatar == "custom", let customImage = self.customSelectedImage {
                    self.showStatus("Uploading photo...", isError: false)
                    if let uploadedURL = await ImageManager.shared.uploadImageToSupabase(customImage, for: profile.profileId) {
                        finalPhotoPath = uploadedURL
                    } else {
                        let localFilename = "profile_\(profile.profileId.uuidString).jpg"
                        if self.saveImageToDocumentsDirectory(customImage, fileName: localFilename) {
                            finalPhotoPath = localFilename
                        }
                    }
                } else {
                    finalPhotoPath = self.selectedAvatar
                }

                // Get the consistent referral code already generated for this family
                let existingCode = DataManager.shared.family?.sharableCode ?? customReferralCode

                // Update family code to 6 digit code, and update family name
                let finalFamilyName = (familyName != nil && !familyName!.isEmpty) ? familyName! : "\(profile.firstName)'s Family"
                await self.updateFamilyDetails(newName: finalFamilyName, code: existingCode, creatorId: profile.profileId, for: profile.familyId)

                // Update profile picture
                profile.profilePic = finalPhotoPath
                DataManager.shared.updateProfile(profile)

                DispatchQueue.main.async {
                    self.showSuccessScreen(code: existingCode)
                }

            } catch {
                print("CreateFamily [error]: \(error)")
                let friendlyMessage = self.friendlyAuthErrorMessage(from: error)
                DispatchQueue.main.async {
                    self.setLoading(false)
                    self.showStatus(friendlyMessage, isError: true)
                    let alert = UIAlertController(title: "Couldn't Create Family", message: friendlyMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func showSuccessScreen(code: String) {
        codeLabel.text = code
        view.endEditing(true)

        // Hide form, show success with smooth transition
        UIView.transition(with: cardView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            self.formContainer.isHidden = true
            self.successContainer.isHidden = false
            self.successContainer.alpha = 1
        }, completion: nil)
    }

    @objc private func copyCodeTapped() {
        UIPasteboard.general.string = codeLabel.text
        let alert = UIAlertController(title: "Copied!", message: "Referral code copied to clipboard.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func getStartedTapped() {
        self.showStatus("Requesting HealthKit permission...", isError: false)
        self.promptAppleHealthPermission { [weak self] in
            DispatchQueue.main.async {
                self?.onSignupComplete?()
            }
        }
    }

    private func updateFamilyDetails(newName: String, code: String, creatorId: UUID, for familyId: UUID) async {
        struct FamilyUpdate: Encodable {
            let familyName: String
            let sharableCode: String
            let createdBy: UUID
            let lastUpdatedAt: Date
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, enc in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = enc.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        do {
            // Update in Supabase
            try await SupabaseManager.shared.client
                .from("Families")
                .update(FamilyUpdate(familyName: newName, sharableCode: code, createdBy: creatorId, lastUpdatedAt: Date()))
                .eq("familyId", value: familyId.uuidString)
                .execute()

            let response = try await SupabaseManager.shared.client
                .from("Families")
                .select()
                .eq("familyId", value: familyId.uuidString)
                .execute()

            if var updatedFamily = try supabaseDecoder().decode([Family].self, from: response.data).first {
                updatedFamily.isSynced = true
                SQLiteHelper.shared.saveFamily(updatedFamily)
                DataManager.shared.family = updatedFamily
            }
        } catch {
            print("Failed to update family details on Supabase: \(error)")
            // Update locally anyway
            if var fam = DataManager.shared.family, fam.familyId == familyId {
                fam.familyName = newName
                fam.sharableCode = code
                fam.createdBy = creatorId
                fam.lastUpdatedAt = Date()
                fam.isSynced = false
                SQLiteHelper.shared.saveFamily(fam)
                DataManager.shared.family = fam
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        isProcessing = loading
        signupButton.isEnabled = !loading
        signupButton.alpha = loading ? 0.65 : 1

        if loading {
            spinner.startAnimating()
            signupButton.setTitle("Creating...", for: .normal)
        } else {
            spinner.stopAnimating()
            signupButton.setTitle("Create Family & Sign Up", for: .normal)
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }

    private func splitName(_ fullName: String) -> (firstName: String, lastName: String) {
        let parts = fullName.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").map(String.init)
        guard let firstName = parts.first else { return ("", "") }
        return (firstName, parts.dropFirst().joined(separator: " "))
    }

    private func supabaseDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standardISO = ISO8601DateFormatter()
        standardISO.formatOptions = [.withInternetDateTime]
        
        let fallbackFormats = [
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ssX",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            "yyyy-MM-dd'T'HH:mm:ssX",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd"
        ]
        let fallbackFormatters: [DateFormatter] = fallbackFormats.map { format in
            let f = DateFormatter()
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            return f
        }
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let date = fractionalISO.date(from: raw) { return date }
            if let date = standardISO.date(from: raw) { return date }
            
            for formatter in fallbackFormatters {
                if let date = formatter.date(from: raw) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
        }
        return decoder
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case familyNameTextField:
            nameTextField.becomeFirstResponder()
        case nameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField:
            confirmPasswordTextField.becomeFirstResponder()
        case confirmPasswordTextField:
            textField.resignFirstResponder()
            signupTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
