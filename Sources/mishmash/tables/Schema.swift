// MARK: Schema

protocol Schema {
    init()
    static var table: String { get }
    var tableConstraints: TableConstraints { get }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased()}
    var tableConstraints: TableConstraints { TableConstraints { } }
}

// MARK: PrimaryKeys

extension PrimaryKeyBase {
    var toBaseType: PrimaryKeyBase {
        return self
    }
}

extension KeyPath where Value: PrimaryKeyBase {
    var toBaseType: KeyPath<Root, PrimaryKeyBase> {
        appending(path: \.toBaseType)
    }
}

extension Schema {
    /// whether the schema contains a primary key
    /// one can name their primary key as they'd like, this is
    /// a generic name that will extract
    var primaryKey: PrimaryKeyBase? {
        let all = columns.compactMap { $0 as? PrimaryKeyBase }
        assert(0...1 ~= all.count,
               "multiple primary keys not currently supported as property")
        return all.first
    }

    /// whether a schema is primary keyed
    /// all relations require a schema to be primary keyed
    var isPrimaryKeyed: Bool {
        primaryKey != nil
    }

    /// this is a forced key that will assert that will fail if a schema has not declared
    /// a primary key
    /// currently only one primary key is supported
    var _primaryKey: PrimaryKeyBase {
        let pk = primaryKey
        assert(pk != nil, "no primary key found: \(Schema.self)")
        return pk!
    }

    var primaryKeyGroup: Any? {
        fatalError()
    }
}

import SQLKit

protocol DatabaseValue {
    static var sqltype: SQLDataType { get }
}

extension String: DatabaseValue {
    static var sqltype: SQLDataType { return .text }
}

extension Int: DatabaseValue {
    static var sqltype: SQLDataType { .int }
}

extension Data: DatabaseValue {
    static var sqltype: SQLDataType { .blob }
}

protocol OptionalProtocol {
    associatedtype Wrapped
}
extension Optional: OptionalProtocol {}


func replacedDynamically() -> Never { fatalError() }


protocol PrimaryKeyValue: DatabaseValue {}
extension String: PrimaryKeyValue {}
extension Int: PrimaryKeyValue {}


@propertyWrapper
class Unique<Value: DatabaseValue>: Column<Value> {
    override var wrappedValue: Value { replacedDynamically() }
    init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        super.init(key, Value.sqltype, Later([.notNull, .unique] + constraints))
    }
}

class PrimaryKeyBase: SQLColumn {
    enum Kind: Equatable {
        /// combining multiple keys not supported
        case uuid, int, composite([Kind])

        var sqltype: SQLDataType {
            switch self {
            case .uuid: return .text
            case .int: return .int
            case .composite:
                fatalError("composite requires special handling")
            }
        }

        fileprivate var constraint: SQLColumnConstraintAlgorithm {
            let auto: Bool
            switch self {
            case .uuid:
                auto = false
            case .int:
                auto = true
            case .composite:
                fatalError("auto requires special case")
            }
            return .primaryKey(autoIncrement: auto)
        }
    }

    // MARK: Attributes
    let kind: Kind

    init(_ key: String = "", _ kind: Kind) {
        self.kind = kind
        super.init(key, kind.sqltype, Later([kind.constraint]))
    }
}

import SQLiteKit
@propertyWrapper
class PrimaryKey<RawType: PrimaryKeyValue>: PrimaryKeyBase {
    var wrappedValue: RawType? { replacedDynamically() }

    init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == String {
        super.init(key, .uuid)
    }

    init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == Int {
        super.init(key, .int)
    }
}

// MARK: Column

@propertyWrapper
class Column<Value>: SQLColumn {
    open var wrappedValue: Value { replacedDynamically() }
}

extension Column where Value: DatabaseValue {
    convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.sqltype, Later(constraints + [.notNull]))
    }
}

extension Column where Value: OptionalProtocol, Value.Wrapped: DatabaseValue {
    convenience init(_ key: String = "", _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.Wrapped.sqltype, Later(constraints))
    }
}

// MARK: One to One
///
/// maybe just a restricted pivot somehow with dual primary key
///


import Logging
import SQLiteKit
import Foundation

private var seequel_directory: URL {
    let url = FileManager.default
        .documentsDir
        .appendingPathComponent("sqlite", isDirectory: true)
    try! FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil)
    return url.appendingPathComponent("database.sqlite", isDirectory: false)
}

//// TEMPORARY ShOEHORN
extension SQLiteDatabase {
    func _sql() -> _SQLiteSQLDatabase {
        _SQLiteSQLDatabase(database: self)
    }
}

struct _SQLiteSQLDatabase: SQLDatabase {
    let database: SQLiteDatabase

    var eventLoop: EventLoop {
        return self.database.eventLoop
    }

