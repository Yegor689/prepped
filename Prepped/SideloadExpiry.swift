import SwiftUI

/// Free (personal-team) code-signing certificates expire 7 days after the app
/// is built/installed, after which iOS refuses to launch the app until it's
/// re-sideloaded. There's no runtime API for the provisioning profile's expiry,
/// so we approximate it from the app bundle's build date: the last-modified
/// date of the main executable, which is stamped at build time.
///
/// This is a best-effort convenience for developers on a free account; it's a
/// no-op-friendly estimate, not an authoritative read of the signing cert.
enum SideloadExpiry {
    /// Free personal-team profiles are valid for 7 days.
    static let validityDays = 7

    /// When this build was produced, inferred from the executable's mod date.
    /// Cached: the executable's date can't change while the app is running, so
    /// we stat the filesystem once instead of on every view render.
    static let buildDate: Date? = {
        guard let exec = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: exec.path),
              let date = attrs[.modificationDate] as? Date
        else { return nil }
        return date
    }()

    /// Estimated moment the sideload expires (build date + validity window).
    /// Cached — derives only from the (fixed) build date.
    static let expiryDate: Date? = {
        guard let buildDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: validityDays, to: buildDate)
    }()

    /// Whole days remaining until expiry (0 = expires today, negative = expired).
    static var daysRemaining: Int? {
        guard let expiryDate else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: expiryDate)
        return cal.dateComponents([.day], from: start, to: end).day
    }

    /// The exact expiry moment, e.g. "Wed, Jul 15, 2026 at 3:42 PM".
    static var expiryDescription: String? {
        expiryDate?.formatted(.dateTime.weekday(.abbreviated).month().day().year().hour().minute())
    }

    /// When this build was installed/signed, e.g. "Jul 8, 2026".
    static var buildDescription: String? {
        buildDate?.formatted(.dateTime.month().day().year())
    }
}

/// Presentation for a given days-remaining value, shared by the banner and the
/// detail screen so the color, icon, and headline stay consistent.
private struct ExpiryStatus {
    let color: Color
    let icon: String
    let headline: String

    init(days: Int) {
        switch days {
        case ..<0:
            color = .red
            icon = "exclamationmark.triangle.fill"
            headline = "Sideload expired"
        case 0:
            color = .red
            icon = "exclamationmark.triangle.fill"
            headline = "Sideload expires today"
        case 1:
            color = .orange
            icon = "exclamationmark.triangle.fill"
            headline = "Sideload expires tomorrow"
        case 2:
            color = .orange
            icon = "clock.badge.checkmark"
            headline = "Sideload expires in 2 days"
        default:
            color = .secondary
            icon = "clock.badge.checkmark"
            headline = "Sideload expires in \(days) days"
        }
    }
}

/// Compact banner surfacing how long until the free-account sideload expires.
/// Stays quiet (secondary) most of the week and escalates to orange/red as the
/// deadline nears. Tapping it opens the detail screen with the exact date.
struct SideloadExpiryBanner: View {
    var body: some View {
        if let days = SideloadExpiry.daysRemaining {
            let status = ExpiryStatus(days: days)
            NavigationLink {
                SideloadExpiryDetailView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: status.icon)
                    Text(status.headline)
                        .font(.footnote.weight(.medium))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.6)
                }
                .foregroundStyle(status.color)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

/// Detail screen explaining the free-account 7-day sideload limit: the exact
/// date the app stops launching, when this build was signed, and how to renew.
struct SideloadExpiryDetailView: View {
    var body: some View {
        List {
            if let days = SideloadExpiry.daysRemaining {
                let status = ExpiryStatus(days: days)

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: status.icon)
                                .font(.title2)
                            Text(status.headline)
                                .font(.headline)
                        }
                        .foregroundStyle(status.color)

                        if let expiry = SideloadExpiry.expiryDescription {
                            Text("The app stops launching on \(expiry).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    LabeledContent("Days remaining",
                                   value: days < 0 ? "Expired" : "\(days)")
                    if let expiry = SideloadExpiry.expiryDescription {
                        LabeledContent("Stops working", value: expiry)
                    }
                    if let build = SideloadExpiry.buildDescription {
                        LabeledContent("Installed", value: build)
                    }
                    LabeledContent("Valid for", value: "\(SideloadExpiry.validityDays) days")
                }
            } else {
                Section {
                    Text("Expiry can't be determined for this build.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("""
                Apps installed with a free Apple ID are only signed for \
                \(SideloadExpiry.validityDays) days. After that, iOS refuses to \
                open the app until it's reinstalled.

                To reset the timer, reconnect this device to the Mac it was \
                installed from and run the app again from Xcode. Reinstalling \
                over the top keeps all your lists — don't delete the app first.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            } header: {
                Text("Why this happens")
            }
        }
        .navigationTitle("Sideload")
        .navigationBarTitleDisplayMode(.inline)
    }
}
