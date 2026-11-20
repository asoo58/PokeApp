import XCTest
import PokemonAPI
@testable import AlexisAsya

/// Les favoris appartiennent au compte Firebase connecté : changer de compte
/// ne doit jamais afficher les favoris d'un autre utilisateur.
@MainActor
final class PerUserFavoritesTests: XCTestCase {
    private func makePokemon(id: Int, name: String) throws -> PKMPokemon {
        let json = """
        {"id": \(id), "name": "\(name)", "past_types": [], "past_abilities": []}
        """
        return try PKMPokemon.decoder.decode(PKMPokemon.self, from: Data(json.utf8))
    }

    func testFavoritesAreIsolatedAndPersistedPerUser() throws {
        let uidA = "tmp-A-\(UUID().uuidString)"
        let uidB = "tmp-B-\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: "pokeapp.favorites.\(uidA)")
            UserDefaults.standard.removeObject(forKey: "pokeapp.favorites.\(uidB)")
        }

        let a = PokemonFavoriteViewModel(userID: uidA)
        let b = PokemonFavoriteViewModel(userID: uidB)
        let pikachu = try makePokemon(id: 25, name: "pikachu")

        a.add(pikachu)

        XCTAssertTrue(a.isFavorite(pikachu))
        XCTAssertFalse(b.isFavorite(pikachu))

        let reloadedA = PokemonFavoriteViewModel(userID: uidA)
        let reloadedB = PokemonFavoriteViewModel(userID: uidB)
        XCTAssertTrue(reloadedA.isFavorite(pikachu))
        XCTAssertFalse(reloadedB.isFavorite(pikachu))
    }
}
