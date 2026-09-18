import UIKit

extension UIViewController {
    /// Presents a beautiful custom modal soft-prompt explaining why the app needs Apple Health access,
    /// before invoking the system HealthKit permissions dialog.
    func promptAppleHealthPermission(completion: @escaping () -> Void) {
        let promptVC = HealthPromptViewController()
        promptVC.completion = completion
        promptVC.modalPresentationStyle = .pageSheet
        if let sheet = promptVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        self.present(promptVC, animated: true, completion: nil)
    }
}

final class HealthPromptViewController: UIViewController {
    var completion: (() -> Void)?

    // MARK: - UI Components

    private let mainStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let iconContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemPink.withAlphaComponent(0.12)
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let heartIconView: UIImageView = {
        let img = UIImageView()
        img.image = UIImage(systemName: "heart.fill")
        img.tintColor = .systemPink
        img.contentMode = .scaleAspectFit
        img.translatesAutoresizingMaskIntoConstraints = false
        return img
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Connect Apple Health"
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.text = "Share wellness metrics so your family stays connected and reassured."
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let permissionsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 10
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let buttonStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Share Health Data", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemPink
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let notNowButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Not Now", for: .normal)
        button.setTitleColor(.secondaryLabel, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupHierarchy()
        setupLayout()
        setupActions()
        populatePermissions()
    }

    // MARK: - Setup

    private func setupHierarchy() {
        view.addSubview(mainStackView)
        view.addSubview(buttonStackView)

        mainStackView.addArrangedSubview(iconContainerView)
        iconContainerView.addSubview(heartIconView)
        
        mainStackView.addArrangedSubview(titleLabel)
        mainStackView.addArrangedSubview(captionLabel)
        mainStackView.addArrangedSubview(permissionsStack)

        buttonStackView.addArrangedSubview(connectButton)
        buttonStackView.addArrangedSubview(notNowButton)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Main content stack constraints
            mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // Icon container
            iconContainerView.widthAnchor.constraint(equalToConstant: 56),
            iconContainerView.heightAnchor.constraint(equalToConstant: 56),
            
            heartIconView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            heartIconView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            heartIconView.widthAnchor.constraint(equalToConstant: 28),
            heartIconView.heightAnchor.constraint(equalToConstant: 28),

            // Permissions block padding
            permissionsStack.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor, constant: 8),
            permissionsStack.trailingAnchor.constraint(equalTo: mainStackView.trailingAnchor, constant: -8),

            // Button stack constraints (pinned to bottom of sheet)
            buttonStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            buttonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            buttonStackView.topAnchor.constraint(greaterThanOrEqualTo: mainStackView.bottomAnchor, constant: 12),

            // Button heights
            connectButton.heightAnchor.constraint(equalToConstant: 48),
            notNowButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func populatePermissions() {
        let items: [(icon: String, color: UIColor, title: String, description: String)] = [
            ("figure.walk.circle.fill", .systemGreen, "Steps & Distance", "Share daily steps and distances covered."),
            ("moon.circle.fill", .systemIndigo, "Restful Sleep", "Share nightly sleep durations and cycles."),
            ("heart.circle.fill", .systemPink, "Vitals & Heart Rate", "Share average resting heart rates.")
        ]
        
        for item in items {
            let row = makePermissionRow(icon: item.icon, color: item.color, title: item.title, description: item.description)
            permissionsStack.addArrangedSubview(row)
        }
    }
    
    private func makePermissionRow(icon: String, color: UIColor, title: String, description: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 12
        container.alignment = .center
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iv = UIImageView()
        iv.image = UIImage(systemName: icon)
        iv.tintColor = color
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalToConstant: 26),
            iv.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 0
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor = .label
        
        let descLbl = UILabel()
        descLbl.text = description
        descLbl.font = .systemFont(ofSize: 12, weight: .regular)
        descLbl.textColor = .secondaryLabel
        descLbl.numberOfLines = 0
        
        textStack.addArrangedSubview(titleLbl)
        textStack.addArrangedSubview(descLbl)
        
        container.addArrangedSubview(iv)
        container.addArrangedSubview(textStack)
        
        return container
    }

    // MARK: - Actions

    private func setupActions() {
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        notNowButton.addTarget(self, action: #selector(notNowTapped), for: .touchUpInside)
    }

    @objc private func connectTapped() {
        connectButton.isEnabled = false
        connectButton.setTitle("Requesting access...", for: .normal)

        HealthKitService.shared.authorizeHealthKit { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismiss(animated: true) {
                    self?.completion?()
                }
            }
        }
    }

