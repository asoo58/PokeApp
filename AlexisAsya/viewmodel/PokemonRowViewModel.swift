import SwiftUI
import PokemonAPI

@Observable
class PokemonRowViewModel {
    private let pokemonAPI = PokemonAPI()

    var types: [String] = []

    func loadTypes(name: String) async {
        do {
            let pokemon = try await pokemonAPI.pokemonService.fetchPokemon(name)
            types = pokemon.types?.compactMap { $0.type?.name } ?? []
        } catch {
            print("Erreur types pour \(name) : \(error)")
        }
    }
}
