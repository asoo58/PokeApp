import SwiftUI
import PokemonAPI

@Observable
class PokemonListViewModel {
    private let pokemonAPI = PokemonAPI()
    // Le .task de la vue peut être rejoué (navigation, retour onglet).
    // Un seul chargement réseau à la fois évite les doublons et les races.
    private let listLoadGuard = SingleFlightAction()
    private let typesLoadGuard = SingleFlightAction()

    var allPokemonNames: [String] = []
    var filteredNames: [String] = []
    var pokemonTypes: [String: [String]] = [:]
    var isLoadingList = false
    var isLoadingTypes = false
    var typeLoadingProgress: Double = 0.0

    // Les 18 types de base (hors "unknown" et "shadow")
    private let allTypes = [
        "normal", "fire", "water", "grass", "electric", "psychic",
        "ice", "dragon", "dark", "fighting", "poison", "ground",
        "rock", "ghost", "steel", "fairy", "flying", "bug"
    ]

    func loadAllPokemonNames() async {
        await listLoadGuard.run {
            self.isLoadingList = true
            do {
                let result = try await self.pokemonAPI.pokemonService.fetchPokemonList(
                    paginationState: .initial(pageLimit: 1302)
                )
                self.allPokemonNames = result.results?.compactMap { $0.name } ?? []
                self.filteredNames = self.allPokemonNames
            } catch {
                print("Erreur chargement liste : \(error)")
            }
            self.isLoadingList = false

            // Précharger les types en arrière-plan juste après
            await self.preloadAllTypes()
        }
    }

    /// Fetch les 18 types en parallèle : chaque requête retourne
    /// la liste complète des Pokémon appartenant à ce type.
    func preloadAllTypes() async {
        await typesLoadGuard.run {
            self.isLoadingTypes = true
            self.typeLoadingProgress = 0.0

            await withTaskGroup(of: (String, [String]).self) { group in
                for type_ in self.allTypes {
                    group.addTask {
                        await self.fetchPokemonNames(forType: type_)
                    }
                }

                var completed = 0
                for await (type_, names) in group {
                    for name in names {
                        // Un Pokémon peut avoir plusieurs types : on append
                        if self.pokemonTypes[name] != nil {
                            if !self.pokemonTypes[name]!.contains(type_) {
                                self.pokemonTypes[name]!.append(type_)
                            }
                        } else {
                            self.pokemonTypes[name] = [type_]
                        }
                    }
                    completed += 1
                    self.typeLoadingProgress = Double(completed) / Double(self.allTypes.count)
                }
            }

            self.isLoadingTypes = false
            self.typeLoadingProgress = 1.0
        }
    }

    private func fetchPokemonNames(forType type_: String) async -> (String, [String]) {
        do {
            let result = try await pokemonAPI.pokemonService.fetchType(type_)
            let names = result.pokemon?.compactMap { $0.pokemon?.name } ?? []
            return (type_, names)
        } catch {
            print("Erreur chargement type \(type_) : \(error)")
            return (type_, [])
        }
    }

    func filterPokemon(query: String, selectedType: String? = nil) {
        let trimmed = query.lowercased().trimmingCharacters(in: .whitespaces)

        var result = trimmed.isEmpty
            ? allPokemonNames
            : allPokemonNames.filter { $0.hasPrefix(trimmed) }

        if let type_ = selectedType {
            result = result.filter { name in
                // Si les types ne sont pas encore chargés pour ce Pokémon,
                // on l'exclut (false) plutôt que de l'inclure par défaut
                pokemonTypes[name]?.contains(type_) ?? false
            }
        }

        filteredNames = result
    }

    /// Toujours utilisé par PokemonRowView pour enrichir le cache
    func cacheTypes(for name: String, types: [String]) {
        pokemonTypes[name] = types
    }
}
