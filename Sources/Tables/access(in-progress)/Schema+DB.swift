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
    public static func on(_ db: SQLDatabase) -> Ref<Self> {
        Log.warn("unsafe constructor")
        return Ref(db)
    }

    @discardableResult
    public static func on(_ db: SQLDatabase, creator: (Ref<Self>) throws -> Void) throws -> Ref<Self> {
        let new = Ref<Self>(db)
        try creator(new)
        try new.save()
        return new
    }

    public static func make<C: BaseColumn>(on db: SQLDatabase,
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
                 limitingColumnsTo columns: [String] = ["*"]) async throws -> [JSON] {
        try await self.db.select()
            .columns(columns)
            .from(table)
            .all(decoding: JSON.self)
            .commit()
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
    func save(to table: String, _ body: [String: JSON]) async throws
    func save<S>(_ ref: Ref<S>) async throws
    func load<S>(id: String) async throws -> Ref<S>?
    func load<S>(ids: [String]) async throws -> [Ref<S>]
    func getOne<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> Ref<S>?
    func getAll<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> [Ref<S>]
}

extension Database {
    func save<S>(_ refs: [Ref<S>]) async throws {
        for ref in refs {
            try await save(ref)
        }
    }
}
