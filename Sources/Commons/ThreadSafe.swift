import Foundation

public struct Lock {
    private let nslock = NSLock()
    public init() {}

    public func lock() {
        self.nslock.lock()
    }

    public func unlock() {
        self.nslock.unlock()
    }

    public func blocking(_ closure: () throws -> Void) rethrows {
        self.lock()
        try closure()
        self.unlock()
    }

    public func blocking<T>(_ closure: () throws -> T) rethrows -> T {
        self.lock()
        defer { self.unlock() }
        return try closure()
    }
}

@propertyWrapper
public struct ThreadSafe<Value> {
    private var value: Value
    private let lock = Lock()

    public init(wrappedValue value: Value) {
        self.value = value
    }

    public var wrappedValue: Value {
        get { return lock.blocking { return value } }
        set { lock.blocking { value = newValue } }
    }
}
