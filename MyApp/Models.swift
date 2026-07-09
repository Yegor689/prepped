import Foundation
import SwiftData

/// When a list's reminder fires, expressed as days before the due date.
/// Reminders are delivered at 9:00 AM on that day.
enum ReminderLead: Int, CaseIterable, Identifiable {
    case none = -1
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none:      return "No reminder"
        case .oneDay:    return "1 day before"
        case .threeDays: return "3 days before"
        case .oneWeek:   return "1 week before"
        }
    }

    /// Short form for compact display, e.g. in the detail header.
    var shortLabel: String {
        switch self {
        case .none:      return "Off"
        case .oneDay:    return "1 day before"
        case .threeDays: return "3 days before"
        case .oneWeek:   return "1 week before"
        }
    }
}

@Model
final class Checklist {
    var id: UUID = UUID()
    var name: String = ""
    var notes: String = ""
    var dueDate: Date = Date.now
    var createdAt: Date = Date.now
    var isCompleted: Bool = false
    /// Raw value of a `ListColor` case; drives the list's accent.
    var colorName: String = ListColor.blue.rawValue
    /// Days before the due date to fire the reminder. `-1` = no reminder.
    var reminderLeadDays: Int = ReminderLead.oneDay.rawValue

    @Relationship(deleteRule: .cascade, inverse: \Item.checklist)
    var items: [Item]

    init(name: String, notes: String = "", dueDate: Date,
         colorName: String = ListColor.blue.rawValue,
         reminderLeadDays: Int = ReminderLead.oneDay.rawValue) {
        self.id = UUID()
        self.name = name
        self.notes = notes
        self.dueDate = dueDate
        self.createdAt = .now
        self.isCompleted = false
        self.colorName = colorName
        self.reminderLeadDays = reminderLeadDays
        self.items = []
    }

    var color: ListColor { ListColor(rawValue: colorName) ?? .blue }
    var reminderLead: ReminderLead { ReminderLead(rawValue: reminderLeadDays) ?? .oneDay }

    var totalItemCount: Int { items.count }
    var completedItemCount: Int { items.filter(\.isDone).count }
    var allItemsDone: Bool { !items.isEmpty && completedItemCount == totalItemCount }
    var progress: Double {
        totalItemCount == 0 ? 0 : Double(completedItemCount) / Double(totalItemCount)
    }
    var isOverdue: Bool { dueDate < .now && !allItemsDone }

    /// Human-friendly relative due description, e.g. "Due today",
    /// "Due in 3 days", "2 days overdue".
    var dueDescription: String {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        let startOfDue = cal.startOfDay(for: dueDate)
        let days = cal.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0

        switch days {
        case 0: return "Due today"
        case 1: return "Due tomorrow"
        case -1: return "1 day overdue"
        case let d where d > 1: return "Due in \(d) days"
        default: return "\(-days) days overdue"
        }
    }
}

@Model
final class Item {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var createdAt: Date = Date.now
    /// Manual sort position within the parent checklist (lower = higher up).
    var order: Int = 0
    var checklist: Checklist?

    init(title: String, order: Int = 0, checklist: Checklist? = nil) {
        self.id = UUID()
        self.title = title
        self.isDone = false
        self.createdAt = .now
        self.order = order
        self.checklist = checklist
    }
}
