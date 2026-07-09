import SwiftUI
import UIKit

/// A `TextField`-equivalent that also reports a backspace pressed while the
/// field is already empty — SwiftUI's `TextField` gives no hook for this, so we
/// wrap `UITextField` and intercept `deleteBackward()`.
///
/// Used for checklist items so backspacing on an empty item deletes the row
/// (the familiar Notes/Reminders behavior).
struct BackspaceTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var strikethrough: Bool = false
    var isDimmed: Bool = false
    /// Called when the user hits delete/backspace while the field is empty.
    var onDeleteBackwardWhenEmpty: () -> Void = {}

    func makeUIView(context: Context) -> DeleteReportingTextField {
        let field = DeleteReportingTextField()
        field.placeholder = placeholder
        field.delegate = context.coordinator
        field.addTarget(context.coordinator,
                        action: #selector(Coordinator.textChanged(_:)),
                        for: .editingChanged)
        field.onDeleteBackwardWhenEmpty = onDeleteBackwardWhenEmpty
        // Match a plain SwiftUI TextField's sizing behavior inside a List row.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.returnKeyType = .done
        return field
    }

    func updateUIView(_ field: DeleteReportingTextField, context: Context) {
        // Keep the latest closure so it captures current SwiftUI state.
        field.onDeleteBackwardWhenEmpty = onDeleteBackwardWhenEmpty
        if field.text != text {
            field.text = text
        }
        applyStyle(to: field)
    }

    private func applyStyle(to field: UITextField) {
        let color: UIColor = isDimmed ? .secondaryLabel : .label
        let title = field.text ?? ""
        if strikethrough {
            field.attributedText = NSAttributedString(
                string: title,
                attributes: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: color,
                ]
            )
        } else {
            // Plain text; clear any prior strikethrough attributes.
            field.attributedText = NSAttributedString(
                string: title,
                attributes: [.foregroundColor: color]
            )
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let parent: BackspaceTextField
        init(_ parent: BackspaceTextField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// `UITextField` subclass that reports a backspace pressed on empty text.
final class DeleteReportingTextField: UITextField {
    var onDeleteBackwardWhenEmpty: () -> Void = {}

    override func deleteBackward() {
        let wasEmpty = (text ?? "").isEmpty
        super.deleteBackward()
        if wasEmpty {
            onDeleteBackwardWhenEmpty()
        }
    }
}
