import SQLKit

///
///
///relations
///some object contains a reference to the primary key or id of another object
///(in sqlite you can do it more flexibly, or like multiple keys together as unique)
///for now, just ids is probably good
///
///
///some notes for my self
///
///foreign key is the key in a table that is not owned, usually, but not always primaryKey
///could track other values, with sth like 'update', would have to be 'unique' tho, or? if it's not unique,
///it would have to be an array of all objects that contain that value
///which in those cases might be better 
///
///maybe would be good to make a distinction, like 'foreign row' as an object, referenced by
///its primary key to get the entire object
///
///and a foreign column, which is just a pointer to the contents of another row
///
///
///

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
    var pointingFrom: SQLColumn { self }
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

    private func setupTableConstraint() {
//        tableConstraints.append(
//            SQLConstraint(
//                algorithm: SQLTableConstraintAlgorithm.foreignKey(
//                    columns: columns,
//                    references: SQLForeignKey(
//                        table: foreignTable,
//                        columns: foreignColumns,
//                        onDelete: onDelete,
//                        onUpdate: onUpdate
//                    )
//                ),
//                name: constraintName
//            )
//        )
//                 builder.foreignKey([pointingFrom.name],
//                                          references: SQLRawExecute(Foreign.table).raw,
//                                          [pointingTo.name],
//                                          onDelete: onDelete,
//                                          onUpdate: onUpdate,
//                                          named: nil)
    }
}

extension Schema {
    /// generate constraints based on columns
    /// for
//    func makeConstraints() -> [SQLConstraint] {
//        columns.forEach { c in
//
//            print(c)
//        }
//    }
}


func table() {

//    c(
//        SQLConstraint(
//            algorithm: SQLTableConstraintAlgorithm.foreignKey(
//                columns: columns,
//                references: SQLForeignKey(
//                    table: foreignTable,
//                    columns: foreignColumns,
//                    onDelete: onDelete,
//                    onUpdate: onUpdate
//                )
//            ),
//            name: constraintName
//        )
//    )
//    return self
}
// TODO: make a proper way to add to table constraints
///
//extension ForeignKey: PostCreateConstraints {
//    /// this is a hack because simply adding the column foreign key constraint doesn't work
//    /// we can fix it, but it still then breaks if there's two because serialization needs to happen
//    /// AFTER the table is done
//    func add(to builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder {
////        createTable.tableConstraints.append(
////            SQLConstraint(
////                algorithm: SQLTableConstraintAlgorithm.foreignKey(
////                    columns: columns,
////                    references: SQLForeignKey(
////                        table: foreignTable,
////                        columns: foreignColumns,
////                        onDelete: onDelete,
////                        onUpdate: onUpdate
////                    )
////                ),
////                name: constraintName
////            )
////        )
//        return builder.foreignKey([pointingFrom.name],
//                                  references: SQLRawExecute(Foreign.table).raw,
//                                  [pointingTo.name],
//                                  onDelete: onDelete,
//                                  onUpdate: onUpdate,
//                                  named: nil)
//    }
//}

let alert = Alert()
struct Alert {}


class CompositePrimaryKey: PrimaryKeyBase {
    init(_ primaries: [PrimaryKeyBase]) {
        alert/
    }
}

// could maybe use forward slashes
struct Descriptor {
    let blogId: String
}
//router(get: /blog/:blogId/comment) {
//    req.blogId
//
//}
/**

 router.get { /blog/:id/comment/{}/
 */
//GET
//alert/foo/collect/:entry
//H(Accept, application/json)
postfix operator /

postfix func /(_ a: Alert) -> Never {
    fatalError()
}

/// MARK: Table Constraints
///
/// foreign keys (and in the future, composite primary keys) need to be declared at end of file
///
protocol ForeignColumnKeyConstraint {
    var pointingFrom: SQLColumn { get }
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


extension SQLCreateTableBuilder {
    /// There's a lot of subtle differences in how foreign constraints are grouped
    /// for now, it's best to assume foreign keys
    func add(compositeKey fc: CompositeKey) throws -> SQLCreateTableBuilder {
        let columns = [] as! [SQLColumn] // fc.sqlColumns
        if fc.constraint == .primary, columns.allPrimaryKeys {
            Log.warn("make composite primary key")
        } else if fc.constraint == .foreign, columns.allForeignKeys {
            Log.warn("make composite foreign keys")
            let foreignConstraints = columns._foreignConstraints
            guard foreignConstraints.validateTableMatch else {
                throw "composite foreign keys must point to the same external table"
            }

            let pointingFrom = foreignConstraints.map(\.pointingFrom).map(\.name)
            let table = foreignConstraints[0].pointingToRemoteTable
            let pointingTo = foreignConstraints.map(\.pointingTo).map(\.name)
            assert(pointingFrom.count == pointingTo.count)
            let onDelete = foreignConstraints.compactMap(\.onDelete)
            let onUpdate = foreignConstraints.compactMap(\.onUpdate)
            assert(0...1 ~= onDelete.count,
                   "multiple actions not supported on composite foreign keys")
            assert(0...1 ~= onUpdate.count,
                   "multiple actions not supported on composite foreign keys")
            // do they all have to go to same table? idk
            return self.foreignKey(pointingFrom,
                                   references: table,
                                   pointingTo,
                                   onDelete: onDelete.first,
                                   onUpdate: onUpdate.first,
                                   named: nil)
        } else if fc.constraint == .unique, !columns.allPrimaryKeys {
            let names = columns.map(\.name)
            return self.unique(names, named: nil)
        }

        throw "unexpected columns found for compositeKeys: \(columns)"
    }
}

extension Array where Element == ForeignColumnKeyConstraint {
    var validateTableMatch: Bool {
        Set(map(\.pointingToRemoteTable)).count == 1
    }
}

extension Array where Element == SQLColumn {
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

/// overkill prolly, lol
@_functionBuilder
class Preparer {
    static func buildBlock(_ schema: Schema.Type...) -> [Schema.Type] { schema }
}

extension SQLDatabase {
    func prepare(@Preparer _ build: () throws -> [Schema.Type]) throws {
        let schema = try build()
        try schema.forEach(prepare)
        Log.info("done preparing.s")
    }

