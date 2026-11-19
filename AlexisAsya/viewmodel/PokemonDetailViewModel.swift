//
// loadAllPokemonNames + filterPokemon
//

import SwiftUI
import PokemonAPI

@Observable
class PokemonDetailViewModel {
    private let pokemonAPI = PokemonAPI()
    // Les boutons Précédent/Suivant peuvent être tapés très vite : une seule
    // requête à la fois, pour éviter que la dernière réponse ne soit pas celle
    // du Pokémon affiché.
    private let loadGuard = SingleFlightAction()

    var pokemon: PKMPokemon? = nil
    var types: [String] = []
    var isLoading = true

    func loadPokemon(name: String) async {
        await loadGuard.run {
            self.isLoading = true
            do {
                let fetched = try await self.pokemonAPI.pokemonService.fetchPokemon(name)
                self.pokemon = fetched
                self.types = fetched.types?.compactMap { $0.type?.name } ?? []
            } catch {
                print("Erreur : \(error)")
            }
            self.isLoading = false
        }
    }
}
