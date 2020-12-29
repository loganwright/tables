/// this is a hacky type to add paths to host
/// maybe future all host
public struct Endpoint: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public let stringValue: String

    public init(stringLiteral s: String) {
        self.stringValue = s
    }
}
