import SwiftUI
import SwiftData

/// A searchable, full-screen list of every template, for picking one to seed a
/// new list. Used when there are more templates than fit in the + menu.
/// Selecting a template dismisses and hands it back via `onSelect`.
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ListTemplate.name) private var templates: [ListTemplate]

    /// Called with the chosen template after the picker dismisses.
    let onSelect: (ListTemplate) -> Void

    @State private var searchText = ""

    private var filtered: [ListTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return templates }
        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(query)
                || template.items.contains { $0.title.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filtered) { template in
                        Button {
                            let chosen = template
                            dismiss()
                            onSelect(chosen)
                        } label: {
                            row(template)
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Choose a Template")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ template: ListTemplate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "square.on.square")
                .foregroundStyle(template.color.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(itemSummary(template))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "plus.circle")
                .foregroundStyle(template.color.color)
                .accessibilityLabel("New list from this template")
        }
        .padding(.vertical, 4)
    }

    private func itemSummary(_ template: ListTemplate) -> String {
        let count = template.items.count
        guard count > 0 else { return "No items" }
        let preview = template.orderedItems.prefix(3).map(\.title).joined(separator: ", ")
        let suffix = count > 3 ? "…" : ""
        return "\(count) item\(count == 1 ? "" : "s") · \(preview)\(suffix)"
    }
}
