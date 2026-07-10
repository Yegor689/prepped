import SwiftUI
import SwiftData

@main struct PreppedApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Checklist.self, Item.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // SwiftData performs automatic lightweight migration for additive changes
        // (new properties that have default values), so adding a field preserves
        // existing data. This normally just succeeds.
        do {
            container = try ModelContainer(for: schema, configurations: [config])
            return
        } catch {
            // Only reached if the store is genuinely incompatible (a destructive
            // schema change migration can't handle). Rather than deleting the
            // user's data, MOVE the old store aside so it can be recovered, then
            // start fresh. This is loud (printed) and non-destructive.
            print("⚠️ SwiftData store could not be opened: \(error)")
            Self.backUpAndRemoveStore()
        }

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer even after backup: \(error)")
        }
    }

    /// Move the existing store aside (don't delete it) so a bad migration is
    /// recoverable instead of destroying data.
    private static func backUpAndRemoveStore() {
        let fm = FileManager.default
        let dir = URL.applicationSupportDirectory
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        // The store is a set of files sharing the "default.store" prefix.
        for suffix in ["", "-shm", "-wal"] {
            let src = dir.appending(path: "default.store\(suffix)")
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = dir.appending(path: "default.store.backup-\(stamp)\(suffix)")
            try? fm.moveItem(at: src, to: dst)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.indigo)
        }
        .modelContainer(container)
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    // Home shows only active (not completed) lists, soonest due first.
    @Query(
        filter: #Predicate<Checklist> { !$0.isCompleted },
        sort: \Checklist.dueDate
    ) private var activeChecklists: [Checklist]

    @State private var showingAdd = false
    @State private var pendingDelete: Checklist?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SideloadExpiryBanner()
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                Group {
                    if activeChecklists.isEmpty {
                        ContentUnavailableView {
                            Label("No Lists Yet", systemImage: "checklist")
                        } description: {
                            Text("Create your first list to get started.")
                        } actions: {
                            Button {
                                showingAdd = true
                            } label: {
                                Label("Create List", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                        }
                    } else {
                        List {
                            if !overdueChecklists.isEmpty {
                                Section("Overdue") {
                                    rows(for: overdueChecklists)
                                }
                            }
                            Section(overdueChecklists.isEmpty ? "" : "Upcoming") {
                                rows(for: upcomingChecklists)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        AllListsView()
                    } label: {
                        Label("All Lists", systemImage: "tray.full")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add List", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ChecklistFormView()
            }
            .confirmationDialog(
                "Delete this list?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { checklist in
                Button("Delete \(checklist.name)", role: .destructive) {
                    confirmDelete(checklist)
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: { checklist in
                Text("\(checklist.name) and its \(checklist.totalItemCount) item(s) will be permanently deleted.")
            }
        }
        .onAppear { NotificationManager.shared.requestAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Fetch on demand instead of continuously observing every list
                // (incl. completed) just for the foreground resync.
                let all = (try? context.fetch(FetchDescriptor<Checklist>())) ?? []
                NotificationManager.shared.rescheduleAll(all)
            }
        }
    }

    // Grouped for display: overdue lists surface at the top.
    private var overdueChecklists: [Checklist] { activeChecklists.filter(\.isOverdue) }
    private var upcomingChecklists: [Checklist] { activeChecklists.filter { !$0.isOverdue } }

    @ViewBuilder
    private func rows(for lists: [Checklist]) -> some View {
        ForEach(lists) { checklist in
            NavigationLink(destination: ChecklistDetailView(checklist: checklist)) {
                ChecklistRow(checklist: checklist)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDelete = checklist
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func confirmDelete(_ checklist: Checklist) {
        NotificationManager.shared.cancel(for: checklist)
        context.delete(checklist)
        pendingDelete = nil
    }
}

struct ChecklistRow: View {
    let checklist: Checklist

    private var tint: Color { checklist.color.color }

    var body: some View {
        HStack(spacing: 12) {
            // Red accent bar flags overdue lists at a glance.
            RoundedRectangle(cornerRadius: 2)
                .fill(checklist.isOverdue ? Color.red : Color.clear)
                .frame(width: 4)

            ProgressRing(
                progress: checklist.progress,
                tint: tint,
                size: 44,
                centerText: checklist.totalItemCount > 0
                    ? "\(checklist.completedItemCount)/\(checklist.totalItemCount)"
                    : nil,
                isComplete: checklist.allItemsDone || checklist.isCompleted
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(checklist.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if checklist.isCompleted {
                        Label(
                            checklist.dueDate.formatted(.dateTime.month().day()),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: checklist.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                            .foregroundStyle(checklist.isOverdue ? .red : tint)
                        Text(checklist.dueDescription)
                            .foregroundStyle(checklist.isOverdue ? .red : .secondary)
                    }
                    if !checklist.notes.isEmpty {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Has notes")
                    }
                }
                .font(.subheadline)
                .labelStyle(.titleAndIcon)
            }

            Spacer(minLength: 0)

            if checklist.isOverdue {
                Text("Overdue")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.15), in: Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Checklist.self, Item.self], inMemory: true)
}
