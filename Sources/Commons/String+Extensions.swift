extension String.StringInterpolation {
    public mutating func appendInterpolation<T>(optional: T?) {
        appendInterpolation(String(describing: optional))
    }
}