    func prepare(_ schema: Schema.Type) throws {
        Log.info("preparing: \(schema.table)")

        let template = schema.init()
        var prepare = self.create(table: schema.table)
        let allColumns = template._allColumns
        prepare = try allColumns.flatMap(sqlColumns).compactMap { column in
            prepare = prepare.column(column.name,
                                     type: column.type,
                                     column.constraints)
            return column as? ForeignColumnKeyConstraint
        }
        .reduce(prepare) { prepare, constraint in
            prepare.add(foreignColumnConstraint: constraint)
        }
        .add(tableConstraints: template.tableConstraints)

        try prepare.run().wait()
    }
    /**


                            - check if collumn has group constraint, if yes, ignore that constraint
        -




     */

    /// a bit lazy at this point, will try to clean up
    private func sqlColumns(with input: Any) throws -> [SQLColumn] {
        switch input {
        case let column as SQLColumn:
            return [column]
        case let column as CompositeKey:
            fatalError()
//            return column.sqlColumns
        default:
            throw "unexpected row"
        }
    }

}


extension Array where Element: SQLColumn {
    func validate() {
        // do we need to do this? sqlite will do it
        assert(map(\.name).first(where: \.isEmpty) == nil)
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
    var pointingFrom: SQLColumn { get }
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
    @Later var pointingFrom: SQLColumn

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
    @Later var pointingFrom: SQLColumn

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

// MARK: DB Accessors (needs work)
let _db: SQLDatabase! = nil

extension Ref {
    var _id: String {
        let id = S.template._primaryKey
        return backing[id.name]!.string!
    }
}

extension SQLDatabase {
    func delete<S: Schema>(_ ref: Ref<S>) throws {
        let idColumn = S.template._primaryKey
        let idValue = ref._id
        try self.delete(from: S.table)
            .where(SQLIdentifier(idColumn.name), .equal, idValue)
            .run()
            .wait()
    }

    func fetch<S: Schema>(where column: KeyPath<S, SQLColumn>, equals value: String) throws -> Ref<S> {
        let column = S.template[keyPath: column]
        let results = try self.select()
            .columns(["*"])
            .where(column._sqlIdentifier, .equal, value)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .wait()
        fatalError()
//        return all.map { Ref($0, fatalError()) }
    }
}

extension SQLColumn {
    var _sqlIdentifier: SQLIdentifier { .init(name) }
}

extension Ref {
//    var _db: SQLDatabase { db as! SQLDatabase }

    func add<R>(to pivot: KeyPath<S, Pivot<S, R>>, _ new: [Ref<R>]) throws {
        /// not efficient, and not handling cascades and stuff
        try new.forEach { incoming in
            let pivot = PivotSchema<S, R>.on(db)
            pivot.left = self
            pivot.right = incoming
            try pivot.save()
        }
    }

    func remove<R>(from pivot: KeyPath<S, Pivot<S, R>>, _ remove: [Ref<R>]) throws {
        let pivot = S.template[keyPath: pivot]
        let schema = pivot.schema

        let pivotIdKey = R.template._pivotIdKey
        let ids = remove.map(\._id)
        try self.db.delete(from: schema.table)
            .where(SQLIdentifier(pivotIdKey), .in, ids)
            .run()
            .wait()
    }
}


func asdfsdfOO() throws {
    struct Course: Schema {
        let id = PrimaryKey<String>()
        let name = Column<String>()
        let students = Pivot<Course, Student>()
    }

    struct Student: Schema {
        let id = PrimaryKey<Int>()
        let name = Column<String>()
        let classes = Pivot<Student, Course>()
    }

    let s: Ref<Student>! = nil

    try s.add(to: \.classes, [])
    try s.remove(from: \.classes, [])
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
