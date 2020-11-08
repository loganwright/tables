typealias EP = Endpoint
/// this is a hacky type to add paths to host
struct Endpoint: ExpressibleByStringLiteral {
    typealias StringLiteralType = String

    let stringValue: String

    init(stringLiteral s: String) {
        self.stringValue = s
    }
}
