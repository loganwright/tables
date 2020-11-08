extension String.StringInterpolation {
    mutating func appendInterpolation<T>(optional: T?) {
        appendInterpolation(String(describing: optional))
    }
}
