import SwiftUI

/// A single highlighted change shown in the What's New sheet.
private struct Highlight: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

/// One-time "What's New" sheet surfacing this release's highlights. Gated by a
/// release tag stored in `@AppStorage`, so it shows once after an update and
/// not again until the tag changes (bump `WhatsNew.releaseTag` per release).
enum WhatsNew {
    /// Bump this string whenever the highlights below change; that's what makes
    /// the sheet reappear once for existing users.
    static let releaseTag = "2026.07-templates"

    fileprivate static let highlights: [Highlight] = [
        Highlight(
            icon: "square.on.square",
            title: "List templates",
            detail: "Save a set of items you use often, then start a new list from it in one tap — right from the + button."
        ),
        Highlight(
            icon: "clock",
            title: "Due times",
            detail: "Give a list an exact time, not just a day. Reminders fire at that time, and a list isn't marked overdue until it actually passes."
        ),
        Highlight(
            icon: "keyboard",
            title: "Faster item entry",
            detail: "Press return to add an item anywhere in a list, and backspace on an empty item to remove it."
        ),
    ]
}

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("What's New")
                            .font(.largeTitle.weight(.bold))
                        Text("in Prepped")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(WhatsNew.highlights) { item in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: item.icon)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 34)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title)
                                        .font(.headline)
                                    Text(item.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .presentationDragIndicator(.visible)
    }
}
