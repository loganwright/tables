import SQLKit

// MARK: EphemeralColumns (Not Persisted)

/// schema fields that are not persisted, but a reference to something
/// in another table
protocol Relation {}

/// the key is not stored on this user
/// they query their id in other tables
protocol EphemeralRelation: Relation {
    /// the key on the current object to which the external objects are pointing
    var pointingTo: PrimaryKeyBase { get }
    /// column in the 'Many' table that contains the unowned id
    var pointingFrom: BaseColumn { get }
}

/**
 Use this type to attach to many references that are pointing at an object
 */
@propertyWrapper
class ToMany<Many: Schema>: EphemeralRelation {
    var wrappedValue: [Many] { replacedDynamically() }

    /// the key on the current object to which the external objects are pointing
    @Later var pointingTo: PrimaryKeyBase
    /// the column in the 'Many' table that contains the unowned id
    @Later var pointingFrom: BaseColumn

    init<OuterSchema: Schema>(linkedBy linkingKeyPath: KeyPath<Many, ForeignKey<OuterSchema>>) {
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
class ToOne<One: Schema>: EphemeralRelation {
    var wrappedValue: One? { replacedDynamically() }

    @Later var pointingTo: PrimaryKeyBase
    @Later var pointingFrom: BaseColumn

    init<Foreign: Schema>(linkedBy reference: KeyPath<One, ForeignKey<Foreign>>) {
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
    var _id: String {
        let id = S.template._primaryKey
        return backing[id.name]!.string!
    }
}

extension BaseColumn {
    var _sqlIdentifier: SQLIdentifier { .init(name) }
}
