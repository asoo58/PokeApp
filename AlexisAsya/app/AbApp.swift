import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

@main
struct AlexisAsya: App {
    @State private var favoriteViewModel = PokemonFavoriteViewModel()
    @State private var authViewModel = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    ContentView()
                        .environment(favoriteViewModel)
                        .environment(authViewModel)
                } else {
                    LoginView(auth: authViewModel)
                }
            }
            .task {
                authViewModel.restoreSession()
            }
            .onChange(of: authViewModel.user?.uid) { _, uid in
                // Chaque compte Firebase a ses propres favoris.
                favoriteViewModel = PokemonFavoriteViewModel(userID: uid)
            }
            .onOpenURL { url in
                // GoogleSignIn rend la main à l'app après le choix du compte ;
                // Firebase gère également ses propres URLs de retour OAuth.
                if !GIDSignIn.sharedInstance.handle(url) {
                    _ = Auth.auth().canHandle(url)
                }
            }
        }
    }
}
