import SwiftUI
import SwiftData

struct ChecklistDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var checklist: Checklist

    @State private var newItemTitle = ""
    @State private var showingEdit = false
    @State private var showingCompletePrompt = false
    @State private var showingIncompleteWarning = false
    @State private var editMode: EditMode = .inactive
    @FocusState private var addFieldFocused: Bool
    @State private var celebrate = false
    /// Live UITextField per item, so backspace-delete and Return-to-insert can
    /// hand focus to a specific row directly (keeps the keyboard up across a
    /// SwiftData mutation, which SwiftUI's per-row @FocusState can't do for a
    /// dynamic ForEach).
    @State private var itemFields: [UUID: UITextField] = [:]
    /// An item whose field should become first responder the moment it's
    /// created (used right after inserting a new row via Return).
    @State private var pendingFocusItemID: UUID?

    private var tint: Color { checklist.color.color }

    var body: some View {
        List {
            Section {
                headerCard
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                // Unchecked items float to the top; reorderable among themselves.
                ForEach(activeItems) { item in
                    itemRow(item)
                }
                .onMove { moveItems(in: activeItems, from: $0, to: $1) }
                .onDelete { deleteItems(in: activeItems, at: $0) }

                // Completed items sink below; also reorderable among themselves.
                ForEach(doneItems) { item in
                    itemRow(item)
                }
                .onMove { moveItems(in: doneItems, from: $0, to: $1) }
                .onDelete { deleteItems(in: doneItems, at: $0) }

                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(tint)
                    TextField("Add item", text: $newItemTitle)
                        .focused($addFieldFocused)
                        .submitLabel(.next)
                        .onSubmit { addItem() }
                        .onChange(of: addFieldFocused) { _, focused in
                            // Commit typed text when the field loses focus (e.g. tapping away).
                            if !focused { addItem(keepFocus: false) }
                        }
                }
            } header: {
                Text("Items")
            } footer: {
                if checklist.items.isEmpty {
                    Text("No items yet — add your first one above.")
                }
            }

        }
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(tint)
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { addItem(keepFocus: false) }
        .overlay {
            if celebrate {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: celebrate)
                    Text("All done!")
                        .font(.title3.weight(.bold))
                }
                .padding(28)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .shadow(radius: 20)
                .transition(.scale.combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !checklist.isCompleted {
                        Button {
                            // Warn if there's still open work; complete directly when all done.
                            if checklist.allItemsDone || checklist.items.isEmpty {
                                markComplete()
                            } else {
                                showingIncompleteWarning = true
                            }
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.seal.fill")
                        }
                    } else {
                        Button {
                            checklist.isCompleted = false
                            NotificationManager.shared.reschedule(for: checklist)
                        } label: {
                            Label("Reopen List", systemImage: "arrow.uturn.backward")
                        }
                    }

                    Divider()

                    Button {
                        showingEdit = true
                    } label: {
                        Label("Edit List Details", systemImage: "pencil")
                    }
                    Button {
                        withAnimation {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    } label: {
                        Label(
                            editMode.isEditing ? "Done Reordering" : "Reorder Items",
                            systemImage: "arrow.up.arrow.down"
                        )
                    }
                    .disabled(checklist.items.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            // Explicit keyboard dismissal — reliable, and no tap gesture on the
            // list competing with fields (which caused multi-tap-to-focus).
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    addFieldFocused = false
                    for field in itemFields.values { field.resignFirstResponder() }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ChecklistFormView(existing: checklist)
        }
        .alert("All items are done!", isPresented: $showingCompletePrompt) {
            Button("Mark Complete") { markComplete() }
            Button("Not Yet", role: .cancel) {}
        } message: {
            Text("Mark this list complete? It will move to All Lists.")
        }
        .alert("Some items aren’t done", isPresented: $showingIncompleteWarning) {
            Button("Complete Anyway", role: .destructive) { markComplete() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("\(checklist.totalItemCount - checklist.completedItemCount) of \(checklist.totalItemCount) items are still open. Complete this list anyway?")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 16) {
            ProgressRing(
                progress: checklist.progress,
                tint: tint,
                size: 64,
                lineWidth: 7,
                centerText: checklist.totalItemCount > 0
                    ? "\(Int(checklist.progress * 100))%"
                    : nil,
                isComplete: checklist.allItemsDone || checklist.isCompleted
            )

            VStack(alignment: .leading, spacing: 6) {
                Label {
                    if checklist.isCompleted {
                        Text("Completed")
                    } else {
                        Text(checklist.dueDescription)
                    }
                } icon: {
                    Image(systemName: checklist.isCompleted ? "checkmark.circle.fill"
                          : (checklist.isOverdue ? "exclamationmark.circle.fill" : "calendar"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(checklist.isOverdue && !checklist.isCompleted ? .red : tint)

                Text(checklist.hasTime
                     ? checklist.dueDate.formatted(.dateTime.weekday(.wide).month().day().hour().minute())
                     : checklist.dueDate.formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if checklist.totalItemCount > 0 {
                    let remaining = checklist.totalItemCount - checklist.completedItemCount
                    if checklist.allItemsDone {
                        Text("All done 🎉")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(checklist.completedItemCount) of \(checklist.totalItemCount) done · \(remaining) left")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !checklist.isCompleted {
                    HStack(spacing: 6) {
                        Image(systemName: checklist.reminderLead == .none ? "bell.slash" : "bell")
                            .frame(width: 16)
                        Text(checklist.reminderLead == .none
                             ? "No reminder"
                             : "Reminder \(checklist.reminderLead.shortLabel)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }

        // Note is part of the card, connected via a hairline divider, italic, no icon.
        if !checklist.notes.isEmpty {
            Divider()
                .overlay(tint.opacity(0.25))
            Text(checklist.notes)
                .font(.footnote)
                .italic()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        }
        .padding(18)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// Items split into unchecked/checked, each in manual order, from a single
    /// sort + partition pass (instead of two independent filter+sort passes
    /// re-run on every render / keystroke).
    private var splitItems: (active: [Item], done: [Item]) {
        var active: [Item] = []
        var done: [Item] = []
        for item in checklist.items.sorted(by: { $0.order < $1.order }) {
            if item.isDone { done.append(item) } else { active.append(item) }
        }
        return (active, done)
    }

    // Unchecked items, in manual order.
    private var activeItems: [Item] { splitItems.active }
    // Checked items, in manual order.
    private var doneItems: [Item] { splitItems.done }

    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
        HStack(spacing: 12) {
            // Circle toggles done/undone.
            Button {
                toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Tap the text to edit it inline; edits autosave. Backspacing on an
            // already-empty item deletes the row.
            BackspaceTextField(
                placeholder: "Item",
                text: Binding(get: { item.title }, set: { item.title = $0 }),
                strikethrough: item.isDone,
                isDimmed: item.isDone,
                onDeleteBackwardWhenEmpty: { deleteItem(item) },
                onReturn: { insertItem(after: item) },
                onFieldAvailable: { field in
                    itemFields[item.id] = field
                    if let field, pendingFocusItemID == item.id {
                        pendingFocusItemID = nil
                        field.becomeFirstResponder()
                    }
                }
            )
        }
    }

    /// Insert a new blank item directly after `item` (within the active
    /// group), so pressing Return mid-list adds an entry there instead of only
    /// at the bottom. Renumbers `order` for everything after the insertion
    /// point, then marks the new item to receive focus once its field exists.
    /// Returns `true` to tell the caller a new row now owns focus.
    private func insertItem(after item: Item) -> Bool {
        var group = activeItems
        guard let index = group.firstIndex(where: { $0.id == item.id }) else { return false }

        let newItem = Item(title: "", order: 0, checklist: checklist)
        context.insert(newItem)
        group.insert(newItem, at: index + 1)
        for (i, entry) in group.enumerated() { entry.order = i }

        pendingFocusItemID = newItem.id
        NotificationManager.shared.reschedule(for: checklist)
        return true
    }

    /// Remove a single item (used by backspace-on-empty). Hands focus to the
    /// previous item's field *before* deleting, deferring the actual SwiftData
    /// removal to the next runloop turn — deleting immediately tears down the
    /// row (and its UITextField) on the same turn UIKit is still processing
    /// the focus change, which drops the keyboard instead of moving it.
    private func deleteItem(_ item: Item) {
        let group = item.isDone ? doneItems : activeItems
        let index = group.firstIndex(where: { $0.id == item.id })
        let previous = index.flatMap { $0 > 0 ? group[$0 - 1] : nil }

        if let previous, let field = itemFields[previous.id] {
            field.becomeFirstResponder()
            let end = field.endOfDocument
            field.selectedTextRange = field.textRange(from: end, to: end)
        } else {
            // No item above — fall back to the add-item field so the
            // keyboard still stays up.
            addFieldFocused = true
        }

        itemFields[item.id] = nil
        DispatchQueue.main.async {
            context.delete(item)
            NotificationManager.shared.reschedule(for: checklist)
        }
    }

    private func toggle(_ item: Item) {
        let wasAllDone = checklist.allItemsDone
        item.isDone.toggle()
        NotificationManager.shared.reschedule(for: checklist)
        if checklist.allItemsDone && !wasAllDone {
            // Just crossed into 100% — celebrate, then offer to complete.
            triggerCelebration()
            if !checklist.isCompleted {
                showingCompletePrompt = true
            }
        }
    }

    private func triggerCelebration() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
            celebrate = true
        }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) { celebrate = false }
        }
    }

    private func addItem(keepFocus: Bool = true) {
        let trimmed = newItemTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (checklist.items.map(\.order).max() ?? -1) + 1
        let item = Item(title: trimmed, order: nextOrder, checklist: checklist)
        context.insert(item)
        newItemTitle = ""
        NotificationManager.shared.reschedule(for: checklist)
        // Keep the field focused so several items can be added in a row.
        if keepFocus { addFieldFocused = true }
    }

    /// Reorder within one group, then renumber that group's `order` fields.
    private func moveItems(in group: [Item], from offsets: IndexSet, to destination: Int) {
        var reordered = group
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.order = index
        }
    }

    private func deleteItems(in group: [Item], at offsets: IndexSet) {
        for index in offsets {
            context.delete(group[index])
        }
        NotificationManager.shared.reschedule(for: checklist)
    }

    private func markComplete() {
        checklist.isCompleted = true
        NotificationManager.shared.cancel(for: checklist)
        dismiss()
    }
}
