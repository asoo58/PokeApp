import SwiftUI

// MARK: - Couleurs des types

func watchTypeColor(_ type: String) -> Color {
    switch type {
    case "fire": return .orange
    case "water": return .blue
    case "grass": return .green
    case "electric": return .yellow
    case "poison": return .purple
    case "psychic", "fairy": return .pink
    case "ice": return .cyan
    case "dragon": return .indigo
    case "dark": return .gray
    case "fighting", "rock", "ground": return .brown
    case "ghost", "steel": return .teal
    default: return .red
    }
}

func watchStatLabel(_ raw: String) -> String {
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

func watchAbilityName(_ slug: String) -> String {
    slug.split(separator: "-")
        .map { $0.capitalized }
        .joined(separator: " ")
}

// MARK: - Carte Pokémon (réutilisée par l'accueil et le détail)

struct WatchPokemonCard: View {
    let pokemon: WatchPokemon

    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: pokemon.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure, .empty:
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                @unknown default:
                    Image(systemName: "questionmark.circle")
                }
            }
            .frame(width: 96, height: 96)

            Text(String(format: "#%03d", pokemon.id))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(pokemon.displayName)
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 5) {
                ForEach(pokemon.types, id: \.self) { type in
                    Text(type.capitalized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(watchTypeColor(type).opacity(0.25))
                        .foregroundStyle(watchTypeColor(type))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Accueil (barre de recherche tout en haut + résultats sur la même page)

struct WatchPokemonView: View {
    @State private var viewModel = WatchPokemonViewModel()

    private var isSearching: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                // ── Barre de recherche, au-dessus de tout ──
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Pokémon ou n°…", text: searchBinding)
                        .autocorrectionDisabled()
                    if isSearching {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                // ── Filtre par type, conservé sous la barre ──
                HStack(spacing: 4) {
                    NavigationLink {
                        WatchTypeFilterView(viewModel: viewModel)
                    } label: {
                        Label(
                            viewModel.selectedType.map { "Type : \($0.capitalized)" } ?? "Tous les types",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                    .buttonStyle(.plain)

                    if viewModel.selectedType != nil {
                        Button {
                            viewModel.selectedType = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    if viewModel.isLoadingType || viewModel.isLoadingTypes {
                        ProgressView()
                    }
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                // ── Résultats en direct ou accueil normal ──
                if isSearching {
                    searchResults
                } else {
                    homeContent
                }
            }
            .navigationTitle("PokéApp")
            .task {
                await viewModel.loadRandom()
                await viewModel.loadAllPokemon()
                await viewModel.loadTypesIfNeeded()
                Task { await viewModel.loadAllTypesIfNeeded() }
            }
            .onChange(of: viewModel.searchText) { _, _ in
                Task { await viewModel.loadTypesIfNeeded() }
            }
            .onChange(of: viewModel.selectedType) { _, _ in
                Task { await viewModel.loadTypesIfNeeded() }
            }
        }
    }

    private var homeContent: some View {
        ScrollView {
            VStack(spacing: 10) {
                NavigationLink {
                    WatchPokemonDetailView(viewModel: viewModel, pokemonName: viewModel.current.name)
                } label: {
                    WatchPokemonCard(pokemon: viewModel.current)
                }
                .buttonStyle(.plain)

                Text("Voir les stats et capacités")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await viewModel.loadRandom() }
                } label: {
                    Label("Aléatoire", systemImage: "shuffle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)

                Button {
                    viewModel.toggleFavorite(viewModel.current)
                } label: {
                    Label(
                        viewModel.isFavorite(viewModel.current) ? "Retiré des favoris" : "Ajouter aux favoris",
                        systemImage: viewModel.isFavorite(viewModel.current) ? "star.fill" : "star"
                    )
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    WatchFavoritesView(viewModel: viewModel)
                } label: {
                    Label("Favoris (\(viewModel.favorites.count))", systemImage: "star.fill")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.isLoadingList && viewModel.allPokemon.isEmpty {
            ProgressView("Chargement…")
        } else if viewModel.allPokemon.isEmpty {
            VStack(spacing: 8) {
                Text(viewModel.listErrorMessage ?? "Aucune donnée disponible.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Réessayer") {
                    Task { await viewModel.loadAllPokemon() }
                }
                .buttonStyle(.bordered)
            }
        } else if viewModel.isLoadingType {
            ProgressView("Filtrage…")
        } else if viewModel.filteredPokemon.isEmpty {
            Text("Aucun Pokémon trouvé")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            List(viewModel.filteredPokemon) { pokemon in
                NavigationLink {
                    WatchPokemonDetailView(viewModel: viewModel, pokemonName: pokemon.name)
                } label: {
                    HStack(spacing: 8) {
                        if let type = viewModel.typeName(for: pokemon.name) {
                            Circle()
                                .fill(watchTypeColor(type))
                                .frame(width: 12, height: 12)
                            Text(pokemon.displayName)
                                .font(.body)
                                .foregroundStyle(watchTypeColor(type))
                        } else {
                            Circle()
                                .fill(.secondary.opacity(0.5))
                                .frame(width: 12, height: 12)
                            Text(pokemon.displayName)
                                .font(.body)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.searchText },
            set: { viewModel.searchText = $0 }
        )
    }
}

// MARK: - Filtre par type

struct WatchTypeFilterView: View {
    let viewModel: WatchPokemonViewModel

    var body: some View {
        List {
            Button {
                viewModel.selectedType = nil
            } label: {
                HStack {
                    Label("Tous les types", systemImage: "square.grid.2x2")
                    if viewModel.selectedType == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(viewModel.allTypes, id: \.self) { type in
                Button {
                    viewModel.selectedType = type
                } label: {
                    HStack {
                        Circle()
                            .fill(watchTypeColor(type))
                            .frame(width: 10, height: 10)
                        Text(type.capitalized)
                        if viewModel.selectedType == type {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }
        .navigationTitle("Type")
    }
}

// MARK: - Éléments de la fiche détail

private struct WatchStatBar: View {
    let stat: WatchStat
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(watchStatLabel(stat.name))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(stat.value)")
                    .font(.caption2.weight(.bold))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.secondary.opacity(0.25))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(CGFloat(stat.value) / 255.0, 1))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct WatchInfoSection<Content: View>: View {
    let title: String
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

private func watchInfoRow(label: String, value: String) -> some View {
    HStack {
        Text(label)
            .font(.caption2)
            .foregroundStyle(.secondary)
        Spacer()
        Text(value)
            .font(.caption2.weight(.bold))
    }
}

// MARK: - Détail d'un Pokémon trouvé

struct WatchPokemonDetailView: View {
    let viewModel: WatchPokemonViewModel
    let pokemonName: String

    @State private var detail: WatchPokemon?
    @State private var loadFailed = false

    var body: some View {
        Group {
            if let detail {
                let primaryColor = watchTypeColor(detail.types.first ?? "normal")

                ScrollView {
                    VStack(spacing: 10) {
                        WatchPokemonCard(pokemon: detail)

                        Button {
                            viewModel.toggleFavorite(detail)
                        } label: {
                            Label(
                                viewModel.isFavorite(detail) ? "Retiré des favoris" : "Ajouter aux favoris",
                                systemImage: viewModel.isFavorite(detail) ? "star.fill" : "star"
                            )
                        }
                        .buttonStyle(.bordered)

                        // ── Infos ──
                        WatchInfoSection(title: "Infos", color: primaryColor) {
                            watchInfoRow(
                                label: "Taille",
                                value: detail.height.map { "\($0 * 10) cm" } ?? "—"
                            )
                            watchInfoRow(
                                label: "Poids",
                                value: detail.weight.map { String(format: "%.1f kg", Double($0) / 10) } ?? "—"
                            )
                            watchInfoRow(
                                label: "Expérience",
                                value: detail.experience.map(String.init) ?? "—"
                            )
                        }

                        // ── Stats ──
                        if !detail.stats.isEmpty {
                            WatchInfoSection(title: "Stats", color: primaryColor) {
                                VStack(spacing: 6) {
                                    ForEach(detail.stats) { stat in
                                        WatchStatBar(stat: stat, color: primaryColor)
                                    }
                                }
                            }
                        }

                        // ── Capacités ──
                        if !detail.abilities.isEmpty {
                            WatchInfoSection(title: "Capacités", color: primaryColor) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(detail.abilities) { ability in
                                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                                            Text("•")
                                            Text(watchAbilityName(ability.name))
                                                .font(.caption2)
                                            if ability.isHidden {
                                                Text("(cachée)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if loadFailed {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Chargement impossible")
                        .foregroundStyle(.secondary)
                    Button("Réessayer") {
                        Task { await load() }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle(detail?.displayName ?? pokemonName.capitalized)
        .task { await load() }
    }

    private func load() async {
        loadFailed = false
        do {
            detail = try await viewModel.pokemon(named: pokemonName)
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Favoris

struct WatchFavoritesView: View {
    let viewModel: WatchPokemonViewModel

    var body: some View {
        Group {
            if viewModel.favorites.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "star")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("Aucun favori")
                        .foregroundStyle(.secondary)
                }
            } else {
                List(viewModel.favorites, id: \.self) { name in
                    NavigationLink {
                        WatchPokemonDetailView(viewModel: viewModel, pokemonName: name)
                    } label: {
                        Label(name.capitalized, systemImage: "star.fill")
                    }
                }
            }
        }
        .navigationTitle("Favoris")
    }
}

#Preview {
    WatchPokemonView()
}
