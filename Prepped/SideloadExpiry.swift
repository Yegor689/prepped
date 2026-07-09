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
    static var buildDate: Date? {
        guard let exec = Bundle.main.executableURL,
              let attrs = try? FileManager.default.attributesOfItem(atPath: exec.path),
              let date = attrs[.modificationDate] as? Date
        else { return nil }
        return date
    }

    /// Estimated moment the sideload expires (build date + validity window).
    static var expiryDate: Date? {
        guard let buildDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: validityDays, to: buildDate)
    }

    /// Whole days remaining until expiry (0 = expires today, negative = expired).
    static var daysRemaining: Int? {
        guard let expiryDate else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: expiryDate)
        return cal.dateComponents([.day], from: start, to: end).day
    }
}

/// Compact banner surfacing how long until the free-account sideload expires.
/// Stays quiet (green/secondary) most of the week and escalates to orange/red
/// as the deadline nears so it's easy to ignore until it matters.
struct SideloadExpiryBanner: View {
    var body: some View {
        if let days = SideloadExpiry.daysRemaining {
            HStack(spacing: 8) {
                Image(systemName: icon(for: days))
                Text(message(for: days))
                    .font(.footnote.weight(.medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(color(for: days))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color(for: days).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func message(for days: Int) -> String {
        switch days {
        case ..<0:  return "Sideload expired — reinstall from Xcode"
        case 0:     return "Sideload expires today — reinstall soon"
        case 1:     return "Sideload expires tomorrow"
        default:    return "Sideload expires in \(days) days"
        }
    }

    private func icon(for days: Int) -> String {
        days <= 1 ? "exclamationmark.triangle.fill" : "clock.badge.checkmark"
    }

    private func color(for days: Int) -> Color {
        switch days {
        case ..<1:  return .red
        case 1...2: return .orange
        default:    return .secondary
        }
    }
}
