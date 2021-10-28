import SQLKit

// MARK: Column

@propertyWrapper
public class Column<Value>: BaseColumn {
    open var wrappedValue: Value { replacedDynamically() }
}

extension Column where Value: DatabaseValue {
    public convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.sqltype, Later(constraints + [.notNull]))
    }
}

extension Column where Value: OptionalProtocol, Value.Wrapped: DatabaseValue {
    public convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.Wrapped.sqltype, Later(constraints))
    }
}
