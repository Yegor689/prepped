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
                            TemplateRow(template: template, accessory: .edit)
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
}
