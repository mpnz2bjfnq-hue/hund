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

    /// Namnet Firebase känner till (kan vara nil för vissa Apple-inloggningar).
    var currentDisplayName: String? {
        Auth.auth().currentUser?.displayName
    }

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
                displayName: displayName ?? authResult.user.displayName ?? String(localized: "Hundägare"),
                email: credential.email ?? authResult.user.email
            )
        }
    }

    // MARK: - E-post/lösenord

    /// Skapar ett nytt konto. Användaren skriver själv sina uppgifter i UI:t.
    func signUpWithEmail(name: String, email: String, password: String) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
            let change = result.user.createProfileChangeRequest()
            change.displayName = trimmedName
            try? await change.commitChanges()
            try await FriendsRepository.shared.ensureProfile(
                uid: result.user.uid,
                displayName: trimmedName.isEmpty ? String(localized: "Hundägare") : trimmedName,
                email: trimmedEmail
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let result = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
            // Säkerställ en profil även för konton skapade före profil-flödet fanns.
            try await FriendsRepository.shared.ensureProfile(
                uid: result.user.uid,
                displayName: result.user.displayName ?? String(localized: "Hundägare"),
                email: result.user.email
            )
        } catch {
            throw mapAuthError(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await Auth.auth().sendPasswordReset(withEmail: trimmedEmail)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Verifierar mot servern att kontot fortfarande existerar, via tvingad
    /// token-refresh. Den cachade ID-token är giltig upp till en timme efter
    /// att kontot raderats (t.ex. av admin), så utan denna koll kan en enhet
    /// fortsätta agera — och återskapa data — åt ett raderat konto.
    /// Nätverksfel räknas som "finns" så flakigt nät inte loggar ut någon.
    func accountStillExists() async -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        do {
            _ = try await user.getIDTokenResult(forcingRefresh: true)
            return true
        } catch {
            switch AuthErrorCode(rawValue: (error as NSError).code) {
            case .userNotFound, .userDisabled, .invalidUserToken, .userTokenExpired:
                return false
            default:
                return true
            }
        }
    }

    /// Översätter vanliga Firebase-authfel till svenska texter.
    private func mapAuthError(_ error: Error) -> Error {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        let message: String
        switch code {
        case .emailAlreadyInUse: message = String(localized: "Det finns redan ett konto med den e-postadressen.")
        case .invalidEmail: message = String(localized: "E-postadressen ser inte giltig ut.")
        case .weakPassword: message = String(localized: "Lösenordet är för svagt (minst 6 tecken).")
        case .wrongPassword, .invalidCredential: message = String(localized: "Fel e-post eller lösenord.")
        case .userNotFound: message = String(localized: "Inget konto hittades med den e-postadressen.")
        case .userDisabled: message = String(localized: "Kontot är inaktiverat.")
        case .networkError: message = String(localized: "Nätverksfel. Kontrollera din anslutning.")
        case .tooManyRequests: message = String(localized: "För många försök. Vänta en stund och försök igen.")
        default: message = String(localized: "Något gick fel. Försök igen.")
        }
        return NSError(
            domain: "AuthService",
            code: (error as NSError).code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    enum AuthServiceError: LocalizedError {
        case invalidCredential
        case missingNonce
        case invalidToken

        var errorDescription: String? {
            String(localized: "Inloggningen misslyckades. Försök igen.")
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
