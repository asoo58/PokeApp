import SwiftUI
import FirebaseAuth

/// Gère la session Firebase : inscription, connexion (email ou Google), déconnexion.
@MainActor
@Observable
final class AuthViewModel {
    private(set) var user: User?
    private(set) var isBusy = false
    var errorMessage: String?

    /// Gardé vivant pendant le flux OAuth, sinon le ticket peut être libéré trop tôt.
    private var googleProvider: OAuthProvider?

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

    /// Connexion avec Google via le flux web officiel Firebase Auth.
    /// Aucun SDK Google supplémentaire n'est nécessaire.
    func signInWithGoogle() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let provider = OAuthProvider(providerID: "google.com")
            googleProvider = provider
            let credential = try await provider.credential(with: nil)
            let result = try await Auth.auth().signIn(with: credential)
            user = result.user
            errorMessage = nil
            googleProvider = nil
        } catch {
            errorMessage = error.localizedDescription
            googleProvider = nil
        }
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
