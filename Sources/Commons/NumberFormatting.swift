import Foundation

extension Double {
    public var twoDecimalPlaces: String {
        String(format: "%.2f", self)
    }
}
