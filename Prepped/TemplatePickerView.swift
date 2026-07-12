import SwiftUI
import SwiftData

/// A searchable, full-screen list of every template, for picking one to seed a
/// new list. Used when there are more templates than fit in the + menu. Sets
/// `selection` and dismisses; the presenter opens the prefilled form in the
/// sheet's `onDismiss` (race-free — the picker is fully gone by then).
struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ListTemplate.name) private var templates: [ListTemplate]

    /// Set to the chosen template just before dismissing.
    @Binding var selection: ListTemplate?

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
                            selection = template
                            dismiss()
                        } label: {
                            TemplateRow(template: template, accessory: .pick)
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
}
