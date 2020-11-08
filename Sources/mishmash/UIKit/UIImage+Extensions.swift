#if os(iOS)

import Foundation
import UIKit

// MARK: Drawing

extension UIImage {
    static func makeCircle(size: CGSize, backgroundColor: UIColor) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            Log.warn("unable to make graphics context for circle graphic render")
            return nil
        }

        context.setFillColor(backgroundColor.cgColor)
        context.setStrokeColor(UIColor.clear.cgColor)
        let bounds = CGRect(origin: .zero, size: size)
        context.addEllipse(in: bounds)
        context.drawPath(using: .fill)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
#endif
