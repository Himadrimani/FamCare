import UIKit

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
