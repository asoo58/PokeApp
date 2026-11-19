import SwiftUI
import PokemonAPI

struct PokemonView: View {
    let name: String
    @State private var viewModel = PokemonDetailViewModel()
    @Environment(PokemonFavoriteViewModel.self) private var favoriteViewModel

    var body: some View {
        @Bindable var favoriteViewModel = favoriteViewModel

        Group {
            if viewModel.isLoading {
                ProgressView("Chargement…")
            } else if let pokemon = viewModel.pokemon {
                ScrollView {
                    VStack(spacing: 0) {

                        // ── Bandeau bicolore ──
                        ZStack {
                            HStack(spacing: 0) {
                                colorForType(viewModel.types.indices.contains(0) ? viewModel.types[0] : "normal")
                                colorForType(viewModel.types.indices.contains(1) ? viewModel.types[1] : (viewModel.types.indices.contains(0) ? viewModel.types[0] : "normal"))
                            }

                            VStack(spacing: 8) {
                                if let urlStr = pokemon.sprites?.frontDefault,
                                   let url = URL(string: urlStr) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().scaledToFit()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 150, height: 150)
                                    .offset(y: 50)
                                }

                                Text(pokemon.name?.capitalized ?? "")
                                    .font(.largeTitle).bold()
                                    .foregroundColor(.white)

                                if let id = pokemon.id {
                                    Text("#\(id)")
                                        .font(.title3)
                                        .foregroundColor(.white.opacity(0.8))
                                }

                                HStack(spacing: 10) {
                                    ForEach(viewModel.types, id: \.self) { type in
                                        Text(type.capitalized)
                                            .font(.subheadline).bold()
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(.white.opacity(0.25))
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 30)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        
                        //── Favoris ──
                        .overlay(alignment: .topTrailing) {
                            Button {
                                favoriteViewModel.toggle(pokemon)
                            } label: {
                                // L'icône reflète toujours le modèle : plus de
                                // désynchronisation lors de tapes rapides.
                                Image(systemName: favoriteViewModel.isFavorite(pokemon) ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(.top, 190)
                                    .padding(.trailing, 20)
                            }
                        }

                        // ── Navigation précédent / suivant ──
                        let primaryColor = colorForType(viewModel.types.first ?? "normal")

                        HStack {
                            Button {
                                if let id = viewModel.pokemon?.id, id > 1 {
                                    Task { await viewModel.loadPokemon(name: "\(id - 1)") }
                                }
                            } label: {
                                Label("Précédent", systemImage: "chevron.left")
                                    .font(.subheadline).bold()
                                    .foregroundColor(primaryColor)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(primaryColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .disabled((viewModel.pokemon?.id ?? 1) <= 1)

                            Spacer()

                            Button {
                                if let id = viewModel.pokemon?.id {
                                    Task { await viewModel.loadPokemon(name: "\(id + 1)") }
                                }
                            } label: {
                                Label("Suivant", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                                    .font(.subheadline).bold()
                                    .foregroundColor(primaryColor)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(primaryColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)

                        // ── Infos ──
                        VStack(alignment: .leading, spacing: 20) {

                            infoSection(title: "Infos") {
                                infoRow(label: "Taille", value: pokemon.height.map { "\($0 * 10) cm" } ?? "—")
                                infoRow(label: "Poids", value: pokemon.weight.map { "\($0 / 10) kg" } ?? "—")
                                infoRow(label: "Expérience de base", value: pokemon.baseExperience.map { "\($0)" } ?? "—")
                            }

                            if let stats = pokemon.stats, !stats.isEmpty {
                                infoSection(title: "Stats") {
                                    ForEach(stats, id: \.stat?.name) { stat in
                                        if let statName = stat.stat?.name, let baseStat = stat.baseStat {
                                            statRow(name: statName, value: baseStat)
                                        }
                                    }
                                }
                            }

                            if let abilities = pokemon.abilities, !abilities.isEmpty {
                                infoSection(title: "Capacités") {
                                    ForEach(abilities, id: \.ability?.name) { ability in
                                        if let abilityName = ability.ability?.name {
                                            HStack {
                                                Text("•")
                                                Text(abilityName.capitalized)
                                                if ability.isHidden == true {
                                                    Text("(cachée)")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .task {
            await viewModel.loadPokemon(name: name)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    // ── Helpers UI ──

    @ViewBuilder
    func infoSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(colorForType(viewModel.types.first ?? "normal"))
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).bold()
        }
    }
    
    func statRow(name: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name.capitalized).foregroundStyle(.secondary)
                Spacer()
                Text("\(value)").bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForType(viewModel.types.first ?? "normal"))
                        .frame(width: geo.size.width * min(CGFloat(value) / 255.0, 1.0))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    NavigationStack {
        PokemonView(name: "charizard")
    }
    .environment(PokemonFavoriteViewModel())
}
