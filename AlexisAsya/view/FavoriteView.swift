//
//  Affichage des Favoris
//

import SwiftUI
import PokemonAPI

struct FavoriteView: View {
    @Environment(PokemonFavoriteViewModel.self) private var favoriteViewModel

    var body: some View {
        NavigationStack {
            Group {
                if favoriteViewModel.favorites.isEmpty {
                    Spacer()
                    Text("Aucun favori pour l'instant")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(favoriteViewModel.favorites, id: \.id) { pokemon in
                        if let name = pokemon.name {
                            NavigationLink(destination: PokemonView(name: name)) {
                                PokemonRowView(name: name)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Favoris")
        }
    }
}

#Preview {
    FavoriteView()
        .environment(PokemonFavoriteViewModel())
}
