import SwiftUI

/// The tinted summary card at the top of the checklist detail screen: progress
/// ring, due description, weekday/date (with time when set), item counts, the
/// reminder line, and the note (below a hairline divider).
struct ChecklistHeaderCard: View {
    let checklist: Checklist

    private var tint: Color { checklist.color.color }

    var body: some View {
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

                // Subtle affordance that the card is tappable to edit.
                Image(systemName: "pencil")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .accessibilityHidden(true)
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
}
