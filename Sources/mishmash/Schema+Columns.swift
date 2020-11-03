import SQLKit

class SQLColumn {
    /// can't decide on naming, going back and forth :/
    var key: String {
        get { name }
        set { name = newValue }
    }

    open var name: String
    @Later open var type: SQLDataType

    /// using the Later attribute to allow nested columns to properly initialize
    @Later open var constraints: [SQLColumnConstraintAlgorithm]

    init(_ name: String, _ type: Later<SQLDataType>, _ constraints: Later<[SQLColumnConstraintAlgorithm]>) {
        self.name = name
        self._type = type
        self._constraints = constraints
    }

    init(_ name: String, _ type: SQLDataType, _ constraints: Later<[SQLColumnConstraintAlgorithm]>) {
        self.name = name
        self._type = Later(type)
        self._constraints = constraints
    }

    convenience init(_ name: String, _ type: SQLDataType, _ constraints: SQLColumnConstraintAlgorithm...) {
        self.init(name, type, Later(constraints))
    }
}

extension SQLColumn {
    var nullable: Bool {
        constraints.first { constraint in
            if case .notNull = constraint { return true }
            else { return false }
        } != nil
    }
}
