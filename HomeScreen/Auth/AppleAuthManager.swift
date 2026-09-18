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
    
    func startSignInWithAppleFlow(completion: @escaping (Result<(idToken: String, nonce: String, fullName: String?), Error>) -> Void) {
        self.completionHandler = completion
        
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - Delegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get Apple ID credential"])))
            return
        }
        
        guard let nonce = currentNonce else {
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: A login callback was received, but no login request was sent."])))
            return
        }
        
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])))
            return
        }
        
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
        
        completionHandler?(.success((idToken: idTokenString, nonce: nonce, fullName: fullName)))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            // User cancelled, don't return a hard error, just fail silently or handle explicitly
            completionHandler?(.failure(NSError(domain: "AppleAuth", code: 999, userInfo: [NSLocalizedDescriptionKey: "User cancelled."])))
            return
        }
        completionHandler?(.failure(error))
    }
    
    // MARK: - Presentation Context Providing
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
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
