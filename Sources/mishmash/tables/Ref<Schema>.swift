import SQLKit

/// maybe use some sort of private flag or way to try to enforce early to users
/// that we should control how 'Ref' types are delivered to try to buffer most of the heavy stuff
///
/// This class is used to project schema as real objects and interact with them in a way that
/// is typesafe, and allows more flexibility in terms of database behavior
///
@dynamicMemberLookup
final class Ref<S: Schema> {
    /// a simple backing for now, could maybe be a protocol or sth faster than json
    fileprivate(set) var backing: [String: JSON] {
        didSet { isDirty = true }
    }

    /// whether or not the reference has changed since it came from the database
    fileprivate(set) var isDirty: Bool = false
    /// whether or not the reference has been stored at some point in the database
    /// ~ not fully tested or clean/secure ~
    fileprivate(set) var exists: Bool = false

    /// the database that contains the table for a given schema
    let db: SQLDatabase

    /// init with the raw backing materials, and a database connection
    init(_ raw: [String: JSON], _ database: SQLDatabase) {
        self.backing = raw
        self.db = database
    }

    /// this is a new object, restrict this creation
    convenience init(_ database: SQLDatabase) {
        self.init([:], database)
    }

    /// this is a new object, restrict this creation
    convenience init(_ database: SeeQuel) {
        self.init([:], database.db)
    }

    // MARK: SubscriptOverloads

    subscript<Value: Codable>(dynamicMember key: KeyPath<S, Column<Value>>) -> Value {
        get {
            let column = S.template[keyPath: key]
            let json = backing[column.name] ?? .null
            return try! Value(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            backing[column.name] = newValue.json
        }
    }

    subscript<Value: Codable>(dynamicMember key: KeyPath<S, Unique<Value>>) -> Value {
        get {
            let column = S.template[keyPath: key]
            let json = backing[column.name] ?? .null
            return try! Value(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            backing[column.name] = newValue.json
        }
    }

    subscript<PK: Codable>(dynamicMember key: KeyPath<S, PrimaryKey<PK>>) -> PK? {
        get {
            let pk = S.template[keyPath: key]
            guard let value = backing[pk.name] else { return nil }
            return try! PK(json: value)
        }
        set {
            let pk = S.template[keyPath: key]
            backing[pk.name] = newValue.json
        }
    }

    // MARK: Relations

    ///
    /// for now, the only relations supported are one-to-one where the link MUST be optional
    /// for one to many relations, it MUST not be optional, and will instead return empty arrays
    ///
    subscript<ForeignTable: Schema>(dynamicMember key: KeyPath<S, ForeignKey<ForeignTable>>) -> Ref<ForeignTable>? {
        get {
            let referencingKey = S.template[keyPath: key]
            guard let referencingValue = backing[referencingKey.name]?.string else { return nil }
            return db.load(id: referencingValue)
        }
        set {
            let relation = S.template[keyPath: key]
            let pointingTo = relation.pointingTo

            guard let foreigner = newValue else {
                self.backing[relation.name] = nil
                return
            }

            guard let foreignIdValue = foreigner.backing[pointingTo.name] else {
                /// would be great if we could attach to the 'Ref' object and somehow trigger an update later after saving
                /// maybe queue things into the database
                fatalError("object: \(foreigner) not ready to be linked.. missing: \(pointingTo.name)")
            }

            // the caller is the referencing body
            // the foreignColumn may or may not be also
            // referencing back in some way
            self.backing[relation.name] = foreignIdValue
        }
    }

    /// a one to many situation, read only
    /// if multiple tables declare a foreign key for our current caller
    /// then the caller can aggregate those values
    ///
    /// the relations tests help with the confusion
    ///
    subscript<Many: Schema>(dynamicMember key: KeyPath<S, ToMany<Many>>) -> [Ref<Many>] {
        let relation = S.template[keyPath: key]
        let pointingTo = relation.pointingTo
        let pointingFrom = relation.pointingFrom
        let id = self.backing[pointingTo.name]
        return db.getAll(where: pointingFrom.name, matches: id)
    }

    /// a one to one relationship where a single object from another table
    /// is referencing to this one
    subscript<One: Schema>(dynamicMember key: KeyPath<S, ToOne<One>>) -> Ref<One>? {
        // we are parent, seeking detached children
        let relation = S.template[keyPath: key]
        let pointingTo = relation.pointingTo
        let pointingFrom = relation.pointingFrom


        guard let id = self.backing[pointingTo.name] else {
            /// we don't have the value that's being pointed to, can't have a child pointing back
            return nil
        }
//        let id = self.backing[pointingTo.name]
        return db.getOne(where: pointingFrom.name, matches: id)
    }

    // MARK: Pivots
    subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> [Ref<R>] {
        get {
            // we're not using the pivot object, could contain some meta info
            // for now, this works
            let pivotColumn = S.template._pivotIdKey
            let myPrimary = S.template._primaryKey
            let id = backing[myPrimary.name]

            /// not very optimized fetching one at a time
            let pivots: [Ref<PivotSchema<S, R>>] = db.getAll(where: pivotColumn, matches: id)
            return pivots.map(\.right).compactMap { r in
                guard let r = r else {
                    Log.warn("unexpected nil on pivot, set cascade?")
                    return nil
                }
                return r
            }
        }
        set {
            /// not efficient, and not handling cascades and stuff
            newValue.forEach { incoming in
                let pivot = PivotSchema<S, R>.on(db)
                pivot.left = self
                pivot.right = incoming
                try! pivot.save()
            }
        }
    }
}

extension Ref {
    func _unsafe_setBacking(column: BaseColumn, value: JSON?) {
        backing[column.name] = value
    }
}

import SQLiteKit
import Foundation

/// should this be here?
extension Ref {
    @discardableResult
    func save() throws -> Self {
        if self.exists { try update() }
        else { try _save() }
        
        isDirty = false
        exists = true
        return self
    }

    private  func _save() throws {
        /// if object doesn't exist
        let idKey = S.template.primaryKey
        let needsId = idKey != nil && self.backing[idKey!.name] == nil
        if needsId, let id = idKey {
            switch id.kind {
            case .uuid:
                /// uuid not auto generated, needs to be made
                Log.info("allow a more general string type for like email")
                Log.info("this one should be PrimaryKey<UUID>")
                self.backing[id.name] = UUID().json
            case .int:
                Log.warn("in multi groups, autoincrement fails..")
                // set automatically after save by sql
            }
        }

        guard !self.backing.isEmpty else { return }
        try db.insert(into: S.table)
            .model(self.backing)
            .run()
            .wait()

        guard
            needsId,
            let pk = idKey,
            pk.kind == .int
            else { return }
        let id = unsafe_lastInsertedRowId()
        self.backing[pk.name] = id.json
    }

    func update() throws {
        let primary = S.template._primaryKey
        try self.db.update(S.table)
            .where(primary.name.sqlid, .equal, backing[primary.name])
            .set(model: backing)
            .run()
            .wait()
    }

    private func unsafe_lastInsertedRowId() -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try! self.db.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .wait()
        return id
    }
}

extension String {
    fileprivate var sqlid: SQLIdentifier { .init(self) }
}
