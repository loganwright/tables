import Foundation

public struct Lock {
    private let nslock = NSLock()
    init() {}

    public func lock() {
        self.nslock.lock()
    }

    public func unlock() {
        self.nslock.unlock()
    }

    public func run(_ closure: () throws -> Void) rethrows {
        self.lock()
        try closure()
        self.unlock()
    }

    public func run<T>(_ closure: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try closure()
    }
}

@propertyWrapper
struct ThreadSafe<Value> {
    private var value: Value
    private let lock = Lock()

    init(wrappedValue value: Value) {
        self.value = value
    }

    var wrappedValue: Value {
        get { return lock.run { return value } }
        set { lock.run { value = newValue } }
    }
}
