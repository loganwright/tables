extension HeaderKey {
    var contentType: String { "Content-Type" }
    var authorization: String { "Authorization" }
    var accept: String { "Accept" }
}

struct HeaderKey: ExpressibleByStringLiteral {
    typealias StringLiteralType = String

    let stringValue: String

    init(stringLiteral s: String) {
        self.stringValue = s
    }
}
