#if os(iOS)
import UIKit

extension UIView {
    static func animate(_ animations: @escaping () -> Void, then: @escaping (Bool) -> Void = { _ in }) {
        UIView.animate(withDuration: 0.25, animations: animations, completion: then)
    }
}
#endif
