import SwiftUI

/// The 8-swatch accent-color picker, shared by the checklist and template
/// forms. Tapping a swatch selects it; the selection gets a checkmark and ring.
struct ColorPickerGrid: View {
    @Binding var selection: ListColor

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(ListColor.allCases) { option in
                Circle()
                    .fill(option.color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        if option == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay {
                        Circle()
                            .stroke(.primary.opacity(option == selection ? 0.4 : 0), lineWidth: 2)
                    }
                    .onTapGesture { selection = option }
                    .accessibilityLabel(option.label)
            }
        }
        .padding(.vertical, 4)
    }
}
