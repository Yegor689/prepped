import SwiftUI
import SwiftData

@main struct PreppedApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Checklist.self, Item.self, ListTemplate.self, TemplateItem.self])
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
                // App-wide accent for chrome (nav, buttons). Per-list color still
                // drives list-specific surfaces (progress ring, accent bar, and
                // the detail screen, which re-tints itself).
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
    // Newest first, so the + menu can surface the most recent templates.
    @Query(sort: \ListTemplate.createdAt, order: .reverse) private var templates: [ListTemplate]

    @State private var showingAdd = false
    @State private var pendingDelete: Checklist?
    /// Template chosen from the + menu to seed a new list.
    @State private var templateForNewList: ListTemplate?
    /// Whether the searchable "all templates" picker is showing.
    @State private var showingTemplatePicker = false
    /// Template chosen inside the picker; consumed in the picker's onDismiss to
    /// open the prefilled form after the picker is fully gone (race-free).
    @State private var pickerSelection: ListTemplate?

    /// The last release tag whose What's New sheet the user has seen.
    @AppStorage("lastSeenWhatsNewTag") private var lastSeenWhatsNewTag = ""
    @State private var showingWhatsNew = false

    /// How many templates to surface directly in the + menu before spilling
    /// into the full picker.
    private let menuTemplateLimit = 5

    /// Destinations reachable from the top-left library menu.
    private enum LibraryDestination: Hashable { case allLists, templates }

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
            .navigationDestination(for: LibraryDestination.self) { destination in
                switch destination {
                case .allLists: AllListsView()
                case .templates: TemplatesView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        NavigationLink(value: LibraryDestination.allLists) {
                            Label("All Lists", systemImage: "tray.full")
                        }
                        NavigationLink(value: LibraryDestination.templates) {
                            Label("Templates", systemImage: "square.on.square")
                        }
                    } label: {
                        Label("Library", systemImage: "line.3.horizontal")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if templates.isEmpty {
                        // No templates yet — + goes straight to a blank list.
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Add List", systemImage: "plus")
                        }
                    } else {
                        Menu {
                            Button {
                                showingAdd = true
                            } label: {
                                Label("Blank List", systemImage: "plus")
                            }
                            Section("From Template") {
                                // Only the most recent few; the rest live in the
                                // searchable picker to keep the menu short.
                                ForEach(templates.prefix(menuTemplateLimit)) { template in
                                    Button {
                                        templateForNewList = template
                                    } label: {
                                        Label(template.name, systemImage: "square.on.square")
                                    }
                                }
                                if templates.count > menuTemplateLimit {
                                    Button {
                                        showingTemplatePicker = true
                                    } label: {
                                        Label("More Templates…", systemImage: "ellipsis")
                                    }
                                }
                            }
                        } label: {
                            Label("Add List", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                ChecklistFormView()
            }
            .sheet(item: $templateForNewList) { template in
                ChecklistFormView(template: template)
            }
            .sheet(isPresented: $showingTemplatePicker, onDismiss: {
                // Picker is fully gone now — safe to present the prefilled form
                // without a sheet-over-sheet race (no delay needed).
                if let picked = pickerSelection {
                    pickerSelection = nil
                    templateForNewList = picked
                }
            }) {
                TemplatePickerView(selection: $pickerSelection)
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
        .sheet(isPresented: $showingWhatsNew) {
            WhatsNewView()
        }
        .onAppear {
            NotificationManager.shared.requestAuthorization()
            maybeShowWhatsNew()
        }
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

    /// Show What's New once per release. It should reach *existing* users on the
    /// update that introduces these features — so an empty stored tag counts as
    /// "hasn't seen it" and still shows, as long as there's existing data (a
    /// genuinely fresh install has no lists/templates and is silently caught up).
    private func maybeShowWhatsNew() {
        guard lastSeenWhatsNewTag != WhatsNew.releaseTag else { return }
        let isFreshInstall = activeChecklists.isEmpty && templates.isEmpty
            && lastSeenWhatsNewTag.isEmpty
        if !isFreshInstall {
            showingWhatsNew = true
        }
        lastSeenWhatsNewTag = WhatsNew.releaseTag
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Checklist.self, Item.self, ListTemplate.self, TemplateItem.self], inMemory: true)
}
