import SQLKit
import Foundation
import SQLiteKit
/// maybe use some sort of private flag or way to try to enforce early to users
/// that we should control how 'Ref' types are delivered to try to buffer most of the heavy stuff
///
/// This class is used to project schema as real objects and interact with them in a way that
/// is typesafe, and allows more flexibility in terms of database behavior
///
@dynamicMemberLookup
public final class Ref<S: Schema> {
    /// a simple backing for now, could maybe be a protocol or sth faster than json
    public fileprivate(set) var backing: [String: JSON] {
        didSet { isDirty = true }
    }

    /// whether or not the reference has changed since it came from the database
    public fileprivate(set) var isDirty: Bool = false
    /// whether or not the reference has been stored at some point in the database
    /// ~ not fully tested or clean/secure ~
    public fileprivate(set) var exists: Bool = false

    /// the database that contains the table for a given schema
    public let db: SQLDatabase

    /// init with the raw backing materials, and a database connection
    init(_ raw: [String: JSON], _ database: SQLDatabase, exists: Bool) {
        self.backing = raw
        self.db = database
        self.exists = exists
    }

    /// this is a new object, restrict this creation
    convenience init(_ database: SQLDatabase) {
        self.init([:], database, exists: false)
    }

    deinit {
        guard !exists else { return }
        Log.warn("reference deallocated without having been saved")
    }
    
    // MARK: SubscriptOverloads

    public subscript<Value: Codable>(dynamicMember key: KeyPath<S, Column<Value>>) -> Value {
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

    public subscript<Value: Codable>(dynamicMember key: KeyPath<S, Unique<Value>>) -> Value {
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

    public subscript<PK: Codable>(dynamicMember key: KeyPath<S, PrimaryKey<PK>>) -> PK? {
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
    ///
    public subscript<ForeignTable: Schema>(dynamicMember key: KeyPath<S, ForeignKey<ForeignTable>>) -> AsyncReadSyncWritable<Ref<ForeignTable>?> {
        AsyncReadSyncWritable(
            get: {
                try await self.foreignGet(key)
            },
            set: {
                try self.foreignSet(key, to: $0)
            }
        )
    }
    
    private func foreignGet<ForeignTable: Schema>(_ key: KeyPath<S, ForeignKey<ForeignTable>>) async throws -> Ref<ForeignTable>? {
        let referencingKey = S.template[keyPath: key]
        guard let referencingValue = backing[referencingKey.name]?.string else { return nil }
        return try await ForeignTable.load(id: referencingValue, in: db)
    }
    
    private func foreignSet<ForeignTable: Schema>(_ key: KeyPath<S, ForeignKey<ForeignTable>>, to newValue: Ref<ForeignTable>?) throws {
        let relation = S.template[keyPath: key]
        let pointingTo = relation.pointingTo
        
        guard let foreigner = newValue else {
            self.backing[relation.name] = nil
            return
        }
        
        guard let foreignIdValue = foreigner.backing[pointingTo.name] else {
            /// would be great if we could attach to the 'Ref' object and somehow trigger an update later after saving
            /// maybe queue things into the database
            throw "object: \(foreigner) not ready to be linked.. missing: \(pointingTo.name)"
        }
        
        // the caller is the referencing body
        // the foreignColumn may or may not be also
        // referencing back in some way
        self.backing[relation.name] = foreignIdValue
    }

    /// a one to many situation, read only
    /// if multiple tables declare a foreign key for our current caller
    /// then the caller can aggregate those values
    ///
    /// the relations tests help with the confusion
    ///
    public subscript<Many: Schema>(dynamicMember key: KeyPath<S, ToMany<Many>>) -> [Ref<Many>] {
        get async throws {
            let relation = S.template[keyPath: key]
            let pointingTo = relation.pointingTo
            let pointingFrom = relation.pointingFrom
            let id = self.backing[pointingTo.name]
//            return try await db.loadAll(where)
//            return try await Many.loadAll(where: <#T##KeyPath<Schema, Column<Encodable>>#>, matches: <#T##Encodable#>, in: <#T##SQLDatabase#>)
            return try await self.db.loadAll(where: pointingFrom.name, matches: id)
        }
    }

    /// a one to one relationship where a single object from another table
    /// is referencing to this one
    public subscript<One: Schema>(dynamicMember key: KeyPath<S, ToOne<One>>) -> Ref<One>? {
        get async throws {
            // we are parent, seeking detached children
            let relation = S.template[keyPath: key]
            // our field that is being pointed to
            let pointingTo = relation.pointingTo
            // the foreign column in the foreign table that is tracking
            // our key
            let pointingFrom = relation.pointingFrom

            //
            guard let id = self.backing[pointingTo.name] else {
                /// we don't have the value that's being pointed to, can't have a child pointing back
                return nil
            }
            return try await db.loadFirst(where: pointingFrom.name, matches: id)
        }
    }
}

// MARK: Temporary Async Get/Set Workarounds

/// a workaround to async properties that also require setters (see subclasses)
public class AsyncReadable<T> {
    public let asyncGet: () async throws -> T
    
    public init(get: @escaping () async throws -> T) {
        self.asyncGet = get
    }
    
    public var get: T {
        get async throws {
            try await asyncGet()
        }
    }
}

/// a workaround for async/throwing read/write properties
public class AsyncReadWritable<T>: AsyncReadable<T> {
    public let asyncSet: (T) async throws -> Void
    
    public init(get: @escaping () async throws -> T, set: @escaping (T) async throws -> Void) {
        self.asyncSet = set
        super.init(get: get)
    }
    
    public func set(_ value: T) async throws {
        try await self.asyncSet(value)
    }
}

/// a workaround with async getters, and throwing setters in a property
public class AsyncReadSyncWritable<T>: AsyncReadable<T> {
    public let asyncSet: (T) throws -> Void
    
    public init(get: @escaping () async throws -> T, set: @escaping (T) throws -> Void) {
        self.asyncSet = set
        super.init(get: get)
    }
    
    public func set(_ value: T) throws {
        try self.asyncSet(value)
    }
}

extension Ref {
    func _unsafe_setBacking(column: BaseColumn, value: JSON?) {
        backing[column.name] = value
    }
}

// MARK: Save & Update

public protocol Saveable {
    @discardableResult
    func save() async throws -> Self
}

extension Array where Element: Saveable {
    @discardableResult
    public func save() async throws -> Self {
        try await asyncForEach { try await $0.save() }
        return self
    }
}

/// should this be here?
extension Ref: Saveable {
    @discardableResult
    public func save() async throws -> Self {
        if self.exists { try await _update() }
        else { try await _save() }
        
        isDirty = false
        exists = true
        return self
    }

    private func _save() async throws {
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
        try await db._create(in: S.table, self.backing)

        guard
            needsId,
            let pk = idKey,
            pk.kind == .int
            else { return }
        let id = try await unsafe_lastInsertedRowId()
        self.backing[pk.name] = id.json
    }

    private func _update() async throws {
        let primary = S.template._primaryKey
        try await self.db._update(
            in: S.table,
            where: primary.name,
            matches: backing[primary.name],
            backing
        )
    }

    private func unsafe_lastInsertedRowId() async throws -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try await self.db.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .commit()
        return id
    }
}

extension String {
    fileprivate var sqlid: SQLIdentifier { .init(self) }
}
