import SQLKit

// MARK: EphemeralColumns (Not Persisted)

/// schema fields that are not persisted, but a reference to something
/// in another table
@TablesActor
public protocol Relation {}

/// the key is not stored on this user
/// they query their id in other tables
@TablesActor
public protocol EphemeralRelation: Relation {
    /// the key on the current object to which the external objects are pointing
    var pointingTo: PrimaryKeyBase { get }
    /// column in the 'Many' table that contains the unowned id
    var pointingFrom: BaseColumn { get }
}

/**
 Use this type to attach to many references that are pointing at an object
 */
@propertyWrapper
public class ToMany<Many: Schema>: EphemeralRelation {
    public var wrappedValue: [Many] { replacedDynamically() }

    /// the key on the current object to which the external objects are pointing
    @Later public var pointingTo: PrimaryKeyBase
    /// the column in the 'Many' table that contains the unowned id
    @Later public var pointingFrom: BaseColumn

    public init<OuterSchema: Schema>(linkedBy linkingKeyPath: KeyPath<Many, ForeignKey<OuterSchema>>) {
        self._pointingTo = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.pointingTo
        }

        self._pointingFrom = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.pointingFrom
        }
    }
}

/**
 for when their is a single object in another table that has declared us as a foreign key
 */
@propertyWrapper
public class ToOne<One: Schema>: EphemeralRelation {
    public var wrappedValue: One? { replacedDynamically() }

    @Later public var pointingTo: PrimaryKeyBase
    @Later public var pointingFrom: BaseColumn

    public init<Foreign: Schema>(linkedBy reference: KeyPath<One, ForeignKey<Foreign>>) {
        self._pointingTo = Later {
            let externalColumn = One.template[keyPath: reference]
            return externalColumn.pointingTo
        }

        self._pointingFrom = Later {
            let child = One.template[keyPath: reference]
            return child.pointingFrom
        }
    }
}

extension Ref {
    internal var _id: String {
        let id = S.template.primaryKey!
        return backing[id.name]!.string!
    }
}

extension BaseColumn {
    var _sqlIdentifier: SQLIdentifier { .init(name) }
}
