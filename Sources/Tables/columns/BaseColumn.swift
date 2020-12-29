import SQLKit

/// should this be BaseColumn?
class BaseColumn {
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

extension BaseColumn {
    /// we need to occasionallly detype key paths, these can't be recast
    /// but they can append this to the key path to assist the compiler
    var detyped: BaseColumn {
        return self
    }
}

extension KeyPath where Value: BaseColumn {
    var detyped: KeyPath<Root, BaseColumn> {
        appending(path: \.detyped)
    }
}

extension BaseColumn {
    var root: BaseColumn {
        return self
    }
}

extension KeyPath where Value: BaseColumn {
    /// this is a concession to it being difficult to work with
    /// key types on their own especially groups of them
    ///
    var root: KeyPath<Root, BaseColumn> {
        appending(path: \.detyped)
    }
}

extension BaseColumn {
    var k: BaseColumn {
        return self
    }
}

extension KeyPath where Value: BaseColumn {
    /// this is a concession to it being difficult to work with
    /// key types on their own especially groups of them
    ///
    var k: KeyPath<Root, BaseColumn> {
        appending(path: \.detyped)
    }
}
extension BaseColumn {
    var base: BaseColumn {
        return self
    }
}

extension KeyPath where Value: BaseColumn {
    /// this is a concession to it being difficult to work with
    /// key types on their own especially groups of them
    ///
    var base: KeyPath<Root, BaseColumn> {
        appending(path: \.detyped)
    }
}
