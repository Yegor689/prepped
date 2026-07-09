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

            if !checklist.isCompleted {
                Section {
                    HStack {
                        Spacer()
                        Button {
                            // Warn if there's still open work; complete directly when all done.
                            if checklist.allItemsDone || checklist.items.isEmpty {
                                markComplete()
                            } else {
                                showingIncompleteWarning = true
                            }
                        } label: {
                            Label("Mark Complete", systemImage: "checkmark.seal.fill")
                                .font(.subheadline.weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(tint)
                        // Not tappable while typing a new item, so a tap meant to
                        // dismiss the keyboard can't accidentally complete the list.
                        .disabled(addFieldFocused)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    Button {
                        checklist.isCompleted = false
                        NotificationManager.shared.reschedule(for: checklist)
                    } label: {
                        Label("Reopen List", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle(checklist.name)
        .navigationBarTitleDisplayMode(.large)
        .tint(tint)
        .environment(\.editMode, $editMode)
        .scrollDismissesKeyboard(.interactively)
        // Tap anywhere in the list (empty space, rows) to dismiss the keyboard.
        // simultaneousGesture lets row taps/buttons still work.
        .simultaneousGesture(
            TapGesture().onEnded {
                if addFieldFocused { addFieldFocused = false }
            }
        )
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

                Text(checklist.dueDate.formatted(.dateTime.weekday(.wide).month().day()))
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

    // Unchecked items, in manual order.
    private var activeItems: [Item] {
        checklist.items.filter { !$0.isDone }.sorted { $0.order < $1.order }
    }
    // Checked items, in manual order.
    private var doneItems: [Item] {
        checklist.items.filter { $0.isDone }.sorted { $0.order < $1.order }
    }

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

            // Tap the text to edit it inline; edits autosave.
            TextField("Item", text: Binding(
                get: { item.title },
                set: { item.title = $0 }
            ))
            .strikethrough(item.isDone)
            .foregroundStyle(item.isDone ? .secondary : .primary)
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
