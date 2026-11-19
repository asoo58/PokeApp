import SwiftUI
import WidgetKit

// MARK: - Modèle

struct ComplicationPokemon {
    let name: String
    let number: Int
    let type: String
    let color: Color

    static let all: [ComplicationPokemon] = [
        .init(name: "Pikachu", number: 25, type: "electric", color: .yellow),
        .init(name: "Bulbizarre", number: 1, type: "grass", color: .green),
        .init(name: "Salamèche", number: 4, type: "fire", color: .orange),
        .init(name: "Carapuce", number: 7, type: "water", color: .blue),
        .init(name: "Mewtwo", number: 150, type: "psychic", color: .pink),
        .init(name: "Dracaufeu", number: 6, type: "fire", color: .red),
        .init(name: "Métamorph", number: 132, type: "normal", color: .purple),
        .init(name: "Evoli", number: 133, type: "normal", color: .brown)
    ]
}

struct PokemonComplicationEntry: TimelineEntry {
    let date: Date
    let pokemon: ComplicationPokemon
}

// MARK: - Timeline

struct PokemonComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PokemonComplicationEntry {
        entry(at: Date(), offset: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (PokemonComplicationEntry) -> Void) {
        completion(entry(at: Date(), offset: 0))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PokemonComplicationEntry>) -> Void) {
        let start = Date()
        let entries = (0..<8).map { index in
            entry(at: start.addingTimeInterval(1_800 * Double(index)), offset: index)
        }
        completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(14_400))))
    }

    private func entry(at date: Date, offset: Int) -> PokemonComplicationEntry {
        let all = ComplicationPokemon.all
        let index = (offset + Calendar.current.component(.hour, from: date)) % all.count
        return PokemonComplicationEntry(date: date, pokemon: all[index])
    }
}

// MARK: - Vue

struct PokemonComplicationEntryView: View {
    var entry: PokemonComplicationEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                circular
            case .accessoryRectangular:
                rectangular
            case .accessoryInline:
                inline
            default:
                rectangular
            }
        }
    }

    private var circular: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(entry.pokemon.color.opacity(0.35))
            VStack(spacing: 0) {
                Image(systemName: "bolt.fill")
                    .font(.caption)
                Text(entry.pokemon.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("POKÉAPP")
                    .font(.caption2)
                    .foregroundStyle(entry.pokemon.color)
                Spacer()
                Text(String(format: "#%03d", entry.pokemon.number))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(entry.pokemon.name)
                .font(.headline)
                .lineLimit(1)
            Text(entry.pokemon.type.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var inline: some View {
        Label("\(entry.pokemon.name) · #\(entry.pokemon.number)", systemImage: "star.fill")
    }
}

// MARK: - Widget

struct PokemonComplication: Widget {
    let kind = "PokemonComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PokemonComplicationProvider()) { entry in
            PokemonComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("PokéApp")
        .description("Un Pokémon sur votre cadran.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

#Preview(as: .accessoryRectangular) {
    PokemonComplication()
} timeline: {
    PokemonComplicationEntry(date: .now, pokemon: ComplicationPokemon.all[0])
}
