import SwiftUI
import UIKit
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// Gère la session Firebase : inscription, connexion (email, Google ou Apple), déconnexion.
@MainActor
@Observable
final class AuthViewModel {
    private(set) var user: User?
    private(set) var isBusy = false
    var errorMessage: String?

    var isAuthenticated: Bool { user != nil }

    /// Firebase est configuré dans l'init de l'App : on ne touche pas à Auth ici,
    /// sinon on crashe avant la configuration.
    init() {}

    /// À appeler une fois l'app lancée pour retrouver une session existante.
    func restoreSession() {
        user = Auth.auth().currentUser
    }

    func signIn(email: String, password: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            user = result.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            user = result.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Connexion avec le SDK officiel GoogleSignIn-iOS, puis liaison du jeton à Firebase Auth.
    func signInWithGoogle() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw AuthError.googleConfigMissing
            }
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            guard let presenting = Self.topViewController() else {
                throw AuthError.noPresentingViewController
            }

            let signInResult: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(withPresenting: presenting) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: AuthError.googleTokenMissing)
                    }
                }
            }

            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw AuthError.googleTokenMissing
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: signInResult.user.accessToken.tokenString
            )
            let result = try await Auth.auth().signIn(with: credential)
            user = result.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fenêtre depuis laquelle Google présente son sélecteur de compte.
    private static func topViewController() -> UIViewController? {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var controller = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }

    /// Connexion avec Apple via le bouton natif « Sign in with Apple ».
    func signInWithApple() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let token = try await AppleSignInCoordinator.requestAuthorization()
            let credential = OAuthProvider.credential(providerID: .apple,
                                                      idToken: token.idToken,
                                                      rawNonce: token.rawNonce)
            let result = try await Auth.auth().signIn(with: credential)
            user = result.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        guard !isBusy else { return }
        do {
            try Auth.auth().signOut()
            user = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
