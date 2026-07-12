import SwiftUI

/// A single template's row: color-tinted icon, name, and item summary, with a
/// configurable trailing accessory. Shared by the templates management list
/// (chevron → edit) and the template picker (plus → new list from it).
struct TemplateRow: View {
    let template: ListTemplate
    /// Trailing accessory: `.edit` shows a chevron, `.pick` a plus.
    var accessory: Accessory = .edit

    enum Accessory { case edit, pick }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.on.square")
                .foregroundStyle(template.color.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(template.itemSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            switch accessory {
            case .edit:
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            case .pick:
                Image(systemName: "plus.circle")
                    .foregroundStyle(template.color.color)
                    .accessibilityLabel("New list from this template")
            }
        }
        .padding(.vertical, 4)
    }
}
