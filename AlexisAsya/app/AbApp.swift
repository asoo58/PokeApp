import SwiftUI

@main
struct AlexisAsya: App {
    @State private var favoriteViewModel = PokemonFavoriteViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(favoriteViewModel)
        }
    }
}
