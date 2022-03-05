import SQLKit
@_exported import Commons

/// should this be BaseColumn?
@TablesActor
public class BaseColumn {
    /// the name of the column
    open var name: String

    /// the type of data stored
    @Later open var type: SQLDataType

    /// using the Later attribute to allow nested columns to properly initialize
    @Later open var constraints: [SQLColumnConstraintAlgorithm]

    public init(_ name: String, _ type: Later<SQLDataType>, _ constraints: Later<[SQLColumnConstraintAlgorithm]>) {
        self.name = name
        self._type = type
        self._constraints = constraints
    }

    public init(_ name: String, _ type: SQLDataType, _ constraints: Later<[SQLColumnConstraintAlgorithm]>) {
        self.name = name
        self._type = Later(type)
        self._constraints = constraints
    }

    convenience init(_ name: String, _ type: SQLDataType, _ constraints: SQLColumnConstraintAlgorithm...) {
        self.init(name, type, Later(constraints))
    }
}

