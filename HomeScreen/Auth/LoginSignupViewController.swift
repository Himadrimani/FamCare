import UIKit
final class LoginSignupViewController: UIViewController {

    enum Mode: Equatable {
        case login
        case signup
    }

    private var cardView: UIView! = UIView()
    private var titleLabel: UILabel! = UILabel()
    private var subtitleLabel: UILabel! = UILabel()
    private var modeSegmentedControl: UISegmentedControl! = UISegmentedControl()
    private var nameTextField: UITextField! = UITextField()
    private var emailTextField: UITextField! = UITextField()
    private var passwordTextField: UITextField! = UITextField()
    private var confirmPasswordTextField: UITextField! = UITextField()
    private var primaryButton: UIButton! = UIButton(type: .system)
    private var switchModeButton: UIButton! = UIButton(type: .system)
    private var statusLabel: UILabel! = UILabel()
    
    private lazy var appleAuthManager = AppleAuthManager(window: self.view.window)

    var onAuthenticationComplete: (() -> Void)?
    private var isAuthenticating = false

    private lazy var forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var appleLoginButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Continue with Apple Account"
        config.image = UIImage(systemName: "applelogo")
        config.baseForegroundColor = .black
        config.imagePadding = 8
        
        let button = UIButton(configuration: config)
        button.backgroundColor = .white
        button.layer.cornerRadius = 22
        // We set font using an attributed title or directly on titleLabel. 
        // Direct assignment on titleLabel can be overridden by config, but let's configure the text attributes:
        button.configurationUpdateHandler = { btn in
            btn.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
                return outgoing
            }
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleAppleLogin), for: .touchUpInside)
        return button
    }()

    private var mode: Mode = .login {
        didSet {
            updateMode(animated: true)
        }
    }
    
    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemGroupedBackground
        
        // Form Stack
        let formStack = UIStackView()
        formStack.axis = .vertical
        formStack.spacing = 20
        formStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Email Field
        let emailLabel = UILabel()
        emailLabel.text = "Email"
        emailLabel.font = .systemFont(ofSize: 14, weight: .medium)
        emailLabel.textColor = .darkGray
        
        emailTextField.placeholder = "Enter your email"
        emailTextField.backgroundColor = .white
        emailTextField.layer.cornerRadius = 12
        emailTextField.setLeftPadding(16)
        emailTextField.keyboardType = .emailAddress
        emailTextField.autocapitalizationType = .none
        
        let emailStack = UIStackView(arrangedSubviews: [emailLabel, emailTextField])
        emailStack.axis = .vertical
        emailStack.spacing = 8
        
        // Password Field
        let passwordLabel = UILabel()
        passwordLabel.text = "Password"
        passwordLabel.font = .systemFont(ofSize: 14, weight: .medium)
        passwordLabel.textColor = .darkGray
        
        passwordTextField.placeholder = "Enter your password"
        passwordTextField.isSecureTextEntry = true
        passwordTextField.backgroundColor = .white
        passwordTextField.layer.cornerRadius = 12
        passwordTextField.setLeftPadding(16)
        
        var eyeConfig = UIButton.Configuration.plain()
        eyeConfig.image = UIImage(systemName: "eye.slash.fill")
        eyeConfig.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -16, bottom: 0, trailing: 0)
        let eyeButton = UIButton(configuration: eyeConfig)
        eyeButton.tintColor = .gray
        eyeButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        eyeButton.addAction(UIAction(handler: { [weak passwordTextField, weak eyeButton] _ in
            guard let field = passwordTextField, let btn = eyeButton else { return }
            field.isSecureTextEntry.toggle()
            let iconName = field.isSecureTextEntry ? "eye.slash.fill" : "eye.fill"
            btn.configuration?.image = UIImage(systemName: iconName)
        }), for: .touchUpInside)
        
        passwordTextField.rightView = eyeButton
        passwordTextField.rightViewMode = .always
        
        let passwordStack = UIStackView(arrangedSubviews: [passwordLabel, passwordTextField])
        passwordStack.axis = .vertical
        passwordStack.spacing = 8
        
        formStack.addArrangedSubview(emailStack)
        formStack.addArrangedSubview(passwordStack)
        
        // Constraints for text fields
        emailTextField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        passwordTextField.heightAnchor.constraint(equalToConstant: 48).isActive = true
        
        // Status Label
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        formStack.addArrangedSubview(statusLabel)
        
        // Primary Button
        primaryButton.backgroundColor = .systemBlue
        primaryButton.setTitle("Sign In", for: .normal)
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        primaryButton.layer.cornerRadius = 24
        primaryButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        primaryButton.addTarget(self, action: #selector(primaryButtonTapped), for: .touchUpInside)
        formStack.addArrangedSubview(primaryButton)
        
        // Forgot Password
        formStack.addArrangedSubview(forgotPasswordButton)
        
        // Divider Or
        let dividerStack = UIStackView()
        dividerStack.axis = .horizontal
        dividerStack.alignment = .center
        dividerStack.spacing = 16
        
        let line1 = UIView()
        line1.backgroundColor = .systemGray5
        line1.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        let orLabelText = UILabel()
        orLabelText.text = "Or"
        orLabelText.font = .systemFont(ofSize: 14)
        orLabelText.textColor = .gray
        
        let line2 = UIView()
        line2.backgroundColor = .systemGray5
        line2.heightAnchor.constraint(equalToConstant: 1).isActive = true
        
        dividerStack.addArrangedSubview(line1)
        dividerStack.addArrangedSubview(orLabelText)
        dividerStack.addArrangedSubview(line2)
        line1.widthAnchor.constraint(equalTo: line2.widthAnchor).isActive = true
        
        formStack.addArrangedSubview(dividerStack)
        
        // Apple Login
        appleLoginButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        formStack.addArrangedSubview(appleLoginButton)
        
        // Spacing before switch mode
        formStack.setCustomSpacing(32, after: appleLoginButton)
        
        // Switch Mode (Don't have an account? Sign up)
        let switchModeString = NSMutableAttributedString(
            string: "Don't have an account? ", 
            attributes: [.foregroundColor: UIColor.darkGray, .font: UIFont.systemFont(ofSize: 14)]
        )
        switchModeString.append(NSAttributedString(
            string: "Sign up", 
            attributes: [.foregroundColor: UIColor.systemBlue, .font: UIFont.systemFont(ofSize: 14, weight: .medium)]
        ))
        switchModeButton.setAttributedTitle(switchModeString, for: .normal)
        switchModeButton.addTarget(self, action: #selector(switchModeTapped), for: .touchUpInside)
        formStack.addArrangedSubview(switchModeButton)
        
        view.addSubview(formStack)
        
        NSLayoutConstraint.activate([
            formStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            formStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            formStack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureAppearance()
        updateMode(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mode = .login
        modeSegmentedControl.selectedSegmentIndex = 0
    }

    @IBAction private func modeChanged(_ sender: UISegmentedControl) {
        mode = sender.selectedSegmentIndex == 0 ? .login : .signup
    }

    @IBAction private func primaryButtonTapped(_ sender: UIButton) {
        guard !isAuthenticating else { return }
        view.endEditing(true)
        handleLogin()
    }
    
    @objc private func handleAppleLogin() {
        guard !isAuthenticating else { return }
        view.endEditing(true)
        
        setLoading(true)
        showStatus("Connecting to Apple...", isError: false)
        
        appleAuthManager.startSignInWithAppleFlow { [weak self] result in
            DispatchQueue.main.async {
                self?.processAppleAuthResult(result)
            }
        }
    }
    
    private func processAppleAuthResult(_ result: Result<(idToken: String, nonce: String, fullName: String?), Error>) {
        switch result {
        case .success(let data):
            Task { [weak self] in
                guard let self = self else { return }
                self.showStatus("Authenticating...", isError: false)
                do {
                    let authResult = try await DataManager.shared.signInWithApple(idToken: data.idToken, nonce: data.nonce, fullName: data.fullName)
                    await MainActor.run {
                        if authResult.profile != nil {
                            self.showStatus("Success.", isError: false)
                            self.promptAppleHealthPermission {
                                self.onAuthenticationComplete?()
                            }
                        } else {
                            // User authenticated via Apple but profile doesn't exist.
                            self.showStatus("Almost done! Please complete your profile.", isError: false)
                            self.setLoading(false)
                            
                            let signupVC = SignupFamilyViewController()
                            signupVC.onSignupComplete = self.onAuthenticationComplete
                            // Inject Apple user context if SignupFamilyViewController was updated to handle it,
                            // or for now, just push to signup where they create a new profile.
                            self.navigationController?.pushViewController(signupVC, animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.showStatus(error.localizedDescription, isError: true)
                        self.setLoading(false)
                    }
                }
            }
        case .failure(let error):
            setLoading(false)
            if (error as NSError).code != 999 { // 999 is our custom code for user cancelled
                showStatus(error.localizedDescription, isError: true)
            } else {
                showStatus("", isError: false)
            }
        }
    }

    @IBAction private func switchModeTapped(_ sender: UIButton) {
        mode = mode == .login ? .signup : .login
        modeSegmentedControl.selectedSegmentIndex = mode == .login ? 0 : 1
    }

    private func configureAppearance() {
        title = "Account"
        [nameTextField, emailTextField, passwordTextField, confirmPasswordTextField].forEach {
            $0?.delegate = self
        }
        statusLabel.text = nil
    }

    private func setupForgotPasswordButton() {
        // Handled in loadView
    }

    @objc private func forgotPasswordTapped() {
        guard !isAuthenticating else { return }
        view.endEditing(true)
        let resetVC = ForgotPasswordViewController()
        resetVC.prefilledEmail = emailTextField.text
        if let nav = navigationController {
            nav.pushViewController(resetVC, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: resetVC)
            present(nav, animated: true)
        }
    }

    private func updateMode(animated: Bool) {
        if self.mode == .signup {
            let signupVC = SignupFamilyViewController()
            signupVC.onSignupComplete = self.onAuthenticationComplete
            self.navigationController?.pushViewController(signupVC, animated: animated)
            return
        }
        
        let updates = {
            self.statusLabel.text = nil
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: updates)
        } else {
            updates()
        }
    }

    private func handleLogin() {
        guard isValidEmail(emailTextField.text) else {
            showStatus("Enter a valid email address.", isError: true)
            return
        }

        guard isValidPassword(passwordTextField.text) else {
            showStatus("Password must be at least 6 characters.", isError: true)
            return
        }

        let emailText = emailTextField.text ?? ""
        let passwordText = passwordTextField.text ?? ""

        // Real Supabase Auth only. No local/offline fallback: invalid credentials,
        // unknown accounts, network errors and missing profiles all surface as errors.
        self.performAuthentication(status: "Signing in...") {
            try await DataManager.shared.signIn(email: emailText, password: passwordText)
        }
    }

    private func performAuthentication(status: String, action: @escaping () async throws -> Profile) {
        setLoading(true)
        showStatus(status, isError: false)

        Task { [weak self] in
            do {
                _ = try await action()
                await MainActor.run {
                    self?.showStatus("Success.", isError: false)
                    self?.promptAppleHealthPermission {
                        self?.onAuthenticationComplete?()
                    }
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    let message: String
                    if let authError = error as? DataManager.AuthenticationError {
                        // Our own typed errors already carry safe, user-facing copy.
                        message = authError.errorDescription ?? "Something went wrong. Please try again."
                    } else {
                        // Map raw Supabase/network errors to safe messages (invalid creds ->
                        // "Incorrect email or password", offline, timeout, rate limit, etc.).
                        message = self.friendlyAuthErrorMessage(from: error)
                    }
                    self.showStatus(message, isError: true)
                    self.setLoading(false)
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        isAuthenticating = loading
        primaryButton.isEnabled = !loading
        switchModeButton.isEnabled = !loading
        modeSegmentedControl.isEnabled = !loading
        primaryButton.alpha = loading ? 0.65 : 1
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }

    private func isValidEmail(_ text: String?) -> Bool {
        return AuthValidator.isValidEmail(text)
    }

    private func isValidPassword(_ text: String?) -> Bool {
        return AuthValidator.isValidPassword(text)
    }


}

extension LoginSignupViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case nameTextField:
            emailTextField.becomeFirstResponder()
        case emailTextField:
            passwordTextField.becomeFirstResponder()
        case passwordTextField where mode == .signup:
            confirmPasswordTextField.becomeFirstResponder()
        default:
            textField.resignFirstResponder()
            primaryButtonTapped(primaryButton)
        }

        return true
    }
}

private extension UITextField {
    func setLeftPadding(_ width: CGFloat) {
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 1))
        leftView = paddingView
        leftViewMode = .always
    }
}
//
//  HealthKitOnboardingViewController.swift
//  HomeScreen
//

import UIKit
import HealthKit

class HealthKitOnboardingViewController: UIViewController {

    var onCompletion: (() -> Void)?

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "applewatch")
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemGreen
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sync Your Vitals"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Sleep, heart rate, and heart rate variability usually come from an Apple Watch or another compatible device that writes into Apple Health. We securely read them from Apple Health to calculate your wellness and share it with your family."
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let benefitsStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 20
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let continueButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Enable Apple Health", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        btn.backgroundColor = .systemGreen
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 14
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(benefitsStackView)
        view.addSubview(continueButton)

        let b1 = createBulletPoint(icon: "moon.stars.fill", color: .systemIndigo, title: "Sleep", desc: "Track your sleep stages and recovery.")
        let b2 = createBulletPoint(icon: "heart.fill", color: .systemPink, title: "Heart Rate", desc: "Follow your resting and active heart rate.")
        let b3 = createBulletPoint(icon: "waveform.path.ecg", color: .systemTeal, title: "Heart Rate Variability", desc: "Gauge recovery and stress resilience.")
        
        benefitsStackView.addArrangedSubview(b1)
        benefitsStackView.addArrangedSubview(b2)
        benefitsStackView.addArrangedSubview(b3)

        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            iconImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            benefitsStackView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            benefitsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            benefitsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func createBulletPoint(icon: String, color: UIColor, title: String, desc: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = color
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        let descLbl = UILabel()
        descLbl.text = desc
        descLbl.font = .systemFont(ofSize: 14, weight: .regular)
        descLbl.textColor = .secondaryLabel
        descLbl.numberOfLines = 0
        descLbl.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(imageView)
        container.addSubview(titleLbl)
        container.addSubview(descLbl)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 30),
            imageView.heightAnchor.constraint(equalToConstant: 30),

            titleLbl.topAnchor.constraint(equalTo: container.topAnchor),
            titleLbl.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 16),
            titleLbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            descLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 4),
            descLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            descLbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            descLbl.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    @objc private func continueTapped() {
        continueButton.isEnabled = false
        
        HealthKitService.shared.authorizeHealthKit { [weak self] result in
            Task { @MainActor in
                // The onboarding screen explains that health data is shared with family
                // members. A successful connect here is the user's explicit consent to
                // share; they can revoke it anytime from Profile → Apple Health.
                if case .success = result {
                    DataManager.shared.setFamilyHealthSharingConsent(true)
                }
                self?.onCompletion?()
            }
        }
    }
}

