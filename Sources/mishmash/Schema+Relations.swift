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
//    var pointingToPath: PartialKeyPath<Foreign>
    /// in this case, we are referring to the current column
    var pointingFrom: SQLColumn { self }

    override var wrappedValue: Foreign? { replacedDynamically() }
    private var onDelete: SQLForeignKeyAction?
    private var onUpdate: SQLForeignKeyAction?

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

// TODO: make a proper way to add to table constraints
///
extension ForeignKey: PostCreateConstraints {
    /// this is a hack because simply adding the column foreign key constraint doesn't work
    /// we can fix it, but it still then breaks if there's two because serialization needs to happen
    /// AFTER the table is done
    func add(to builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        return builder.foreignKey([pointingFrom.name],
                                  references: SQLRawExecute(Foreign.table).raw,
                                  [pointingTo.name],
                                  onDelete: onDelete,
                                  onUpdate: onUpdate,
                                  named: nil)
    }
}

/// hacky just trying to work around problem for now
protocol PostCreateConstraints {
    func add(to builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder
}

// MARK: EphemeralColumns (Not Persisted)

protocol Relation {}

//protocol BaseRelation: Relation {
//    var pointingTo: PrimaryKeyBase { get }
//    var pointingFrom: SQLColumn { get }
//}

//protocol : Relation {
//    var left: PrimaryKeyBase
//    var right: PrimaryKeyBase
//}

/**
 Use this type to attach to many references that are pointing at an object
 */
@propertyWrapper
class ToMany<Many: Schema>: Relation {
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
class ToOne<One: Schema>: Relation {
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


// MARK: Pivots

/// the underlying schema for storing the pivot
struct PivotSchema<Left: Schema, Right: Schema>: Schema {
    static var table: String {
        [Left.table, Right.table].sorted().joined(separator: "_")
    }

    var left: ForeignKey<Left>
    var right: ForeignKey<Right>

    init() {
        let lpk = \Left._primaryKey
        let rpk = \Right._primaryKey
        let ln = Left.template._pivotIdKey
        let rn = Right.template._pivotIdKey
        self.left = ForeignKey(ln, pointingTo: lpk)
        self.right = ForeignKey(rn, pointingTo: rpk)
    }
}

extension Schema {
    var _pivotIdKey: String {
        Self.table + "_" + _primaryKey.name
    }
}

class Projection<S> {
}

@propertyWrapper
class Pivot<Left: Schema, Right: Schema>: Relation {
    var wrappedValue: [Ref<Right>] { replacedDynamically() }
    var projectedValue: Projection<Pivot<Left, Right>> { return .init() }

    @Later var lk: PrimaryKeyBase
    @Later var rk: PrimaryKeyBase

    init() {
        /// this is maybe easier for now, upper version is easier to move to support unique keys
        self._lk = Later { Left.template._primaryKey }
        self._rk = Later { Right.template._primaryKey }
    }
}

extension Pivot {
    var schema: PivotSchema<Left, Right>.Type { PivotSchema<Left, Right>.self }
}

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

    static func fetch<S: Schema>(where path: KeyPath<S, SQLColumn>, equals: String) {

    }
}

extension SQLColumn {
    var _sqlIdentifier: SQLIdentifier { .init(name) }
}

extension Ref {
    var _db: SQLDatabase { db as! SQLDatabase }

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
        try self._db.delete(from: schema.table)
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

//    Student.fet
}

/// there's a lot of initialization and intermixing, sometimes lazy loading helps with cycles
/// and is good in preparation for more async support
@propertyWrapper
final class Later<T> {
    var wrappedValue: T {
        loader()
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
