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
    var pointingFrom: SQLColumn { self }

    override var wrappedValue: Foreign? { replacedDynamically() }

    private var onDelete: SQLForeignKeyAction?
    private var onUpdate: SQLForeignKeyAction?

    init(_ name: String = "",
         pointingTo foreign: KeyPath<Foreign, PrimaryKey<Int>>,
         onDelete: SQLForeignKeyAction? = nil,
         onUpdate: SQLForeignKeyAction? = nil) {

        self._pointingTo = Later { Foreign.template[keyPath: foreign] }
        super.init(name, Int.sqltype, Later([]))

        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    init(_ name: String = "",
         pointingTo foreign: KeyPath<Foreign, PrimaryKey<String>>,
         onDelete: SQLForeignKeyAction? = nil,
         onUpdate: SQLForeignKeyAction? = nil) {

        self._pointingTo = Later { Foreign.template[keyPath: foreign] }
        super.init(name, String.sqltype, Later([]))

        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    init(_ name: String = "",
         pointingTo foreign: KeyPath<Foreign, PrimaryKeyBase>,
         onDelete: SQLForeignKeyAction? = nil,
         onUpdate: SQLForeignKeyAction? = nil) {

        self._pointingTo = Later { Foreign.template[keyPath: foreign] }
        super.init(name, String.sqltype, Later([]))

        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }
}

extension ForeignKey: ForeignKeySettable {
    func setForeignKeys(on builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        Log.info("fix the foreign key/referencing words, I think you (I) learned it backwards")
        return builder.foreignKey([name],
                                  references: SQLRawExecute(Foreign.table).raw,
                                  [pointingTo.name],
                                  onDelete: onDelete,
                                  onUpdate: onUpdate,
                                  named: nil)
    }
}

/// hacky just trying to work around problem for now
protocol ForeignKeySettable {
    func setForeignKeys(on builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder
}

/**
 Use this type to attach to many references that are pointing at an object
 */
@propertyWrapper
class ToMany<Many: Schema>: Column<[Many]> {
    override var wrappedValue: [Many] { replacedDynamically() }
    /// the key on the current object to which the external objects are pointing
    @Later var pointingTo: PrimaryKeyBase
    /// the column in the 'Many' table that contains the unowned id
    @Later var pointingFrom: SQLColumn
//    @Later var foreignIdKeyPath: AnyKeyPath

    /// the key that is referencing something else, like game_id would be referencing the 'id' of 'game'
    /// the column in the 'Many' table that corresponds to `OuterSchema`
//    @Later var referencingKey: String
//    @Later var referencingKeyPath: PartialKeyPath<Many>

    init<OuterSchema: Schema>(_ key: String = "", linkedBy linkingKeyPath: KeyPath<Many, ForeignKey<OuterSchema>>) {
        self._pointingTo = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.pointingTo
        }

        self._pointingFrom = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.pointingFrom
        }

//        self._foreignIdKeyPath = Later {
//            let column = Many.template[keyPath: linkingKeyPath]
//            return column.pointingToKeyPath
//        }
//
//        self._referencingKey = Later {
//            let column = Many.template[keyPath: linkingKeyPath]
//            return column.pointingTo.name
//        }

//        self._referencingKeyPath = Later { linkingKeyPath }

        /// not going to actually really store this key
        super.init(key, .text, Later([]))
        shouldSerialize = false
    }
}

/**
 for when their is a single object in another table that has declared us as a foreign key
 */
@propertyWrapper
class ToOne<One: Schema>: Column<One?> {

    override var wrappedValue: One? { replacedDynamically() }

    /// the column, on the current object, to which the foreign object points back
    /// the other column is pointing to self
    @Later var pointingTo: PrimaryKeyBase
    @Later var pointingFrom: SQLColumn

//    override var name: String { fatalError("unnamed column, not stored") }
    /// referencing out
//    @Later var referencingIdKey: String
//    @Later var referencingIdKeyPath: PartialKeyPath<One>

    init<Foreign: Schema>(
        _ key: String = "",
        linkedBy reference: KeyPath<One, ForeignKey<Foreign>>) {
        self._pointingTo = Later {
            let externalColumn = One.template[keyPath: reference]
            return externalColumn.pointingTo
        }

        self._pointingFrom = Later {
            let child = One.template[keyPath: reference]
            return child.pointingFrom
        }

//        self._referencingIdKey = Later {
//            let parent = One.template[keyPath: reference]
//            return parent.referencingKey
//        }
//
//        self._referencingIdKeyPath = Later { reference }

        super.init(key, .text, Later([]))
        /// hacky way  to keep it out of stuff
        shouldSerialize = false
    }
}



protocol KeyedSchema: Schema {
    var _id: PrimaryKeyBase { get set }
}


/**
 pivot table
 */

//struct LinkSchema<Left: KeyedSchema, Right: KeyedSchema>: Schema {
//    KeyPath<Foreign, PrimaryKey<String>>
//    var left = Foreign
//}

@propertyWrapper @dynamicMemberLookup
class Link<Left: KeyedSchema, Right: KeyedSchema>: Column<(Left, Right)>  {
    override var wrappedValue: (Left, Right) { replacedDynamically() }

    private(set) var left = ForeignKey<Left>(pointingTo: \._id)
    private(set) var right = ForeignKey<Right>(pointingTo: \._id)

    required init(_ lk: KeyPath<Left, PrimaryKey<String>>, _ rk: KeyPath<Right, PrimaryKey<String>>) {
        super.init("\(Self.self)", .custom(SQLRawExecute("")), Later([]))
        shouldSerialize = false
    }

//    init(_ name: String = "",
//         linking foreign: KeyPath<Foreign, PrimaryKey<Int>>,
//         onDelete: SQLForeignKeyAction? = nil,
//         onUpdate: SQLForeignKeyAction? = nil) {
//
//        self._foreignIdKeyPath = Later { foreign }
//        self._foreignIdColumn = Later { Foreign.template[keyPath: foreign] }
//        super.init(name, Int.sqltype, Later([]))
//
//        self.onDelete = onDelete
//        self.onUpdate = onUpdate
//    }

    subscript<T>(dynamicMember key: WritableKeyPath<ForeignKey<Left>, T>) -> T {
        get {
            left[keyPath: key]
        }
        set {
            left[keyPath: key] = newValue
        }
    }

    subscript<T>(dynamicMember key: WritableKeyPath<ForeignKey<Right>, T>) -> T {
        get {
            right[keyPath: key]
        }
        set {
            right[keyPath: key] = newValue
        }
    }
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