    @objc private func notNowTapped() {
        dismiss(animated: true) {
            self.completion?()
        }
    }
}

// MARK: - Friendly Authentication / Signup Error Messages

extension UIViewController {
    /// Converts raw backend/database/auth errors into short, friendly messages
    /// that are safe to show end users. Never surfaces internal details like
    /// Postgres "duplicate key" constraint violations or SQL text.
    func friendlyAuthErrorMessage(from error: Error) -> String {
        let raw = "\(error.localizedDescription) \(String(describing: error))".lowercased()

        // Email already in use (Supabase Auth) or unique constraint hit on Profiles.email
        if raw.contains("already registered")
            || raw.contains("already been registered")
            || raw.contains("user already exists")
            || raw.contains("duplicate key")
            || raw.contains("already exists")
            || raw.contains("23505")
            || raw.contains("unique constraint") {
            return "This email is already registered. Please try another email or log in."
        }

        // Invalid email format reported by backend
        if raw.contains("invalid email") || raw.contains("email address is invalid") {
            return "Please enter a valid email address."
        }

        // Weak password rejected by backend
        if raw.contains("password") && (raw.contains("weak") || raw.contains("at least") || raw.contains("should be")) {
            return "Please choose a stronger password (at least 6 characters)."
        }

        // Rate limiting. The built-in Supabase email provider allows only a small number of
        // auth emails per hour (project-wide), so a reset request can be throttled for a while.
        if raw.contains("over_email_send_rate_limit")
            || (raw.contains("email") && raw.contains("rate limit")) {
            return "Too many password reset emails have been requested. Please wait a while (up to an hour) and try again."
        }
        if raw.contains("rate limit")
            || raw.contains("you can only request this")
            || raw.contains("too many requests")
            || raw.contains("429") {
            return "Too many requests. Please wait a little while and try again."
        }

        // Network / connectivity problems
        if raw.contains("offline")
            || raw.contains("network")
            || raw.contains("timed out")
            || raw.contains("timeout")
            || raw.contains("connection")
            || raw.contains("internet")
            || raw.contains("could not connect")
            || raw.contains("-1009")
            || raw.contains("-1001") {
            return "You appear to be offline. Check your internet connection and try again."
        }

        // Invalid / expired one-time code (password recovery)
        if raw.contains("otp")
            || raw.contains("token has expired")
            || raw.contains("invalid token")
            || raw.contains("token is invalid")
            || raw.contains("token not found")
            || raw.contains("expired") {
            return "That reset link is invalid or has expired. Please request a new one."
        }

        // Wrong credentials
        if raw.contains("invalid login")
            || raw.contains("invalid credentials")
            || raw.contains("wrong password")
            || raw.contains("incorrect") {
            return "Incorrect email or password. Please try again."
        }

        // Fallback: generic, non-scary message
        return "Something went wrong. Please try again in a moment."
    }
}

// MARK: - Shared Authentication Validation

/// Central place for the auth screens' email/password validation so the rules stay
/// consistent across Login, Sign Up (Join/Create Family), Forgot Password and Set New
/// Password. Previously each screen used its own ad-hoc `contains("@")` check.
enum AuthValidator {
    /// Minimum password length. Matches the Supabase project's `minimum_password_length`.
    static let minPasswordLength = 6
    /// Maximum password length. bcrypt (used by Supabase Auth) only considers the first
    /// 72 bytes, and longer values are rejected server-side, so we guard for it up front.
    static let maxPasswordLength = 72

    /// Real email-format check (local-part @ domain . TLD). Trims surrounding whitespace.
    static func isValidEmail(_ email: String?) -> Bool {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return false
        }
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return email.range(of: pattern, options: [.regularExpression]) != nil
    }

    /// Returns a user-facing error message if the password is invalid, or `nil` if it is fine.
    /// Passwords are never trimmed (leading/trailing spaces can be intentional).
    static func passwordValidationError(_ password: String?) -> String? {
        let password = password ?? ""
        if password.count < minPasswordLength {
            return "Password must be at least \(minPasswordLength) characters."
        }
        if password.utf8.count > maxPasswordLength {
            return "Password must be \(maxPasswordLength) characters or fewer."
        }
        return nil
    }

    /// Convenience: whether the password satisfies the min/max rules.
    static func isValidPassword(_ password: String?) -> Bool {
        passwordValidationError(password) == nil
    }
}
