import SwiftUI
import FirebaseCore

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
        }
    }
}
