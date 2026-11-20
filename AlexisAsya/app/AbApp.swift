import SwiftUI
import FirebaseCore
import FirebaseAuth

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
                // Nécessaire au retour du flux OAuth Google.
                _ = Auth.auth().canHandle(url)
            }
        }
    }
}
