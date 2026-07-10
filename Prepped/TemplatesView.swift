import SwiftUI
import SwiftData

/// Manage list templates: create, edit, and delete. New lists are started
/// *from* a template via the home screen's + menu. Reached from the home
/// screen's top-left Library menu.
struct TemplatesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ListTemplate.createdAt) private var templates: [ListTemplate]

    @State private var editingTemplate: ListTemplate?
    @State private var creatingTemplate = false

    var body: some View {
        Group {
            if templates.isEmpty {
                ContentUnavailableView {
                    Label("No Templates", systemImage: "square.on.square")
                } description: {
                    Text("Save a set of items you use often, then start a list from it in one tap.")
                } actions: {
                    Button {
                        creatingTemplate = true
                    } label: {
                        Label("New Template", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                }
            } else {
                List {
                    ForEach(templates) { template in
                        Button {
                            editingTemplate = template
                        } label: {
                            templateRow(template)
                        }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                context.delete(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creatingTemplate = true
                } label: {
                    Label("New Template", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $creatingTemplate) {
            TemplateFormView()
        }
        .sheet(item: $editingTemplate) { template in
            TemplateFormView(existing: template)
        }
    }

    @ViewBuilder
    private func templateRow(_ template: ListTemplate) -> some View {
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

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
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
