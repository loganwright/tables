#if os(iOS)
import UIKit

class InsetTextField: UITextField {
    var textInsets: UIEdgeInsets = .zero

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: textInsets)
    }
}
#endif
