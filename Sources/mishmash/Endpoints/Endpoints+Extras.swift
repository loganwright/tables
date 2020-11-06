enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

extension String {
    var withTrailingSlash: String {
        if hasSuffix("/") { return self }
        else { return self + "/" }
    }
}
