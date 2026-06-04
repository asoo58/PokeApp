import SwiftUI

struct PokemonRowView: View {
    let name: String
    var onTypesLoaded: (([String]) -> Void)? = nil
    @State private var viewModel = PokemonRowViewModel()

    var body: some View {
        HStack {
            Text(name.capitalized)
                .font(.body)
            Spacer()
            HStack(spacing: 6) {
                ForEach(viewModel.types, id: \.self) { type in
                    Text(type.capitalized)
                        .font(.caption).bold()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(colorForType(type))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .task {
            await viewModel.loadTypes(name: name)
            onTypesLoaded?(viewModel.types)
        }
    }
}

#Preview {
    PokemonRowView(name: "charizard")
}
