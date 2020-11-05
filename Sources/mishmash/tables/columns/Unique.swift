import SQLKit

@propertyWrapper
class Unique<Value>: Column<Value> {
    override var wrappedValue: Value { replacedDynamically() }
    override init(_ name: String = "",
                  _ type: SQLDataType,
                  _ constraints: Later<[SQLColumnConstraintAlgorithm]> = Later([])) {
        super.init(name, type, constraints)
    }
}

extension Unique where Value: DatabaseValue {
    convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.sqltype, Later(constraints + [.notNull, .unique]))
    }
}

extension Unique where Value: OptionalProtocol, Value.Wrapped: DatabaseValue {
    convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.Wrapped.sqltype, Later(constraints))
    }
}
