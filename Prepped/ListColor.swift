import SwiftUI

/// A small, curated palette a user can assign to a list.
/// Muted/system-adjacent tones to stay within a clean, minimal look.
enum ListColor: String, CaseIterable, Identifiable {
    case blue, teal, green, orange, pink, purple, indigo, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .teal:   return .teal
        case .green:  return .green
        case .orange: return .orange
        case .pink:   return .pink
        case .purple: return .purple
        case .indigo: return .indigo
        case .gray:   return .gray
        }
    }

    var label: String { rawValue.capitalized }
}
