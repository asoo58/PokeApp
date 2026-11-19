//
// Add a pokemon to a favorite List
//

import SwiftUI
import PokemonAPI

@Observable
class PokemonFavoriteViewModel {
    var favorites: [PKMPokemon] = []

    // Plusieurs tapes rapides sur l'étoile ne doivent compter que pour une.
    private var toggleGuard = DebouncedAction(interval: 0.35)

    func add(_ pokemon: PKMPokemon) {
        guard !isFavorite(pokemon) else { return }
        favorites.append(pokemon)
    }

    func remove(_ pokemon: PKMPokemon) {
        favorites.removeAll { $0.id == pokemon.id }
    }

    func isFavorite(_ pokemon: PKMPokemon) -> Bool {
        favorites.contains { $0.id == pokemon.id }
    }

    func toggle(_ pokemon: PKMPokemon) {
        let key = "\(pokemon.id ?? -1)"
        toggleGuard.run(key: key) {
            if self.isFavorite(pokemon) {
                self.remove(pokemon)
            } else {
                self.add(pokemon)
            }
        }
    }
}
