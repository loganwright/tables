#if canImport(UIKit)
import UIKit

extension CALayer {
    /// transforms the given layer
    /// might need concat if pairing with other transforms
    public func offset(by offset: CGPoint) {
        self.transform = CGAffineTransform(
            translationX: offset.x, y: offset.y
        ).caAffine3d
    }
}

extension CGAffineTransform {
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> CGAffineTransform {
        CGAffineTransform(translationX: x, y: y)
    }

    public static func scale(x: CGFloat = 1, y: CGFloat = 1) -> CGAffineTransform {
        CGAffineTransform(scaleX: x, y: y)
    }

    public var caAffine3d: CATransform3D { CATransform3DMakeAffineTransform(self) }
}
#endif
