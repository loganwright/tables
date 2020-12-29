#if os(iOS)
import UIKit
import Commons

extension String {
    public var uicolor: UIColor {
        return .init(hex: self)
    }
    public var localUIImage: UIImage! {
        let img = UIImage(named: self)
        if img == nil, self != "empty" {
            Log.warn("missing expected local image named: \(self)")
        }
        return img
    }
}

extension UIColor {
    public convenience init(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 else {
            fatalError("unexpected hex color format")
        }

        let cleanHex = hex.uppercased()
        let chars = Array(cleanHex)
        let rChars = chars[1...2]
        let gChars = chars[3...4]
        let bChars = chars[5...6]

        var r: UInt64 = 0, g: UInt64 = 0, b: UInt64 = 0;
        Scanner(string: .init(rChars)).scanHexInt64(&r)
        Scanner(string: .init(gChars)).scanHexInt64(&g)
        Scanner(string: .init(bChars)).scanHexInt64(&b)
        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(1)
        )
    }
}

extension CGColor {
    public static func convert(_ ui: UIColor) -> CGColor {
        ui.cgColor
    }
}
#endif
