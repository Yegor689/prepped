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
        // Fire on the lead day at the due time-of-day (or 9 AM if the list has
        // no specific time), i.e. `reminderLead` days before the due date.
        let dueDay = cal.startOfDay(for: checklist.dueDate)
        let hour: Int
        let minute: Int
        if checklist.hasTime {
            let comps = cal.dateComponents([.hour, .minute], from: checklist.dueDate)
            hour = comps.hour ?? reminderHour
            minute = comps.minute ?? 0
        } else {
            hour = reminderHour
            minute = 0
        }
        guard let leadDay = cal.date(byAdding: .day, value: -checklist.reminderLead.rawValue, to: dueDay),
              let fireDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: leadDay)
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

    /// Full resync — call on app foreground as a safety net. Only touches
    /// requests that are actually out of sync: reads the currently-pending set
    /// once, then reschedules a list only when whether-it-should-be-scheduled
    /// disagrees with reality. Avoids a cancel+add round-trip per list on every
    /// foreground.
    func rescheduleAll(_ checklists: [Checklist]) {
        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let pendingIDs = Set(pending.map(\.identifier))
            for checklist in checklists {
                let id = checklist.id.uuidString
                let shouldBeScheduled = !checklist.isCompleted
                    && !checklist.allItemsDone
                    && checklist.reminderLead != .none
                let isScheduled = pendingIDs.contains(id)
                // In sync already — nothing to do.
                if shouldBeScheduled == isScheduled { continue }
                // Hop to main: reschedule reads SwiftData model properties.
                DispatchQueue.main.async {
                    self.reschedule(for: checklist)
                }
            }
        }
    }
}
