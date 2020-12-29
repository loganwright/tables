public struct HeaderKey: ExpressibleByStringLiteral {
    public typealias StringLiteralType = String

    public let stringValue: String

    public init(stringLiteral s: String) {
        self.stringValue = s
    }

    public var contentType: String = "Content-Type"
    public var authorization: String = "Authorization"
    public var accept: String = "Accept"
}
