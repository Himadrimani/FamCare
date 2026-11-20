import AuthenticationServices
import CryptoKit
import UIKit

final class AppleAuthManager: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    // Unhashed nonce string
    private var currentNonce: String?
    private var completionHandler: ((Result<(idToken: String, nonce: String, fullName: String?), Error>) -> Void)?
    private weak var presentingWindow: UIWindow?
    
    init(window: UIWindow?) {
        self.presentingWindow = window
    }
    
    func startSignInWithAppleFlow(presentingFrom window: UIWindow? = nil, completion: @escaping (Result<(idToken: String, nonce: String, fullName: String?), Error>) -> Void) {
        if let window = window {
            self.presentingWindow = window
        }
        self.completionHandler = completion
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // [STAGE 2] Authorization request created
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        print("[Auth Diagnostics][Stage 2] ASAuthorizationAppleIDRequest created with scopes [.fullName, .email] and sha256 nonce")
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        // [STAGE 3] Authorization sheet presented
        print("[Auth Diagnostics][Stage 3] ASAuthorizationController performing requests (sheet presented)")
        authorizationController.performRequests()
    }
    
    // MARK: - Delegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        // [STAGE 4] Apple authorization completed
        print("[Auth Diagnostics][Stage 4] Apple authorization completed successfully")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("[Auth Diagnostics][Stage 5 Failed] Credential is not ASAuthorizationAppleIDCredential")
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple ID credential"])))
            return
        }
        
        // [STAGE 5] ASAuthorizationAppleIDCredential received
        let hasEmail = appleIDCredential.email != nil
        let hasFullName = appleIDCredential.fullName != nil
        print("[Auth Diagnostics][Stage 5] ASAuthorizationAppleIDCredential received (hasEmail: \(hasEmail), hasFullName: \(hasFullName))")
        
        guard let nonce = currentNonce else {
            print("[Auth Diagnostics][Stage 8 Failed] Missing local nonce state")
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: A login callback was received, but no login request was sent."])))
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("[Auth Diagnostics][Stage 6 Failed] appleIDCredential.identityToken is nil")
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])))
            return
        }
        
        // [STAGE 6] Identity token extracted
        print("[Auth Diagnostics][Stage 6] Identity token data extracted (\(appleIDToken.count) bytes)")
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("[Auth Diagnostics][Stage 7 Failed] Failed to decode identity token data as UTF-8")
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to decode identity token as UTF-8"])))
            return
        }
        
        // [STAGE 7] Identity token successfully decoded as UTF-8
        print("[Auth Diagnostics][Stage 7] Identity token successfully decoded as UTF-8 (\(idTokenString.count) chars)")
        
        // Extract full name if available (only provided on first login)
        var fullName: String?
        if let name = appleIDCredential.fullName {
            let given = name.givenName ?? ""
            let family = name.familyName ?? ""
            let combined = "\(given) \(family)".trimmingCharacters(in: .whitespaces)
            if !combined.isEmpty {
                fullName = combined
            }
        }
        
        // [STAGE 8] Credential and required authentication parameters validated
        print("[Auth Diagnostics][Stage 8] Credential and required authentication parameters validated successfully")
        completionHandler?(.success((idToken: idTokenString, nonce: nonce, fullName: fullName)))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error
        let underlyingInfo = underlying != nil ? ", Underlying: \(underlying!.localizedDescription)" : ""
        print("[Auth Diagnostics][Stage 4 Failed] Apple authorization failed. Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription)\(underlyingInfo)")
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // User cancelled, don't return a hard error, just fail silently or handle explicitly
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 999, userInfo: [NSLocalizedDescriptionKey: "User cancelled."])))
                return
            case .unknown:
                let msg = "Apple Sign-In could not be completed (Error 1000). Please verify your device has an active internet connection, no VPN/Private Relay conflicts, and check Settings > Apple Account > Sign-In & Security > Sign in with Apple."
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1000, userInfo: [NSLocalizedDescriptionKey: msg, NSUnderlyingErrorKey: error])))
                return
            case .failed:
                let msg = "Apple Sign-In authorization failed. Please check your network connection and try again."
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1001, userInfo: [NSLocalizedDescriptionKey: msg, NSUnderlyingErrorKey: error])))
                return
            case .invalidResponse:
                let msg = "Received an invalid response from Apple authorization servers."
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1002, userInfo: [NSLocalizedDescriptionKey: msg, NSUnderlyingErrorKey: error])))
                return
            case .notHandled:
                let msg = "Apple Sign-In request was not handled. Please try again."
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1003, userInfo: [NSLocalizedDescriptionKey: msg, NSUnderlyingErrorKey: error])))
                return
            case .notInteractive:
                let msg = "Apple Sign-In requires user interaction."
                completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1004, userInfo: [NSLocalizedDescriptionKey: msg, NSUnderlyingErrorKey: error])))
                return
            @unknown default:
                break
            }
        }
        completionHandler?(.failure(error))
    }
    
    // MARK: - Presentation Context Providing
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = presentingWindow, window.windowScene != nil {
            return window
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            if let keyWindow = activeScene.windows.first(where: { $0.isKeyWindow }) ?? activeScene.windows.first {
                return keyWindow
            }
        }
        return presentingWindow ?? UIWindow()
    }
    
    // MARK: - Crypto Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}
