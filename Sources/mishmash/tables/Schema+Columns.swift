import SQLKit

/// should this be BaseColumn?
class SQLColumn {
    /// the name of the column
    open var name: String

    /// the type of data stored
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

// MARK: KeyPath

extension SQLColumn {
    var detyped: SQLColumn {
        return self
    }
}

extension KeyPath where Value: SQLColumn {
    var detyped: KeyPath<Root, SQLColumn> {
        appending(path: \.detyped)
    }
}

extension SQLColumn {
    var base: SQLColumn {
        return self
    }
}

extension KeyPath where Value: SQLColumn {
    /// this is a concession to it being difficult to work with
    /// key types on their own especially groups of them
    ///
    var base: KeyPath<Root, SQLColumn> {
        appending(path: \.detyped)
    }
}

//postfix func /<S: Schema, C: SQLColumn>(_ kp: KeyPath<S, C>)
//-> KeyPath<S, SQLColumn> {
//    kp.detyped
//}
