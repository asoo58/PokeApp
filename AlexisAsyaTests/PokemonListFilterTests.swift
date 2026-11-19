import XCTest
@testable import AlexisAsya

/// La recherche est pure : elle doit rester stable même si l'utilisateur
/// tape vite, vide le champ ou change de type plusieurs fois de suite.
@MainActor
final class PokemonListFilterTests: XCTestCase {

    private func makeViewModel() -> PokemonListViewModel {
        let viewModel = PokemonListViewModel()
        viewModel.allPokemonNames = ["pikachu", "pidgey", "raichu", "charmander", "bulbizarre"]
        viewModel.pokemonTypes = [
            "pikachu": ["electric"],
            "raichu": ["electric"],
            "charmander": ["fire"],
            "bulbizarre": ["grass", "poison"]
        ]
        return viewModel
    }

    func testFilterUsesPrefixFromFirstLetter() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "pi")

        XCTAssertEqual(viewModel.filteredNames, ["pikachu", "pidgey"])
    }

    func testFilterIsCaseInsensitiveAndTrimsWhitespace() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "  PIK  ")

        XCTAssertEqual(viewModel.filteredNames, ["pikachu"])
    }

    func testEmptyQueryReturnsEveryPokemon() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "   ")

        XCTAssertEqual(viewModel.filteredNames, viewModel.allPokemonNames)
    }

    func testUnknownPrefixReturnsEmptyList() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "zzz")

        XCTAssertTrue(viewModel.filteredNames.isEmpty)
    }

    func testTypeFilterUsesCachedTypes() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "", selectedType: "electric")

        XCTAssertEqual(viewModel.filteredNames, ["pikachu", "raichu"])
    }

    func testTypeWithoutCachedDataExcludesEverything() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "", selectedType: "water")

        XCTAssertTrue(viewModel.filteredNames.isEmpty)
    }

    func testPrefixAndTypeFiltersCombine() {
        let viewModel = makeViewModel()

        viewModel.filterPokemon(query: "ra", selectedType: "electric")

        XCTAssertEqual(viewModel.filteredNames, ["raichu"])
    }

    func testRepeatedFilterCallsGiveSameResult() {
        let viewModel = makeViewModel()

        for _ in 0..<20 {
            viewModel.filterPokemon(query: "pi", selectedType: nil)
        }

        XCTAssertEqual(viewModel.filteredNames, ["pikachu", "pidgey"])
    }
}
