import SQLKit

@propertyWrapper
public class Unique<Value>: Column<Value> {
    public override var wrappedValue: Value { replacedDynamically() }
    public override init(_ name: String = "",
                         _ type: SQLDataType,
                         _ constraints: Later<[SQLColumnConstraintAlgorithm]> = Later([])) {
        super.init(name, type, Later { constraints.wrappedValue + [.unique] })
    }
}

extension Unique where Value: DatabaseValue {
    public convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.sqltype, Later(constraints + [.notNull, .unique]))
    }
}

extension Unique where Value: OptionalProtocol, Value.Wrapped: DatabaseValue {
    public convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.Wrapped.sqltype, Later(constraints + [.unique]))
    }
}
