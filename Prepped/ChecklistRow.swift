import SwiftUI

/// A checklist's home/all-lists row: accent bar, progress ring, name, relative
/// due description, a notes glyph, and an "Overdue" pill. Shared by the home
/// screen and All Lists.
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
