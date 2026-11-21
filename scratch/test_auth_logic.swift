import Foundation
import CryptoKit

// Test Nonce generation and SHA-256
func randomNonceString(length: Int = 32) -> String {
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    assert(errorCode == errSecSuccess)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
    }
    return String(nonce)
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

let nonce1 = randomNonceString()
let hash1 = sha256(nonce1)
assert(nonce1.count == 32)
assert(hash1.count == 64)
print("✓ Nonce generation and SHA-256 verified: \(hash1)")

// Test name splitting logic
func splitName(_ fullName: String) -> (firstName: String, lastName: String) {
    let parts = fullName
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(separator: " ")
        .map(String.init)

    guard let firstName = parts.first else {
        return ("", "")
    }

    return (firstName, parts.dropFirst().joined(separator: " "))
}

let test1 = splitName("Naman Mittal")
assert(test1.firstName == "Naman" && test1.lastName == "Mittal")

let test2 = splitName("SingleName")
assert(test2.firstName == "SingleName" && test2.lastName == "")

let test3 = splitName("First Middle Last")
assert(test3.firstName == "First" && test3.lastName == "Middle Last")
print("✓ Name splitting logic verified")

print("ALL AUTH LOGIC TESTS PASSED!")
