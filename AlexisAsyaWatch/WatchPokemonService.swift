import Foundation
import Observation

/// Statistique de base (PV, attaque, défense…).
struct WatchStat: Identifiable, Equatable {
    let name: String
    let value: Int

    var id: String { name }
}

/// Capacité, avec l'information « cachée » comme sur l'iPhone.
struct WatchAbility: Identifiable, Equatable {
    let name: String
    let isHidden: Bool

    var id: String { name }
}

/// Petit modèle local : pas besoin de dépendance SPM pour l'app Watch.
struct WatchPokemon: Identifiable, Equatable {
    let id: Int
    let name: String
    let types: [String]
    let imageURL: URL?
    let stats: [WatchStat]
    let abilities: [WatchAbility]
    let height: Int?   // en dm (PokeAPI)
    let weight: Int?   // en hg (PokeAPI)
    let experience: Int?

    var displayName: String { name.capitalized }

    var bestStat: WatchStat? { stats.max { $0.value < $1.value } }

    static let fallback = WatchPokemon(
        id: 25,
        name: "pikachu",
        types: ["electric"],
        imageURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png"),
        stats: [
            WatchStat(name: "hp", value: 35),
            WatchStat(name: "attack", value: 55),
            WatchStat(name: "defense", value: 40),
            WatchStat(name: "special-attack", value: 50),
            WatchStat(name: "special-defense", value: 50),
            WatchStat(name: "speed", value: 90)
        ],
        abilities: [
            WatchAbility(name: "static", isHidden: false),
            WatchAbility(name: "lightning-rod", isHidden: true)
        ],
        height: 4,
        weight: 60,
        experience: 112
    )
}

/// Élément de la liste de recherche (nom + numéro du Pokédex).
struct WatchPokemonListItem: Identifiable, Codable, Hashable {
    let name: String
    let id: Int

    var displayName: String { name.capitalized }
    var number: String { String(format: "#%03d", id) }
}

@MainActor
@Observable
final class WatchPokemonViewModel {
    // MARK: - Pokémon affiché
    var current: WatchPokemon = .fallback
    var isLoading = false
    var errorMessage: String?

    // MARK: - Moteur de recherche
    var allPokemon: [WatchPokemonListItem] = []
    var searchText: String = ""
    var selectedType: String?
    var isLoadingList = false
    var isLoadingType = false
    var isLoadingTypes = false
    var listErrorMessage: String?

    private var typeCache: [String: [String]] = [:]

    // Garde-fous contre les interactions répétées (tapes sur l'étoile,
    // bouton Aléatoire, retour arrière qui relance .task, etc.).
    private var toggleGuard = DebouncedAction(interval: 0.35)
    private let randomGuard = SingleFlightAction()
    private let listGuard = SingleFlightAction()
    private let typeGuard = SingleFlightAction()
    private let allTypesGuard = SingleFlightAction()

    let allTypes = ["normal", "fire", "water", "grass", "electric", "psychic",
                    "ice", "dragon", "dark", "fighting", "poison", "ground",
                    "rock", "ghost", "steel", "fairy", "flying", "bug"]

    var filteredPokemon: [WatchPokemonListItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var result = allPokemon

        if !query.isEmpty {
            // Dès la première lettre : les Pokémon dont le nom COMMENCE par cette lettre.
            // Si l'utilisateur tape un chiffre, on filtre sur le numéro du Pokédex.
            let isNumber = query.allSatisfy(\.isNumber)
            result = result.filter { pokemon in
                isNumber
                    ? pokemon.number.contains(query) || String(pokemon.id).hasPrefix(query)
                    : pokemon.name.hasPrefix(query)
            }
        }

        if let type = selectedType, let names = typeCache[type] {
            let allowed = Set(names)
            result = result.filter { allowed.contains($0.name) }
        }

        return result
    }

    /// Premier type connu d'un Pokémon, d'après le cache des types.
    func typeName(for pokemon: String) -> String? {
        for type in allTypes {
            if let names = typeCache[type], names.contains(pokemon) {
                return type
            }
        }
        return nil
    }

    // MARK: - Favoris
    var favorites: [String] = UserDefaults.standard.stringArray(forKey: "watch.favorites") ?? [] {
        didSet { UserDefaults.standard.set(favorites, forKey: "watch.favorites") }
    }

    init() {
        allPokemon = Self.loadCachedList()
        typeCache = Self.loadCachedTypes()
    }

