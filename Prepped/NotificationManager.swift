import Foundation
import UserNotifications

/// Centralizes local-notification scheduling for checklists.
///
/// iOS can't evaluate app logic at fire time, so the "only notify while items
/// remain unfinished" rule is enforced by:
///  - scheduling only when the checklist has unfinished items and isn't complete,
///  - cancelling the pending request the moment it finishes / is completed,
///  - rescheduling on any relevant change.
/// Each request uses the checklist's `id` (UUID string) as its identifier.
final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    /// Hour of day (24h) reminders are delivered at.
    private let reminderHour = 9

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error { print("Notification auth error: \(error)") }
        }
    }

    /// Schedule or cancel the reminder for a single checklist based on its state.
    func reschedule(for checklist: Checklist) {
        let id = checklist.id.uuidString
        cancel(id: id)

        // Nothing to remind about if it's done, has no outstanding items, or
        // the user turned the reminder off.
        guard !checklist.isCompleted,
              !checklist.allItemsDone,
              checklist.reminderLead != .none else { return }

        let cal = Calendar.current
        // Start from the due day, go back the chosen number of days, then set to 9 AM.
        let dueDay = cal.startOfDay(for: checklist.dueDate)
        guard let leadDay = cal.date(byAdding: .day, value: -checklist.reminderLead.rawValue, to: dueDay),
              let fireDate = cal.date(bySettingHour: reminderHour, minute: 0, second: 0, of: leadDay)
        else { return }

        // If that moment has already passed, fire shortly from now instead of skipping.
        let effectiveDate = max(fireDate, Date().addingTimeInterval(5))

        let content = UNMutableNotificationContent()
        content.title = checklist.name
        content.body = "Due \(checklist.dueDate.formatted(date: .abbreviated, time: .omitted)) — \(checklist.completedItemCount)/\(checklist.totalItemCount) done."
        content.sound = .default

        let components = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: effectiveDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancel(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancel(for checklist: Checklist) {
        cancel(id: checklist.id.uuidString)
    }

    /// Full resync — call on app foreground as a safety net.
    func rescheduleAll(_ checklists: [Checklist]) {
        for checklist in checklists { reschedule(for: checklist) }
    }
}
