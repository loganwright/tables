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

extension Schema {
    /// whether the schema contains a primary key
    /// one can name their primary key as they'd like, this is
    /// a generic name that will extract
    ///
    /// currently composite primary keys will need to be worked around
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

///
extension Schema {
    static func on(_ db: SQLDatabase) -> Ref<Self> {
        Log.warn("unsafe constructor")
        return Ref(db)
    }

    @discardableResult
    static func on(_ db: SQLDatabase, creator: (Ref<Self>) throws -> Void) throws -> Ref<Self> {
        let new = Ref<Self>(db)
        try creator(new)
        try new.save()
        return new
    }

    static func make<C: BaseColumn>(on db: SQLDatabase,
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

    static func make<C: BaseColumn>(on db: SQLDatabase,
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
    var db: SQLDatabase {
        let db = self.connection._sql()
        return SQLLoggingDatabase(db)
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
