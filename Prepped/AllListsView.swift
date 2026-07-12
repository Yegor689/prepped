import SwiftUI
import SwiftData

/// Shows every checklist, split into Active and Completed sections.
/// Completed lists (hidden from home) live here and can be reopened.
struct AllListsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Checklist.dueDate) private var checklists: [Checklist]

    private var active: [Checklist] { checklists.filter { !$0.isCompleted } }
    private var completed: [Checklist] { checklists.filter { $0.isCompleted } }

    var body: some View {
        Group {
            if checklists.isEmpty {
                ContentUnavailableView(
                    "No Lists",
                    systemImage: "tray",
                    description: Text("Lists you create will appear here.")
                )
            } else {
                List {
                    if !active.isEmpty {
                        Section("Active") {
                            ForEach(active) { checklist in
                                NavigationLink {
                                    ChecklistDetailView(checklist: checklist)
                                } label: {
                                    ChecklistRow(checklist: checklist)
                                }
                            }
                        }
                    }

                    if !completed.isEmpty {
                        Section("Completed") {
                            ForEach(completed) { checklist in
                                NavigationLink {
                                    ChecklistDetailView(checklist: checklist)
                                } label: {
                                    ChecklistRow(checklist: checklist)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        reopen(checklist)
                                    } label: {
                                        Label("Reopen", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.blue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("All Lists")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func reopen(_ checklist: Checklist) {
        checklist.isCompleted = false
        NotificationManager.shared.reschedule(for: checklist)
    }
}
