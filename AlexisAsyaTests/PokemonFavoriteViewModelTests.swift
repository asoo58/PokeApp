import XCTest
import PokemonAPI
@testable import AlexisAsya

/// Protège le bouton « favori » : des tapes répétées ne doivent jamais
/// ajouter deux fois le même Pokémon, ni désynchroniser l'icône.
@MainActor
final class PokemonFavoriteViewModelTests: XCTestCase {

    private func makePokemon(id: Int, name: String) throws -> PKMPokemon {
        let json = """
        {"id": \(id), "name": "\(name)", "past_types": [], "past_abilities": []}
        """
        return try PKMPokemon.decoder.decode(PKMPokemon.self, from: Data(json.utf8))
    }

    func testAddingSamePokemonTwiceKeepsOneFavorite() throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")

        viewModel.add(pikachu)
        viewModel.add(pikachu)

        XCTAssertEqual(viewModel.favorites.count, 1)
        XCTAssertTrue(viewModel.isFavorite(pikachu))
    }

    func testTenRapidTapsEndWithSingleFavorite() throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")

        for _ in 0..<10 {
            viewModel.toggle(pikachu)
        }

        XCTAssertEqual(viewModel.favorites.count, 1)
        XCTAssertTrue(viewModel.isFavorite(pikachu))
    }

    func testSameIdWithDifferentInstancesIsStillOneFavorite() throws {
        let viewModel = PokemonFavoriteViewModel()
        let first = try makePokemon(id: 25, name: "pikachu")
        let second = try makePokemon(id: 25, name: "pikachu")

        viewModel.add(first)
        viewModel.add(second)

        XCTAssertEqual(viewModel.favorites.count, 1)
    }

    func testDifferentPokemonsAreBothFavorites() throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")
        let raichu = try makePokemon(id: 26, name: "raichu")

        for _ in 0..<5 { viewModel.toggle(pikachu) }
        for _ in 0..<5 { viewModel.toggle(raichu) }

        XCTAssertEqual(viewModel.favorites.count, 2)
        XCTAssertTrue(viewModel.isFavorite(pikachu))
        XCTAssertTrue(viewModel.isFavorite(raichu))
    }

    func testRemoveUnknownPokemonDoesNothing() throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")
        let missing = try makePokemon(id: 999, name: "missingno")

        viewModel.add(pikachu)
        viewModel.remove(missing)

        XCTAssertEqual(viewModel.favorites.count, 1)
        XCTAssertFalse(viewModel.isFavorite(missing))
    }

    func testIsFavoriteFollowsCurrentState() throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")

        XCTAssertFalse(viewModel.isFavorite(pikachu))

        viewModel.add(pikachu)
        XCTAssertTrue(viewModel.isFavorite(pikachu))

        viewModel.remove(pikachu)
        XCTAssertFalse(viewModel.isFavorite(pikachu))
    }

    func testToggleAfterDelayRemovesFavorite() async throws {
        let viewModel = PokemonFavoriteViewModel()
        let pikachu = try makePokemon(id: 25, name: "pikachu")

        viewModel.toggle(pikachu)
        XCTAssertEqual(viewModel.favorites.count, 1)

        // Un second clic intentionnel, après la fenêtre d'ignorance,
        // doit bien retirer le favori.
        try await Task.sleep(for: .milliseconds(400))
        viewModel.toggle(pikachu)

        XCTAssertEqual(viewModel.favorites.count, 0)
        XCTAssertFalse(viewModel.isFavorite(pikachu))
    }
}
