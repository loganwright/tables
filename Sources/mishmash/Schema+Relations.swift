import SQLKit

/**
 A general person way to reference other objects from the databasek,
 the inverse of foreign key would be ToOne or ToMany depending on whether
 multiple objects declare the key


 foreign keys can also go two ways where, two objects both have references to the other
 */
@propertyWrapper
class ForeignKey<Foreign: Schema>: Column<Foreign?> {

    @Later var foreignIdKey: PrimaryKeyBase
    @Later var foreignIdKeyPath: PartialKeyPath<Foreign>

    var referencingKey: String { name }

    override var wrappedValue: Foreign? { replacedDynamically() }

    init(_ name: String = "",
         linking foreign: KeyPath<Foreign, PrimaryKey<Int>>,
         onDelete: SQLForeignKeyAction? = nil,
         onUpdate: SQLForeignKeyAction? = nil) {

        self._foreignIdKeyPath = Later { foreign }
        self._foreignIdKey = Later { Foreign.template[keyPath: foreign] }
        super.init(name, Int.sqltype, Later([]))

        loadConstraints(onDelete: onDelete, onUpdate: onUpdate)
    }

    init(_ name: String = "",
         linking foreign: KeyPath<Foreign, PrimaryKey<String>>,
         onDelete: SQLForeignKeyAction? = nil,
         onUpdate: SQLForeignKeyAction? = nil) {

        self._foreignIdKeyPath = Later { foreign }
        self._foreignIdKey = Later { Foreign.template[keyPath: foreign] }
        super.init(name, String.sqltype, Later([]))
        self.loadConstraints(onDelete: onDelete, onUpdate: onUpdate)
    }

    /// just offloading some behavior to prevent
    /// infinite loops when schema cross reference
    /// only really used during preparations anyways
    private func loadConstraints(onDelete: SQLForeignKeyAction?,
        onUpdate: SQLForeignKeyAction?) {
        self.$constraints.loader = { [weak self] in
            guard let welf = self else { fatalError() }
            let foreignKey = welf.foreignIdKey
            let defaults: [SQLColumnConstraintAlgorithm] = [
                .inlineForeignKey(name: welf.referencingKey),
                .references(Foreign.table,
                            foreignKey.name,
                            onDelete: onDelete,
                            onUpdate: onUpdate)
            ]
            return defaults
        }
    }
}

/**
 Use this type to attach to many references that are pointing at an object
 */
@propertyWrapper
class ToMany<Many: Schema>: Column<[Many]> {
    override var wrappedValue: [Many] { replacedDynamically() }

    @Later var foreignIdKey: PrimaryKeyBase
    @Later var foreignIdKeyPath: AnyKeyPath

    /// the key that is referencing something else, like game_id would be referencing the 'id' of 'game'
    @Later var referencingKey: String
    @Later var referencingKeyPath: PartialKeyPath<Many>

    init<OuterSchema: Schema>(_ key: String = "", linkedBy linkingKeyPath: KeyPath<Many, ForeignKey<OuterSchema>>) {
        self._foreignIdKey = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.foreignIdKey
        }

        self._foreignIdKeyPath = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.foreignIdKeyPath
        }

        self._referencingKey = Later {
            let column = Many.template[keyPath: linkingKeyPath]
            return column.referencingKey
        }

        self._referencingKeyPath = Later { linkingKeyPath }

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

    /// let idToFilterBy = foreign
    @Later var foreignIdKey: PrimaryKeyBase
    @Later var foreignIdKeyPath: AnyKeyPath

    /// referencing out
    @Later var referencingIdKey: String
    @Later var referencingIdKeyPath: PartialKeyPath<One>

    init<Foreign: Schema>(
        _ key: String = "",
        linkedBy reference: KeyPath<One, ForeignKey<Foreign>>) {
        self._foreignIdKey = Later {
            let parent = One.template[keyPath: reference]
            return parent.foreignIdKey
        }

        self._foreignIdKeyPath = Later {
            let parent = One.template[keyPath: reference]
            return parent.foreignIdKeyPath
        }

        self._referencingIdKey = Later {
            let parent = One.template[keyPath: reference]
            return parent.referencingKey
        }

        self._referencingIdKeyPath = Later { reference }

        super.init(key, .text, Later([]))
        /// hacky way  to keep it out of stuff
        shouldSerialize = false
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
