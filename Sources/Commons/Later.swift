/// there's a lot of initialization and intermixing, sometimes lazy loading helps with cycles
/// and is good in preparation for more async support
@propertyWrapper
public final class Later<T> {
    private(set) var hasLoaded: Bool = false
    private lazy var backing: T = {
        self.hasLoaded = true
        return self.loader()
    }()
    public var wrappedValue: T {
        get {
            backing
        }
        set {
            backing = newValue
        }
    }
    public var projectedValue: Later<T> { self }

    fileprivate var loader: () -> T

    public init(wrappedValue: T) {
        self.loader = { wrappedValue }
    }

    public convenience init(_ t: T) {
        self.init(wrappedValue: t)
    }

    public init(_ loader: @escaping () -> T) {
        self.loader = loader
    }

    public func callAsFunction() -> T {
        wrappedValue
    }
}
