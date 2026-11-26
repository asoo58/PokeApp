import SwiftUI
import UIKit
import WidgetKit

// MARK: - Modèle affiché par le widget

struct WidgetStat: Identifiable {
    let id: String
    let label: String
    let value: Int
}

struct WidgetPokemon {
    let name: String
    let number: Int
    let types: [String]
    let stats: [WidgetStat]
    let abilities: [String]
    let height: Int          // en dm (PokeAPI)
    let weight: Int          // en hg (PokeAPI)
    let experience: Int?
    let image: UIImage?
    let color: Color

    var bestStat: WidgetStat? { stats.max { $0.value < $1.value } }

    static func typeName(_ raw: String) -> String {
        switch raw {
        case "normal": return "Normal"
        case "fire": return "Feu"
        case "water": return "Eau"
        case "grass": return "Plante"
        case "electric": return "Électrik"
        case "ice": return "Glace"
        case "fighting": return "Combat"
        case "poison": return "Poison"
        case "ground": return "Sol"
        case "flying": return "Vol"
        case "psychic": return "Psy"
        case "bug": return "Insecte"
        case "rock": return "Roche"
        case "ghost": return "Spectre"
        case "dragon": return "Dragon"
        case "dark": return "Ténèbres"
        case "steel": return "Acier"
        case "fairy": return "Fée"
        default: return raw.capitalized
        }
    }

    static func statLabel(_ raw: String) -> String {
        switch raw {
        case "hp": return "PV"
        case "attack": return "ATQ"
        case "defense": return "DÉF"
        case "special-attack": return "ATQ SPÉ"
        case "special-defense": return "DÉF SPÉ"
        case "speed": return "VIT"
        default: return raw.capitalized
        }
    }

    static func abilityName(_ slug: String) -> String {
        slug.split(separator: "-")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    // MARK: Données de secours (affichées immédiatement, même sans réseau)

    private static func stats(_ values: [Int]) -> [WidgetStat] {
        let raw = ["hp", "attack", "defense", "special-attack", "special-defense", "speed"]
        return zip(raw, values).map { key, value in
            WidgetStat(id: key, label: statLabel(key), value: value)
        }
    }

    static let all: [WidgetPokemon] = [
        .init(name: "Pikachu", number: 25, types: ["electric"],
              stats: stats([35, 55, 40, 50, 50, 90]),
              abilities: ["static", "lightning-rod"],
              height: 4, weight: 60, experience: 112, image: nil, color: .yellow),
        .init(name: "Bulbizarre", number: 1, types: ["grass", "poison"],
              stats: stats([45, 49, 49, 65, 65, 45]),
              abilities: ["overgrow", "chlorophyll"],
              height: 7, weight: 69, experience: 64, image: nil, color: .green),
        .init(name: "Salamèche", number: 4, types: ["fire"],
              stats: stats([39, 52, 43, 60, 50, 65]),
              abilities: ["blaze", "solar-power"],
              height: 6, weight: 85, experience: 62, image: nil, color: .orange),
        .init(name: "Carapuce", number: 7, types: ["water"],
              stats: stats([44, 48, 65, 50, 64, 43]),
              abilities: ["torrent", "rain-dish"],
              height: 5, weight: 90, experience: 66, image: nil, color: .blue),
        .init(name: "Dracaufeu", number: 6, types: ["fire", "flying"],
              stats: stats([78, 84, 78, 109, 85, 100]),
              abilities: ["blaze", "solar-power"],
              height: 17, weight: 905, experience: 267, image: nil, color: .red),
        .init(name: "Mewtwo", number: 150, types: ["psychic"],
              stats: stats([106, 110, 90, 154, 90, 130]),
              abilities: ["pressure", "unnerve"],
              height: 20, weight: 1220, experience: 340, image: nil, color: .pink),
        .init(name: "Évoli", number: 133, types: ["normal"],
              stats: stats([55, 55, 50, 45, 65, 55]),
              abilities: ["run-away", "adaptability", "anticipation"],
              height: 6, weight: 65, experience: 92, image: nil, color: .brown),
        .init(name: "Métamorph", number: 132, types: ["normal"],
              stats: stats([48, 48, 48, 48, 48, 48]),
              abilities: ["limber", "imposter"],
              height: 3, weight: 40, experience: 101, image: nil, color: .purple)
    ]
}

struct PokemonWidgetEntry: TimelineEntry {
    let date: Date
    let pokemon: WidgetPokemon
}

// MARK: - Récupération PokeAPI (image + stats + capacités)

enum WidgetDataService {

    static func loadPokemon(for base: WidgetPokemon) async -> WidgetPokemon {
        guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(base.number)") else {
            return base
        }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else { return base }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let api = try decoder.decode(APIPokemon.self, from: data)

            let spriteURL = api.sprites?.other?.officialArtwork?.frontDefault ?? api.sprites?.frontDefault
            let image = await loadImage(from: spriteURL)

            return WidgetPokemon(
                // On garde le nom français soigné de la liste locale.
                name: base.name,
                number: api.id ?? base.number,
                types: api.types?.compactMap { $0.type?.name } ?? base.types,
                stats: api.stats?.compactMap { stat in
                    guard let key = stat.stat?.name, let value = stat.baseStat else { return nil }
                    return WidgetStat(id: key, label: WidgetPokemon.statLabel(key), value: value)
                } ?? base.stats,
                abilities: api.abilities?.compactMap { $0.ability?.name } ?? base.abilities,
                height: api.height ?? base.height,
                weight: api.weight ?? base.weight,
                experience: api.baseExperience ?? base.experience,
                image: image ?? base.image,
                color: base.color
            )
        } catch {
            // Hors-ligne ou erreur réseau : les données de secours restent affichées.
            return base
        }
    }

    private static func loadImage(from urlString: String?) async -> UIImage? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let downloaded = UIImage(data: data) else { return nil }

        // On réduit l'image pour limiter la mémoire de la timeline du widget.
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            downloaded.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Décodage minimal (uniquement les champs utiles)

private struct APIPokemon: Decodable {
    let id: Int?
    let height: Int?
    let weight: Int?
    let baseExperience: Int?
    let stats: [APIStat]?
    let abilities: [APIAbility]?
    let types: [APIType]?
    let sprites: APISprites?
}

private struct APIStat: Decodable {
    let stat: APINamed?
    let baseStat: Int?
}

private struct APIAbility: Decodable {
    let ability: APINamed?
}

private struct APIType: Decodable {
    let type: APINamed?
}

private struct APINamed: Decodable {
    let name: String?
}

private struct APISprites: Decodable {
    let frontDefault: String?
    let other: APIOther?
}

private struct APIOther: Decodable {
    let officialArtwork: APIOfficialArtwork?

    enum CodingKeys: String, CodingKey {
        case officialArtwork = "official-artwork"
    }
}

private struct APIOfficialArtwork: Decodable {
    let frontDefault: String?
}
