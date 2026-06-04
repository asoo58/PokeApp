import SwiftUI

struct ContentView: View {
    @State private var viewModel = PokemonListViewModel()
    @State private var searchText: String = ""
    @State private var selectedType: String? = nil
    @State private var showFilterSheet = false

    let allTypes = ["normal", "fire", "water", "grass", "electric", "psychic",
                    "ice", "dragon", "dark", "fighting", "poison", "ground",
                    "rock", "ghost", "steel", "fairy", "flying", "bug"]

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 0) {

                    // ── Barre recherche + filtre ──
                    HStack {
                        TextField("Nom du Pokémon", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: searchText) { _, newValue in
                                viewModel.filterPokemon(query: newValue, selectedType: selectedType)
                            }

                        Button {
                            showFilterSheet = true
                        } label: {
                            Image(systemName: selectedType != nil
                                  ? "line.3.horizontal.decrease.circle.fill"
                                  : "line.3.horizontal.decrease.circle")
                                .font(.title2)
                                .foregroundColor(selectedType != nil ? colorForType(selectedType!) : .gray)
                        }
                        // Désactiver le bouton filtre tant que les types ne sont pas chargés
                        .disabled(viewModel.isLoadingTypes)
                    }
                    .padding()

                    // ── Barre de progression du chargement des types ──
                    if viewModel.isLoadingTypes {
                        VStack(spacing: 4) {
                            ProgressView(value: viewModel.typeLoadingProgress)
                                .progressViewStyle(.linear)
                                .padding(.horizontal)
                            Text("Chargement des types… \(Int(viewModel.typeLoadingProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 6)
                    }

                    // ── Chip type actif ──
                    if let type = selectedType {
                        HStack {
                            HStack(spacing: 4) {
                                Text(type.capitalized)
                                    .font(.caption).bold()
                                Button {
                                    selectedType = nil
                                    viewModel.filterPokemon(query: searchText, selectedType: nil)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colorForType(type).opacity(0.2))
                            .foregroundColor(colorForType(type))
                            .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }

                    Divider()

                    if viewModel.isLoadingList {
                        Spacer()
                        ProgressView("Chargement de la liste…")
                        Spacer()
                    } else if viewModel.filteredNames.isEmpty {
                        Spacer()
                        Text("Aucun Pokémon trouvé")
                            .foregroundStyle(.secondary)
                        Spacer()
                    } else {
                        List(viewModel.filteredNames, id: \.self) { name in
                            NavigationLink(destination: PokemonView(name: name)) {
                                PokemonRowView(name: name, onTypesLoaded: { types in
                                    viewModel.cacheTypes(for: name, types: types)
                                })
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("PokéApp")
                .task {
                    await viewModel.loadAllPokemonNames()
                }
                .sheet(isPresented: $showFilterSheet) {
                    filterSheet
                }
            }
            .tabItem {
                Label("Recherche", systemImage: "magnifyingglass")
            }

            FavoriteView()
                .tabItem {
                    Label("Favoris", systemImage: "star.fill")
                }
        }
    }

    var filterSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Filtrer par type")
                    .font(.headline)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                    ForEach(allTypes, id: \.self) { type in
                        Button {
                            selectedType = selectedType == type ? nil : type
                            viewModel.filterPokemon(query: searchText, selectedType: selectedType)
                            showFilterSheet = false
                        } label: {
                            Text(type.capitalized)
                                .font(.caption).bold()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedType == type
                                            ? colorForType(type)
                                            : colorForType(type).opacity(0.25))
                                .foregroundColor(selectedType == type ? .white : colorForType(type))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button {
                    selectedType = nil
                    viewModel.filterPokemon(query: searchText, selectedType: nil)
                    showFilterSheet = false
                } label: {
                    Text("Réinitialiser")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
        .environment(PokemonFavoriteViewModel())
}