    var logger: Logger {
        return self.database.logger
    }

    var dialect: SQLDialect {
        SQLiteDialect()
    }

    func execute(
        sql query: SQLExpression,
        _ onRow: @escaping (SQLRow) -> ()
    ) -> EventLoopFuture<Void> {
        var serializer = SQLSerializer(database: self)
        query.serialize(to: &serializer)
        let binds: [SQLiteData]
        do {
            binds = try serializer.binds.map { encodable in
                return try SQLiteDataEncoder().encode(encodable)
            }
        } catch {
            return self.eventLoop.makeFailedFuture(error)
        }
        return self.database.query(
            serializer.sql,
            binds,
            logger: self.logger
        ) { row in
            onRow(row)
        }
    }
}
/////
extension Schema {
    static func on(_ db: SQLDatabase) -> Ref<Self> {
        Log.warn("should use constructor")
        return Ref(db)
    }

    @discardableResult
    static func on(_ db: SQLDatabase, creator: (Ref<Self>) throws -> Void) throws -> Ref<Self> {
        let new = Ref<Self>(db)
        try creator(new)
        try new.save()
        return new
    }

    static func make<C: SQLColumn>(on db: SQLDatabase,
                                   columns: KeyPath<Self, C>...,
                                   rows: [[Any]]) throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try rows.map { row in
            try Self.on(db) { new in
                try zip(columns, row).forEach { k, v in
                    let column = template[keyPath: k]
                    let js = try JSON(fuzzy: v)
                    new._unsafe_setBacking(column: column, value: js)

                }
            }
        }
    }

    static func make<C: SQLColumn>(on db: SQLDatabase,
                                   with columns: KeyPath<Self, C>...,
                                   and rows: [[JSON]]) throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try rows.map { row in
            try Self.on(db) { new in
                zip(columns, row).forEach { k, v in
                    let column = template[keyPath: k]
                    new._unsafe_setBacking(column: column, value: v)

                }
            }
        }
    }
}

final class SeeQuel {
    static let shared: SeeQuel = SeeQuel(storage: .memory) // SeeQuel(storage: .file(path: seequel_directory.path))

//    private var db: SQLDatabase = TestDatabase()
    var db: SQLWrappedLogging<_SQLiteSQLDatabase> {
        let db = self.connection._sql()
        return SQLWrappedLogging(db)
    }

    private let eventLoopGroup: EventLoopGroup
    private let threadPool: NIOThreadPool
    private let connection: SQLiteConnection

    init(storage: SQLiteConfiguration.Storage) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 2)
        self.threadPool = NIOThreadPool(numberOfThreads: 2)
        self.threadPool.start()

        self.connection = try! SQLiteConnectionSource(
            configuration: .init(storage: storage, enableForeignKeys: true),
            threadPool: self.threadPool
        ).makeConnection(
            logger: .init(label: "sql-manager"),
            on: self.eventLoopGroup.next()
        ).wait()
    }

    deinit {
        let connect = self.connection
        guard !connect.isClosed else { return }
        let _ = connect.close()
    }

    func _getAll(from table: String,
                 limitingColumnsTo columns: [String] = ["*"]) throws -> [JSON] {
        try self.db.select()
            .columns(columns)
            .from(table)
            .all(decoding: JSON.self)
            .wait()
    }
}

struct SQLRawExecute: SQLExpression {
    let raw: String
    init(_ raw: String) {
        self.raw = raw
    }

    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write(raw)
    }
}


private struct SQLTableSchema: SQLExpression {
    let table: String

    public init(_ table: String) {
        self.table = table
    }

    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write("pragma table_info(\(table));")
    }
}

protocol Database {
    func save(to table: String, _ body: [String: JSON])

    func save<S>(_ ref: Ref<S>) throws
    func load<S>(id: String) -> Ref<S>?
    func load<S>(ids: [String]) -> [Ref<S>]

//    func prepare(_ table: Table) throws
//    func prepare(_ tables: [Table]) throws

    func getOne<S: Schema, T: Encodable>(where key: String, matches: T) -> Ref<S>?
    func getAll<S: Schema, T: Encodable>(where key: String, matches: T) -> [Ref<S>]
//    func getAll<S: Schema, T: Encodable>(where key: String, containedIn: [T]) -> [Ref<S>]

//    func delete<T>(where key: String, contains: T)
}

extension Database {
    func save<S>(_ refs: [Ref<S>]) throws {
        try refs.forEach(save)
    }

//    func prepare(_ tables: [Table]) {
//        do {
//            try tables.forEach(prepare)
//        } catch {
//            Log.error("table prepare failed: \(error)")
//        }
//    }
//}
//
//extension Database {
//    func prepare(@TableBuilder _ builder: () -> [Table]) throws {
//        let tables = builder()
//        try self.prepare(tables)
//    }
}
