#if os(iOS)
import Foundation
import UIKit

extension CGRect {
    var center: CGPoint {
        .init(x: width / 2, y: height / 2)
    }
}

public extension Int {
    var radians: CGFloat {
        return CGFloat(self).toRadians
    }
}
public extension CGFloat {
    var toRadians: CGFloat {
        return CGFloat(Double(self) * (.pi / 180))
    }
    var toDegrees: CGFloat {
        return self * CGFloat(180.0 / .pi)
    }
}

public extension CGFloat {
    var squared: CGFloat {
        return self * self
    }
}

public extension CGPoint {
    static var one: CGPoint { .init(x: 1, y: 1) }
    
    func angle(to point: CGPoint) -> CGFloat {
        let originX = point.x - self.x
        let originY = point.y - self.y
        let bearingRadians = atan2f(Float(originY), Float(originX))
        var bearingDegrees = CGFloat(bearingRadians).toDegrees
        while bearingDegrees < 0 {
            bearingDegrees += 360
        }
        return bearingDegrees
    }

    func distanceToPoint(point: CGPoint) -> CGFloat {
        let distX = point.x - self.x
        let distY = point.y - self.y
        let distance = sqrt(distX.squared + distY.squared)
        return distance
    }
}

func +=(left: inout CGPoint, right: CGPoint) {
    left.x += right.x
    left.y += right.y
}

func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint {
    return CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
}

func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
}

func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint {
    return CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

func +(lhs: CGSize, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

func -(lhs: CGSize, rhs: CGSize) -> CGSize {
    return CGSize(width: lhs.width - rhs.width, height: lhs.height - rhs.height)
}

func *(lhs: CGSize, rhs: CGFloat) -> CGSize {
    return CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
}

func random(range: Range<Int>) -> Int {
    return Int.random(in: range)
}

public func avg(of numbers: CGFloat...) -> CGFloat {
    return numbers.reduce(0, +) / CGFloat(numbers.count)
}

public func circumferenceForRadius(_ radius: CGFloat) -> CGFloat {
    return radius * CGFloat(.pi * 2.0)
}

public func lengthOfArcForDegrees(degrees: CGFloat, radius: CGFloat) -> CGFloat {
    let circumference = circumferenceForRadius(radius)
    let percentage = degrees / 360.0
    return circumference * percentage
}

public func degreesForLengthOfArc(lengthOfArc: CGFloat, radius: CGFloat) -> CGFloat {
    let circumference = circumferenceForRadius(radius)
    let percentage = lengthOfArc / circumference
    return percentage * 360
}

public func pointWithCenter(center: CGPoint, radius: CGFloat, angleDegrees: CGFloat) -> CGPoint {
    let x = radius * cos(angleDegrees.toRadians) + center.x
    let y = radius * sin(angleDegrees.toRadians) + center.y
    return CGPoint(x: x, y: y)
}

public extension CGRect {
    var halfWidth: CGFloat {
        width / 2.0
    }

    var halfHeight: CGFloat {
        height / 2.0
    }

    var shortestEdge: CGFloat {
        return min(width, height)
    }

    var longestEdge: CGFloat {
        return max(width, height)
    }
}

extension CGSize {
    public func scaledHeightAtFixedWidth(_ fixedWidth: CGFloat) -> CGFloat {
        let scale = height / width
        return fixedWidth * scale
    }

    public func scaledWidthAtFixedHeight(_ fixedHeight: CGFloat) -> CGFloat {
        let scale = width / height
        return fixedHeight * scale
    }
}

extension CGRect {
    func inset(by: CGFloat) -> CGRect {
        return inset(by: .init(top: by, left: by, bottom: by, right: by))
    }
}

extension CGFloat {
    static var ninetyDegrees: CGFloat { CGFloat(.pi / 2.0) }
}

struct Geometry {
    /// assuming a fill from 0-1.0 where 0 is 12 o'clock, 0.25 is 3 o'clock, and so on
    static func convertToAngle(fill: Double) -> CGFloat {
        assert(0...1 ~= fill, "unsupported value, expected 0-1.0")
        let oneHundredEightyDegrees = Double.pi
        let ninetyDegrees = oneHundredEightyDegrees / 2.0
        let threeHundredSixtyDegrees = oneHundredEightyDegrees * 2.0

        /// drawing normally starts at 3 o'clock, we need to offset to draw from 12 o'clock
        let top = -ninetyDegrees
        let converted = fill * threeHundredSixtyDegrees
        return CGFloat(top + converted)
    }
}


extension CGRect {
    /// some view layouts crash if we raw w cgrect.zero, so this is better
    static var sizing: CGRect { .init(x: 0, y: 0, width: 160, height: 160) }
}
#endif
