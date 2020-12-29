#if os(iOS)
import UIKit

extension UINavigationController {
    func hideNavigationBar() {
        navigationBar.setBackgroundImage(UIImage(), for:.default)
        navigationBar.shadowImage = UIImage()
        navigationBar.layoutIfNeeded()
    }
}
#endif
