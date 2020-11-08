import Foundation

extension Double {
    var twoDecimalPlaces: String {
        String(format: "%.2f", self)
    }
}
