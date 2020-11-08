/// there's a lot of initialization and intermixing, sometimes lazy loading helps with cycles
/// and is good in preparation for more async support
@propertyWrapper
final class Later<T> {
    var wrappedValue: T {
        get {
            loader()
        }
        set {
            loader = { newValue }
        }
    }
    var projectedValue: Later<T> { self }

    fileprivate var loader: () -> T

    init(wrappedValue: T) {
        self.loader = { wrappedValue }
    }

    convenience init(_ t: T) {
        self.init(wrappedValue: t)
    }

    init(_ loader: @escaping () -> T) {
        self.loader = loader
    }
}
