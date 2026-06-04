//
// la fonction colorForType + la liste des types
//

import SwiftUI

func colorForType(_ type: String) -> Color {
    switch type {
    case "fire":     return .orange
    case "water":    return .blue
    case "grass":    return .green
    case "electric": return .yellow
    case "psychic":  return .pink
    case "ice":      return .cyan
    case "dragon":   return .indigo
    case "dark":     return Color(red: 0.2, green: 0.2, blue: 0.2)
    case "fighting": return .red
    case "poison":   return .purple
    case "ground":   return Color(red: 0.8, green: 0.6, blue: 0.3)
    case "rock":     return Color(red: 0.6, green: 0.5, blue: 0.3)
    case "ghost":    return Color(red: 0.4, green: 0.3, blue: 0.6)
    case "steel":    return Color(red: 0.6, green: 0.6, blue: 0.7)
    case "fairy":    return Color(red: 1.0, green: 0.6, blue: 0.8)
    case "flying":   return Color(red: 0.7, green: 0.8, blue: 0.9)
    case "bug":      return Color(red: 130/255, green: 143/255, blue: 37/255)
    case "normal":   return Color(red: 0.7, green: 0.7, blue: 0.6)
    default:         return .gray
    }
}
