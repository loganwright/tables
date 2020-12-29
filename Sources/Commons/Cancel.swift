public class Cancel {
    public private(set) var cancelled = false
    public init() {}
    public func callAsFunction() {
        cancelled = true
    }
}