//
//  ForgotPasswordViewController.swift
//  HomeScreen
//
//  Free-plan password reset. The user enters their email and receives a Supabase
//  recovery link. Tapping that link opens the app via the `homescreenapp://reset-password`
//  deep link, and SceneDelegate then presents SetNewPasswordViewController.
//

import UIKit

final class ForgotPasswordViewController: UIViewController, UITextFieldDelegate {

    /// Optionally pre-fills the email field (e.g. what the user already typed on the login screen).
    var prefilledEmail: String?

    private var isBusy = false
    private var didSend = false

    // Free-plan built-in email is heavily rate-limited, so we throttle client-side too:
    // after a successful send the button is locked for a cooldown to prevent request spam.
    private let cooldownDuration = 60
    private var cooldownRemaining = 0
    private var cooldownTimer: Timer?

    deinit {
        cooldownTimer?.invalidate()
    }

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.keyboardDismissMode = .interactive
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "lock.rotation")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Reset Your Password"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter the email associated with your account and we'll send you a secure link to reset your password."
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var emailTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Email address"
        tf.keyboardType = .emailAddress
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.textContentType = .username
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.backgroundColor = .secondarySystemGroupedBackground
        tf.translatesAutoresizingMaskIntoConstraints = false
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }()

    private let sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send Reset Link", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Forgot Password"
        view.backgroundColor = .systemGroupedBackground
        emailTextField.delegate = self
        emailTextField.text = prefilledEmail
        setupLayout()
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(iconImageView)
        contentStack.setCustomSpacing(24, after: iconImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(28, after: subtitleLabel)
        contentStack.addArrangedSubview(emailTextField)
        contentStack.addArrangedSubview(sendButton)
        contentStack.addArrangedSubview(statusLabel)

        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -40),

            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            emailTextField.heightAnchor.constraint(equalToConstant: 48),
            sendButton.heightAnchor.constraint(equalToConstant: 50),

            spinner.centerXAnchor.constraint(equalTo: sendButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: sendButton.centerYAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        // Block while a request is in flight or during the post-send cooldown.
        guard !isBusy, cooldownRemaining == 0 else { return }
        view.endEditing(true)

        let email = (emailTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuthValidator.isValidEmail(email) else {
            showStatus("Please enter a valid email address.", isError: true)
            return
        }

        setLoading(true)
        showStatus("Sending reset link...", isError: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await DataManager.shared.sendPasswordReset(email: email)
                await MainActor.run {
                    self.setLoading(false)
                    self.didSend = true
                    // Privacy-safe: never confirm whether the email is registered.
                    self.showStatus("If an account exists for this email, you'll receive a password reset link. Open the email on this device and tap the link to set a new password. (Check your spam folder too.)", isError: false)
                    self.startCooldown()
                }
            } catch {
                let friendlyMessage = self.friendlyAuthErrorMessage(from: error)
                await MainActor.run {
                    self.setLoading(false)
                    self.showStatus(friendlyMessage, isError: true)
                    // Supabase already rate-limited us; enforce a cooldown before another attempt.
                    self.startCooldown()
                }
            }
        }
    }

    // MARK: - Cooldown

    private func startCooldown() {
        cooldownTimer?.invalidate()
        cooldownRemaining = cooldownDuration
        updateCooldownButton()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.cooldownRemaining -= 1
            if self.cooldownRemaining <= 0 {
                self.cooldownRemaining = 0
                timer.invalidate()
                self.cooldownTimer = nil
            }
            self.updateCooldownButton()
        }
    }

    private func updateCooldownButton() {
        if cooldownRemaining > 0 {
            sendButton.isEnabled = false
            sendButton.alpha = 0.65
            sendButton.setTitle("Resend in \(cooldownRemaining)s", for: .normal)
        } else {
            sendButton.isEnabled = true
            sendButton.alpha = 1
            sendButton.setTitle(didSend ? "Resend Link" : "Send Reset Link", for: .normal)
        }
    }

    // MARK: - Helpers

    private func setLoading(_ loading: Bool) {
        isBusy = loading
        if loading {
            sendButton.isEnabled = false
            sendButton.alpha = 0.65
            sendButton.setTitle("", for: .normal)
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            // Don't re-enable if a cooldown is still counting down.
            if cooldownRemaining > 0 {
                updateCooldownButton()
            } else {
                sendButton.isEnabled = true
                sendButton.alpha = 1
                sendButton.setTitle(didSend ? "Resend Link" : "Send Reset Link", for: .normal)
            }
        }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        sendTapped()
        return true
    }
}

