import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit
import UIKit

/// Pont entre le bouton natif « Sign in with Apple » et Firebase Auth.
/// Le nonce envoyé à Apple est haché (SHA-256) ; Firebase a besoin du nonce brut.
@MainActor
final class AppleSignInCoordinator: NSObject,
                                    ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {
    private typealias Continuation = CheckedContinuation<(idToken: String, rawNonce: String), Error>

    private var continuation: Continuation?
    private var rawNonce = ""
    private var controller: ASAuthorizationController?

    /// Gardé vivant pendant que la feuille Apple est ouverte.
    private static var active: AppleSignInCoordinator?

    static func requestAuthorization() async throws -> (idToken: String, rawNonce: String) {
        let coordinator = AppleSignInCoordinator()
        active = coordinator
        return try await withCheckedThrowingContinuation { continuation in
            coordinator.continuation = continuation
            coordinator.start()
        }
    }

    private func start() {
        rawNonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            + UUID().uuidString.replacingOccurrences(of: "-", with: "")

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(rawNonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        controller = authorizationController
        authorizationController.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // La feuille n'est présentée que depuis l'app au premier plan : une scène existe toujours.
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first!

        return windowScene.windows.first { $0.isKeyWindow }
            ?? windowScene.windows.first
            ?? UIWindow(windowScene: windowScene)
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { finish() }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: AuthError.appleTokenMissing)
            return
        }
        continuation?.resume(returning: (idToken, rawNonce))
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        defer { finish() }
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            continuation?.resume(throwing: AuthError.appleCanceled)
        } else {
            continuation?.resume(throwing: error)
        }
    }

    private func finish() {
        continuation = nil
        controller = nil
        Self.active = nil
    }
}

enum AuthError: LocalizedError {
    case appleTokenMissing
    case appleCanceled
    case googleConfigMissing
    case noPresentingViewController
    case googleTokenMissing

    var errorDescription: String? {
        switch self {
        case .appleTokenMissing:
            return "Apple n'a pas renvoyé de jeton d'identité. Réessaie."
        case .appleCanceled:
            return "Connexion Apple annulée."
        case .googleConfigMissing:
            return "Configuration Google introuvable dans GoogleService-Info.plist."
        case .noPresentingViewController:
            return "Impossible d'afficher la fenêtre de connexion Google."
        case .googleTokenMissing:
            return "Google n'a pas renvoyé de jeton d'identité. Réessaie."
        }
    }
}
