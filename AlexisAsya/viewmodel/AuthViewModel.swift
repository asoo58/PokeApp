import SwiftUI
import FirebaseAuth

/// Gère la session Firebase : inscription, connexion, déconnexion.
@MainActor
@Observable
final class AuthViewModel {
    private(set) var user: User?
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
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(email: String, password: String) async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            user = result.user
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