//
//  SetNewPasswordViewController.swift
//  HomeScreen
//
//  Shown after the user opens the password-reset deep link. A valid recovery session
//  is already established by SceneDelegate, so the user just chooses a new password.
//

final class SetNewPasswordViewController: UIViewController, UITextFieldDelegate {

    /// Called after the password is successfully updated (used to route back to login).
    var onPasswordReset: (() -> Void)?

    private var isBusy = false

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.shield.fill")
        iv.tintColor = .systemGreen
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose a New Password"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter and confirm your new password below."
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var newPasswordTextField = makeField(placeholder: "New password")
    private lazy var confirmPasswordTextField = makeField(placeholder: "Confirm new password")

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Update Password", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "New Password"
        view.backgroundColor = .systemGroupedBackground
        [newPasswordTextField, confirmPasswordTextField].forEach { $0.delegate = self }
        setupLayout()
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }

    private func setupLayout() {
        view.addSubview(contentStack)
        contentStack.addArrangedSubview(iconImageView)
        contentStack.setCustomSpacing(24, after: iconImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(28, after: subtitleLabel)
        contentStack.addArrangedSubview(newPasswordTextField)
        contentStack.addArrangedSubview(confirmPasswordTextField)
        contentStack.addArrangedSubview(saveButton)
        contentStack.addArrangedSubview(statusLabel)

        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            newPasswordTextField.heightAnchor.constraint(equalToConstant: 48),
            confirmPasswordTextField.heightAnchor.constraint(equalToConstant: 48),
            saveButton.heightAnchor.constraint(equalToConstant: 50),

            spinner.centerXAnchor.constraint(equalTo: saveButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor)
        ])
    }

    private func makeField(placeholder: String) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.isSecureTextEntry = true
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.textContentType = .newPassword
        tf.layer.cornerRadius = 10
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor.separator.cgColor
        tf.backgroundColor = .secondarySystemGroupedBackground
        tf.translatesAutoresizingMaskIntoConstraints = false
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        tf.leftView = paddingView
        tf.leftViewMode = .always
        return tf
    }

    @objc private func saveTapped() {
        guard !isBusy else { return }
        view.endEditing(true)

        let newPassword = newPasswordTextField.text ?? ""
        let confirm = confirmPasswordTextField.text ?? ""

        if let passwordError = AuthValidator.passwordValidationError(newPassword) {
            showStatus(passwordError, isError: true)
            return
        }
        guard newPassword == confirm else {
            showStatus("Passwords do not match.", isError: true)
            return
        }

        setLoading(true)
        showStatus("Updating your password...", isError: false)

        Task { [weak self] in
            guard let self else { return }
            do {
                try await DataManager.shared.updatePassword(newPassword)
                await MainActor.run {
                    self.setLoading(false)
                    self.showStatus("Your password has been updated. You can now log in with your new password.", isError: false)
                    self.newPasswordTextField.isEnabled = false
                    self.confirmPasswordTextField.isEnabled = false
                    self.saveButton.isEnabled = false
                    self.saveButton.alpha = 0.65
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self.onPasswordReset?()
                    }
                }
            } catch {
                let friendlyMessage = self.friendlyAuthErrorMessage(from: error)
                await MainActor.run {
                    self.setLoading(false)
                    self.showStatus(friendlyMessage, isError: true)
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        isBusy = loading
        saveButton.isEnabled = !loading
        saveButton.alpha = loading ? 0.65 : 1
        saveButton.setTitle(loading ? "" : "Update Password", for: .normal)
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    private func showStatus(_ message: String, isError: Bool) {
        statusLabel.text = message
        statusLabel.textColor = isError ? .systemRed : .systemGreen
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == newPasswordTextField {
            confirmPasswordTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            saveTapped()
        }
        return true
    }
}
