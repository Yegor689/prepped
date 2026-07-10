import SwiftUI
import SwiftData

/// Add or edit a checklist. Pass `existing` to edit; omit to create.
struct ChecklistFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var existing: Checklist?

    @State private var name = ""
    @State private var notes = ""
    @State private var dueDate = Date().addingTimeInterval(60 * 60 * 24 * 7)
    @State private var hasTime = false
    @State private var color: ListColor = .blue
    @State private var reminderLead: ReminderLead = .oneDay

    private var isEditing: Bool { existing != nil }

    /// Reminder footer reflects when it actually fires: the due time if set,
    /// otherwise the default 9 AM.
    private var reminderFooter: String {
        if hasTime {
            let time = dueDate.formatted(.dateTime.hour().minute())
            return "Delivered at \(time), only if items remain unfinished."
        }
        return "Delivered at 9:00 AM, only if items remain unfinished."
    }

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 12)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    DatePicker("Due date", selection: $dueDate, displayedComponents: [.date])
                    Toggle("Set a time", isOn: $hasTime.animation())
                    if hasTime {
                        DatePicker("Due time", selection: $dueDate, displayedComponents: [.hourAndMinute])
                    }
                    Picker("Reminder", selection: $reminderLead) {
                        ForEach(ReminderLead.allCases) { lead in
                            Text(lead.label).tag(lead)
                        }
                    }
                } footer: {
                    if reminderLead != .none {
                        Text(reminderFooter)
                    }
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
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
            }
            .navigationTitle(isEditing ? "Edit List" : "New List")
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

    private func populate() {
        guard let existing else { return }
        name = existing.name
        notes = existing.notes
        dueDate = existing.dueDate
        hasTime = existing.hasTime
        color = existing.color
        reminderLead = existing.reminderLead
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // When there's no specific time, pin to the start of the day so a stale
        // time component can't affect overdue/reminder logic.
        let resolvedDue = hasTime ? dueDate : Calendar.current.startOfDay(for: dueDate)
        let target: Checklist
        if let existing {
            existing.name = trimmed
            existing.notes = notes
            existing.dueDate = resolvedDue
            existing.hasTime = hasTime
            existing.colorName = color.rawValue
            existing.reminderLeadDays = reminderLead.rawValue
            target = existing
        } else {
            let checklist = Checklist(name: trimmed, notes: notes, dueDate: resolvedDue,
                                      hasTime: hasTime,
                                      colorName: color.rawValue,
                                      reminderLeadDays: reminderLead.rawValue)
            context.insert(checklist)
            target = checklist
        }
        NotificationManager.shared.reschedule(for: target)
        dismiss()
    }
}
