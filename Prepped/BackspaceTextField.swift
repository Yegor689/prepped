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
    /// Called when the user hits Return. Returning `true` means a new row was
    /// inserted and focus was handed off elsewhere, so this field should NOT
    /// resign; returning `false` just dismisses as usual.
    var onReturn: () -> Bool = { false }
    /// Reports the live UITextField as it's created/torn down, so a caller can
    /// hand focus directly to a specific row's field (e.g. the previous item,
    /// to keep the keyboard up across a delete) without going through
    /// SwiftUI's per-row @FocusState, which can't target a dynamic ForEach row.
    var onFieldAvailable: (UITextField?) -> Void = { _ in }

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
        field.returnKeyType = .next
        onFieldAvailable(field)
        return field
    }

    func updateUIView(_ field: DeleteReportingTextField, context: Context) {
        // Keep the latest closures so they capture current SwiftUI state.
        field.onDeleteBackwardWhenEmpty = onDeleteBackwardWhenEmpty
        context.coordinator.parent = self
        if field.text != text {
            field.text = text
        }
        applyStyle(to: field)
    }

    static func dismantleUIView(_ field: DeleteReportingTextField, coordinator: Coordinator) {
        coordinator.parent.onFieldAvailable(nil)
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
        var parent: BackspaceTextField
        init(_ parent: BackspaceTextField) { self.parent = parent }

        @objc func textChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            // If a new row was inserted and focused, this field is about to
            // lose first responder to it — don't also resign, which would
            // race and drop the keyboard.
            if !parent.onReturn() {
                field.resignFirstResponder()
            }
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
