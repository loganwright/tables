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

// MARK: Preparations

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
        Log.warn("should this just use the foreignkey type and skip protocol?")
        return foreignKey([fc.pointingFrom.name],
                          references: fc.pointingToRemoteTable,
                          [fc.pointingTo.name],
                          onDelete: fc.onDelete,
                          onUpdate: fc.onUpdate,
                          named: nil)
    }
}
