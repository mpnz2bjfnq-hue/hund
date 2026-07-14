//
//  AuthService.swift
//  UppdragHund
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var currentUserID: String?
    private(set) var isSignedIn = false

    private var currentNonce: String?
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        currentUserID = Auth.auth().currentUser?.uid
        isSignedIn = Auth.auth().currentUser != nil
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUserID = user?.uid
            self?.isSignedIn = user != nil
        }
    }

    func prepareSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleSignIn(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .failure(let error):
            throw error
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthServiceError.invalidCredential
            }
            guard let nonce = currentNonce else {
                throw AuthServiceError.missingNonce
            }
            guard let tokenData = credential.identityToken,
                  let idTokenString = String(data: tokenData, encoding: .utf8) else {
                throw AuthServiceError.invalidToken
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            let authResult = try await Auth.auth().signIn(with: firebaseCredential)

            let displayName = credential.fullName.flatMap { components -> String? in
                let formatter = PersonNameComponentsFormatter()
                let name = formatter.string(from: components)
                return name.isEmpty ? nil : name
            }

            try await FriendsRepository.shared.ensureProfile(
                uid: authResult.user.uid,
                displayName: displayName ?? authResult.user.displayName ?? "Hundägare",
                email: credential.email ?? authResult.user.email
            )
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    enum AuthServiceError: LocalizedError {
        case invalidCredential
        case missingNonce
        case invalidToken

        var errorDescription: String? {
            "Inloggningen misslyckades. Försök igen."
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(status == errSecSuccess, "Unable to generate nonce")
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
