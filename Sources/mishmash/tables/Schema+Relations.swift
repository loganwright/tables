import SQLKit

/**
 A general person way to reference other objects from the databasek,
 the inverse of foreign key would be ToOne or ToMany depending on whether
 multiple objects declare the key


 foreign keys can also go two ways where, two objects both have references to the other
 */
@propertyWrapper
class ForeignKey<Foreign: Schema>: Column<Foreign?> {
    /// the column in the foreign table that is being pointed to
    @Later var pointingTo: PrimaryKeyBase
    /// in this case, we are referring to the current column
    var pointingFrom: BaseColumn { self }
    private(set) var onDelete: SQLForeignKeyAction?
    private(set) var onUpdate: SQLForeignKeyAction?

    override var wrappedValue: Foreign? { replacedDynamically() }

    init(_ name: String = "",
         pointingTo foreign: Later<PrimaryKeyBase>,
         onUpdate: SQLForeignKeyAction? = nil,
         onDelete: SQLForeignKeyAction? = nil) {

        self._pointingTo = foreign
        let type = Later<SQLDataType> { foreign.wrappedValue.kind.sqltype }
        super.init(name, type, Later([]))

        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    // MARK: Type Constrained Primary Keys

    convenience init(_ name: String = "",
                     pointingTo foreign: KeyPath<Foreign, PrimaryKeyBase>,
                     onUpdate: SQLForeignKeyAction? = nil,
                     onDelete: SQLForeignKeyAction? = nil) {

        let _pointingTo = Later<PrimaryKeyBase> { Foreign.template[keyPath: foreign] }
        self.init(name, pointingTo: _pointingTo, onUpdate: onUpdate, onDelete: onDelete)
    }

    convenience init(_ name: String = "",
                     pointingTo foreign: KeyPath<Foreign, PrimaryKey<Int>>,
                     onUpdate: SQLForeignKeyAction? = nil,
                     onDelete: SQLForeignKeyAction? = nil) {
        let _pointingTo = Later<PrimaryKeyBase> { Foreign.template[keyPath: foreign] }
        self.init(name, pointingTo: _pointingTo, onUpdate: onUpdate, onDelete: onDelete)
    }

    convenience init(_ name: String = "",
         pointingTo foreign: KeyPath<Foreign, PrimaryKey<String>>,
         onUpdate: SQLForeignKeyAction? = nil,
         onDelete: SQLForeignKeyAction? = nil) {
        let _pointingTo = Later<PrimaryKeyBase> {
            Foreign.template[keyPath: foreign]
        }
        self.init(name, pointingTo: _pointingTo, onUpdate: onUpdate, onDelete: onDelete)
    }
}

/// an object can have multiple foreign key columns as long as each points
/// to a different table, but they have to be serialized at the end
protocol ForeignColumnKeyConstraint {
    var pointingFrom: BaseColumn { get }
    // todo: support multikeys
    var pointingTo: PrimaryKeyBase { get }
    var pointingToRemoteTable: String { get }
    var onUpdate: SQLForeignKeyAction? { get }
    var onDelete: SQLForeignKeyAction? { get }
    var named: String? { get }
}

extension ForeignColumnKeyConstraint {
    var named: String? { nil }
}

extension ForeignKey: ForeignColumnKeyConstraint {
    var pointingToRemoteTable: String { Foreign.table }
}

// MARK: Prepare / Create

extension SQLCreateTableBuilder {
    /// There's a lot of subtle differences in how foreign constraints are grouped
    /// for now, it's best to assume foreign keys
    func add(foreignColumnConstraint fc: ForeignColumnKeyConstraint) -> SQLCreateTableBuilder {
        foreignKey([fc.pointingFrom.name],
                   references: fc.pointingToRemoteTable,
                   [fc.pointingTo.name],
                   onDelete: fc.onDelete,
                   onUpdate: fc.onUpdate,
                   named: nil)
    }
}

extension Array where Element == ForeignColumnKeyConstraint {
    var validateTableMatch: Bool {
        Set(map(\.pointingToRemoteTable)).count == 1
    }
}

extension Array where Element == BaseColumn {
    var _foreignConstraints: [ForeignColumnKeyConstraint] {
        compactMap { $0 as? ForeignColumnKeyConstraint }
    }
    var allPrimaryKeys: Bool {
        allSatisfy { $0 is PrimaryKeyBase }
    }

    var allForeignKeys: Bool {
        allSatisfy { $0 is ForeignColumnKeyConstraint }
    }

    var allUniqueable: Bool {
        filter { $0 is PrimaryKeyBase || $0 is ForeignColumnKeyConstraint } .isEmpty
    }
}


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

/// there's a lot of initialization and intermixing, sometimes lazy loading helps with cycles
/// and is good in preparation for more async support
@propertyWrapper
final class Later<T> {
    var wrappedValue: T {
        get {
            loader()
        }
        set {
            loader = { newValue }
        }
    }
    var projectedValue: Later<T> { self }

    fileprivate var loader: () -> T

    init(wrappedValue: T) {
        self.loader = { wrappedValue }
    }

    convenience init(_ t: T) {
        self.init(wrappedValue: t)
    }

    init(_ loader: @escaping () -> T) {
        self.loader = loader
    }
}
