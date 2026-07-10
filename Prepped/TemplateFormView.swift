import SwiftUI
import SwiftData

/// Create or edit a `ListTemplate`: a name, an accent color, and a set of item
/// titles. No due date and no completion — templates are blueprints for lists.
struct TemplateFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: ListTemplate?

    @State private var name = ""
    @State private var color: ListColor = .blue
    /// Working copy of item titles; committed to the model on save.
    @State private var itemTitles: [String] = [""]
    @FocusState private var focusedIndex: Int?

    private var isEditing: Bool { existing != nil }
    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    private var tint: Color { color.color }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Template name", text: $name)
                }

                Section("Color") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ListColor.allCases) { option in
                            Circle()
                                .fill(option.color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if option == color {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .stroke(.primary.opacity(option == color ? 0.4 : 0), lineWidth: 2)
                                }
                                .onTapGesture { color = option }
                                .accessibilityLabel(option.label)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Items") {
                    ForEach(itemTitles.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                            TextField("Item", text: $itemTitles[index])
                                .focused($focusedIndex, equals: index)
                                .submitLabel(.next)
                                .onSubmit { addRow(after: index) }
                        }
                    }
                    .onDelete { itemTitles.remove(atOffsets: $0) }

                    Button {
                        addRow(after: itemTitles.count - 1)
                    } label: {
                        Label("Add item", systemImage: "plus.circle.fill")
                            .foregroundStyle(tint)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Template" : "New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func addRow(after index: Int) {
        let insertAt = min(index + 1, itemTitles.count)
        itemTitles.insert("", at: insertAt)
        focusedIndex = insertAt
    }

    private func populate() {
        guard let existing else { return }
        name = existing.name
        color = existing.color
        let titles = existing.orderedItems.map(\.title)
        itemTitles = titles.isEmpty ? [""] : titles
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        // Drop blank rows; keep the user's order.
        let titles = itemTitles
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let template: ListTemplate
        if let existing {
            existing.name = trimmedName
            existing.colorName = color.rawValue
            // Replace items wholesale — simplest correct approach for a small set.
            for old in existing.items { context.delete(old) }
            template = existing
        } else {
            let created = ListTemplate(name: trimmedName, colorName: color.rawValue)
            context.insert(created)
            template = created
        }

        for (i, title) in titles.enumerated() {
            let item = TemplateItem(title: title, order: i, template: template)
            context.insert(item)
        }
        dismiss()
    }
}
