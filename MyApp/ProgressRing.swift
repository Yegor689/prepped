import SwiftUI

/// A circular progress indicator. Shows the fraction complete as a ring,
/// with the completed-count in the center (or a checkmark when fully done).
struct ProgressRing: View {
    var progress: Double          // 0...1
    var tint: Color
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    var centerText: String? = nil
    var isComplete: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.25), value: progress)

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(tint)
            } else if let centerText {
                Text(centerText)
                    .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}