    /// Charge la liste complète des noms (avec cache hors-ligne).
    func loadAllPokemon() async {
        await listGuard.run {
            guard self.allPokemon.isEmpty else { return }
            self.isLoadingList = true
            self.listErrorMessage = nil
            defer { self.isLoadingList = false }

            let cached = Self.loadCachedList()
            if !cached.isEmpty {
                self.allPokemon = cached
                return
            }

            guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon?limit=1302") else {
                self.listErrorMessage = "Erreur de chargement."
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let decoded = try JSONDecoder().decode(PokemonListResponse.self, from: data)
                let items = decoded.results.compactMap { entry -> WatchPokemonListItem? in
                    guard let id = entry.pokemonID else { return nil }
                    return WatchPokemonListItem(name: entry.name, id: id)
                }
                self.allPokemon = items.sorted { $0.id < $1.id }
                if !self.allPokemon.isEmpty {
                    Self.saveCachedList(self.allPokemon)
                }
            } catch {
                self.listErrorMessage = "Impossible de charger la liste. Vérifiez la connexion."
            }
        }
    }

    /// Charge les Pokémon d'un type (une seule requête, puis cache).
    func loadTypesIfNeeded() async {
        await typeGuard.run {
            guard let type = self.selectedType, self.typeCache[type] == nil else { return }
            self.isLoadingType = true
            defer { self.isLoadingType = false }

            do {
                self.typeCache[type] = try await Self.fetchTypeNames(type)
                Self.saveCachedTypes(self.typeCache)
            } catch {
                self.listErrorMessage = "Impossible de charger le type \(type)."
            }
        }
    }

    /// Charge les 18 types en arrière-plan pour colorier chaque résultat de recherche.
    func loadAllTypesIfNeeded() async {
        await allTypesGuard.run {
            let missing = self.allTypes.filter { self.typeCache[$0] == nil }
            guard !missing.isEmpty else { return }
            self.isLoadingTypes = true
            defer { self.isLoadingTypes = false }

            await withTaskGroup(of: (String, [String]?).self) { group in
                for type in missing {
                    group.addTask {
                        (type, try? await Self.fetchTypeNames(type))
                    }
                }
                for await (type, names) in group {
                    if let names { self.typeCache[type] = names }
                }
            }
            Self.saveCachedTypes(self.typeCache)
        }
    }

    /// Charge le Pokémon sélectionné pour la vue détail.
    func pokemon(named name: String) async throws -> WatchPokemon {
        try await fetchPokemon(name.lowercased())
    }

    func loadRandom() async {
        await randomGuard.run {
            self.isLoading = true
            self.errorMessage = nil
            defer { self.isLoading = false }

            let randomID = Int.random(in: 1...1025)
            do {
                self.current = try await self.fetchPokemon(String(randomID))
            } catch {
                self.current = .fallback
                self.errorMessage = "Mode hors-ligne : Pokémon de secours."
            }
        }
    }

    func toggleFavorite(_ pokemon: WatchPokemon) {
        toggleGuard.run(key: pokemon.name) {
            var names = self.favorites
            if names.contains(pokemon.name) {
                names.removeAll { $0 == pokemon.name }
            } else {
                names.append(pokemon.name)
            }
            self.favorites = names
        }
    }

    func isFavorite(_ pokemon: WatchPokemon) -> Bool {
        favorites.contains(pokemon.name)
    }

    // MARK: - Réseau

    private static func fetchTypeNames(_ type: String) async throws -> [String] {
        guard let url = URL(string: "https://pokeapi.co/api/v2/type/\(type)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(PokemonTypeResponse.self, from: data)
        return decoded.pokemon.map(\.pokemon.name)
    }

    private func fetchPokemon(_ identifier: String) async throws -> WatchPokemon {
        guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(identifier)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        // PokeAPI utilise snake_case : base_stat, base_experience, is_hidden…
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decoded = try decoder.decode(PokemonResponse.self, from: data)
        return WatchPokemon(
            id: decoded.id,
            name: decoded.name,
            types: decoded.types.map(\.type.name),
            imageURL: URL(string: "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/\(decoded.id).png"),
            stats: decoded.stats.compactMap { slot in
                guard let name = slot.stat?.name, let value = slot.baseStat else { return nil }
                return WatchStat(name: name, value: value)
            },
            abilities: decoded.abilities.compactMap { slot in
                guard let name = slot.ability?.name else { return nil }
                return WatchAbility(name: name, isHidden: slot.isHidden ?? false)
            },
            height: decoded.height,
            weight: decoded.weight,
            experience: decoded.baseExperience
        )
    }

    // MARK: - Cache

    private static let listKey = "watch.pokemon.list"
    private static let typesKey = "watch.pokemon.types"

    private static func loadCachedList() -> [WatchPokemonListItem] {
        guard let data = UserDefaults.standard.data(forKey: listKey),
              let items = try? JSONDecoder().decode([WatchPokemonListItem].self, from: data) else {
            return []
        }
        return items
    }

    private static func saveCachedList(_ items: [WatchPokemonListItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: listKey)
    }

    private static func loadCachedTypes() -> [String: [String]] {
        guard let data = UserDefaults.standard.data(forKey: typesKey),
              let cache = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return [:]
        }
        return cache
    }

    private static func saveCachedTypes(_ cache: [String: [String]]) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: typesKey)
    }
}

// MARK: - Réponses PokeAPI

private struct PokemonResponse: Decodable {
    let id: Int
    let name: String
    let types: [TypeSlot]
    let stats: [StatSlot]
    let abilities: [AbilitySlot]
    let height: Int?
    let weight: Int?
    let baseExperience: Int?
}

private struct TypeSlot: Decodable {
    let type: TypeName
}

private struct TypeName: Decodable {
    let name: String
}

private struct StatSlot: Decodable {
    let stat: TypeName?
    let baseStat: Int?
}

private struct AbilitySlot: Decodable {
    let ability: TypeName?
    let isHidden: Bool?
}

private struct PokemonListResponse: Decodable {
    let results: [PokemonListEntry]
}

private struct PokemonListEntry: Decodable {
    let name: String
    let url: String

    /// Extrait l'identifiant de "https://pokeapi.co/api/v2/pokemon/25/".
    /// `split` ignore les composants vides : le dernier est donc bien "25".
    var pokemonID: Int? {
        guard let last = url.split(separator: "/").last else { return nil }
        return Int(last)
    }
}

private struct PokemonTypeResponse: Decodable {
    let pokemon: [TypeEntry]
}

private struct TypeEntry: Decodable {
    let pokemon: PokemonListEntry
}
