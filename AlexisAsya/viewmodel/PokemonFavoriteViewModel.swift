//
// Add a pokemon to a favorite List
//

import SwiftUI
import PokemonAPI

@Observable
class PokemonFavoriteViewModel {
    var favorites: [PKMPokemon] = []

    /// Identifiant Firebase du compte connecté. `nil` = invité (tests et avant login) :
    /// dans ce cas les favoris restent uniquement en mémoire, comme avant.
    private let userID: String?

    private var storageKey: String? {
        guard let userID else { return nil }
        return "pokeapp.favorites.\(userID)"
    }

    // Plusieurs tapes rapides sur l'étoile ne doivent compter que pour une.
    private var toggleGuard = DebouncedAction(interval: 0.35)

    init(userID: String? = nil) {
        self.userID = userID
        load()
    }

    func add(_ pokemon: PKMPokemon) {
        guard !isFavorite(pokemon) else { return }
        favorites.append(pokemon)
        save()
    }

    func remove(_ pokemon: PKMPokemon) {
        favorites.removeAll { $0.id == pokemon.id }
        save()
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

    // MARK: - Sauvegarde par compte

    private func load() {
        guard let storageKey,
              let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PKMPokemon].self, from: data) else { return }
        favorites = decoded
    }

    private func save() {
        guard let storageKey,
              let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
