import SwiftUI
import WidgetKit

// MARK: - Timeline (8 Pokémon, renouvelée toutes les 30 minutes)

struct PokemonWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PokemonWidgetEntry {
        PokemonWidgetEntry(date: Date(), pokemon: WidgetPokemon.all[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (PokemonWidgetEntry) -> Void) {
        // Date légèrement passée : évite le "missing entry" si le système
        // évalue l'instant courant quelques millisecondes avant la date créée.
        completion(PokemonWidgetEntry(
            date: Date().addingTimeInterval(-60),
            pokemon: WidgetPokemon.all[0]
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PokemonWidgetEntry>) -> Void) {
        let start = Date().addingTimeInterval(-60)

        Task {
            let pokemon = await Self.detailedPokemon()
            let entries = pokemon.indices.map { index in
                let offset = (index + Calendar.current.component(.hour, from: start)) % pokemon.count
                return PokemonWidgetEntry(
                    date: start.addingTimeInterval(1_800 * Double(index)),
                    pokemon: pokemon[offset]
                )
            }
            completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(14_400))))
        }
    }

    /// Enrichit les 8 Pokémon de secours avec l'image et les données PokeAPI.
    /// Si le réseau échoue, les données locales restent utilisées.
    private static func detailedPokemon() async -> [WidgetPokemon] {
        let base = WidgetPokemon.all
        return await withTaskGroup(of: (Int, WidgetPokemon).self) { group in
            for (index, pokemon) in base.enumerated() {
                group.addTask {
                    (index, await WidgetDataService.loadPokemon(for: pokemon))
                }
            }

            var result = base
            for await (index, pokemon) in group {
                result[index] = pokemon
            }
            return result
        }
    }
}

// MARK: - Pokéball de secours (quand l'image n'est pas disponible)

private struct PokeballMark: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle().fill(.white)
            VStack(spacing: 0) {
                color
                Color.white
            }
            .clipShape(Circle())
            Rectangle()
                .fill(Color.black.opacity(0.8))
                .frame(height: 2)
            Circle()
                .fill(.white)
                .frame(width: 11, height: 11)
            Circle()
                .stroke(Color.black.opacity(0.8), lineWidth: 2)
                .frame(width: 11, height: 11)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct StatBar: View {
    let stat: WidgetStat

    var body: some View {
        HStack(spacing: 4) {
            Text(stat.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 26, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * min(CGFloat(stat.value) / 200, 1))
                }
            }
            .frame(height: 5)
            Text("\(stat.value)")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, alignment: .trailing)
        }
    }
}

// MARK: - Vues selon la famille

struct PokemonWidgetEntryView: View {
    var entry: PokemonWidgetEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall: smallView
            case .systemMedium: mediumView
            case .accessoryCircular: circularView
            case .accessoryRectangular: rectangularView
            case .accessoryInline: inlineView
            default: smallView
            }
        }
    }

    private var abilityList: String {
        entry.pokemon.abilities.prefix(2)
            .map(WidgetPokemon.abilityName)
            .joined(separator: ", ")
    }

    private var background: some View {
        ContainerRelativeShape()
            .fill(
                LinearGradient(
                    colors: [
                        entry.pokemon.color.opacity(0.92),
                        entry.pokemon.color.opacity(0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func sprite(_ size: CGFloat) -> some View {
        ZStack {
            if let image = entry.pokemon.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                PokeballMark(color: entry.pokemon.color)
                    .padding(6)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
    }

    private var typePills: some View {
        HStack(spacing: 4) {
            ForEach(entry.pokemon.types, id: \.self) { type in
                Text(WidgetPokemon.typeName(type).uppercased())
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.25), in: Capsule())
            }
        }
    }

    // Écran d'accueil — petit
    private var smallView: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("POKÉAPP")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Text(String(format: "#%03d", entry.pokemon.number))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                HStack(alignment: .center, spacing: 6) {
                    sprite(62)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.pokemon.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        typePills
                        if let best = entry.pokemon.bestStat {
                            Text("\(best.label) \(best.value)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 3) {
                    ForEach(Array(entry.pokemon.stats.prefix(2))) { stat in
                        StatBar(stat: stat)
                    }
                }
                Text(abilityList)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(10)
        }
    }

    // Écran d'accueil — moyen
    private var mediumView: some View {
        ZStack {
            background
            HStack(spacing: 12) {
                sprite(96)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.pokemon.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer()
                        Text(String(format: "#%03d", entry.pokemon.number))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    typePills

                    VStack(spacing: 3) {
                        ForEach(Array(entry.pokemon.stats.prefix(3))) { stat in
                            StatBar(stat: stat)
                        }
                    }

                    Text("Capacités : \(abilityList)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)

                    Text(String(
                        format: "%.1f m · %.1f kg · EXP %d",
                        Double(entry.pokemon.height) / 10,
                        Double(entry.pokemon.weight) / 10,
                        entry.pokemon.experience ?? 0
                    ))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                }
            }
            .padding(12)
        }
    }

    // Écran verrouillé — circulaire
    private var circularView: some View {
        ZStack {
            ContainerRelativeShape()
                .fill(entry.pokemon.color.opacity(0.45))
            VStack(spacing: -2) {
                sprite(34)
                Text(entry.pokemon.name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // Écran verrouillé — rectangulaire
    private var rectangularView: some View {
        HStack(spacing: 6) {
            sprite(40)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(entry.pokemon.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "#%03d", entry.pokemon.number))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(entry.pokemon.types.map(WidgetPokemon.typeName).joined(separator: " · ")) · \(entry.pokemon.stats.first?.label ?? "PV") \(entry.pokemon.stats.first?.value ?? 0)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(abilityList)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // Écran verrouillé — en ligne
    private var inlineView: some View {
        Label(
            "\(entry.pokemon.name) · #\(entry.pokemon.number) · \(entry.pokemon.bestStat?.label ?? "ATQ") \(entry.pokemon.bestStat?.value ?? 0)",
            systemImage: "star.fill"
        )
    }
}

// MARK: - Widget

struct PokemonWidget: Widget {
    let kind = "PokemonWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PokemonWidgetProvider()) { entry in
            PokemonWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PokéApp")
        .description("Photo, statistiques et capacités d'un Pokémon sur votre écran d'accueil et votre écran verrouillé.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryCircular, .accessoryRectangular, .accessoryInline
        ])
    }
}

#Preview(as: .systemSmall) {
    PokemonWidget()
} timeline: {
    PokemonWidgetEntry(date: .now, pokemon: WidgetPokemon.all[0])
}

#Preview(as: .systemMedium) {
    PokemonWidget()
} timeline: {
    PokemonWidgetEntry(date: .now, pokemon: WidgetPokemon.all[4])
}
