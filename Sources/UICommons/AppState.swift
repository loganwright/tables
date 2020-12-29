import UIKit

public unowned let keyWindow = UIApplication.shared.windows.first!

extension CGFloat {
    ///
    /// top notch: 47, bottom: line 34
    /// a little hacky, but it's the most consistent
    public var paddingTop: CGFloat {
        if #available(iOS 11.0, *) {
            return self + keyWindow.safeAreaInsets.top
        } else {
            return 20 // the info bar
        }
    }

    public var paddingBottom: CGFloat {
        if #available(iOS 11.0, *) {
            return self + keyWindow.safeAreaInsets.bottom
        } else {
            return 0
        }
    }
}

extension Int {
    /// a little hacky, but it's the most consistent
    public var paddingTop: CGFloat {
        CGFloat(self).paddingTop
    }

    /// bottom is 34 on swipe up devices
    public var paddingBottom: CGFloat {
        CGFloat(self).paddingBottom
    }
}

// Global Imports

@_exported import Commons
