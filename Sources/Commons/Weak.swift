public struct Weak<T: AnyObject> {
    public weak var t: T?
    public var value: T? { t }
    public init(_ t: T) {
        self.t = t
    }
}
