import Logging
import SQLiteKit
import Foundation

/// default sql directory
private var sql_directory: URL {
    let url = FileManager.default
        .documentsDir
        .appendingPathComponent("sqlite", isDirectory: true)
    try! FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil)
    return url.appendingPathComponent("database.sqlite", isDirectory: false)
}

/// interact w sql database
final class SQLManager {
    static var shared: SQLManager = .default
    
    static let inMemory = SQLManager(storage: .memory)
    static let `default` = SQLManager(storage: .file(path: sql_directory.path))

    var db: SQLDatabase {
        self.connection.sql()
    }

    private let eventLoopGroup: EventLoopGroup
    private let threadPool: NIOThreadPool
    let connection: SQLiteConnection

    init(storage: SQLiteConfiguration.Storage) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.threadPool = NIOThreadPool(numberOfThreads: 1)
        self.threadPool.start()

        self.connection = try! SQLiteConnectionSource(
            configuration: .init(storage: storage, enableForeignKeys: true),
            threadPool: self.threadPool
        ).makeConnection(
            logger: .init(label: "sql-manager"),
            on: self.eventLoopGroup.next()
        ).wait()
    }

    // MARK: CRUD

    /// get object by id
    func _get(from table: String,
              matchingId id: String,
              limitingColumnsTo columns: [String] = ["*"]) async throws -> JSON? {
        try await self.db.select()
            .columns(columns)
            .where("id", .equal, id)
            .from(table)
            .first(decoding: JSON.self)
            .commit()
    }

    /// get all objects in table
    func _getAll(from table: String,
                 limitingColumnsTo columns: [String] = ["*"]) async throws -> [JSON] {
        try await self.db.select()
            .columns(columns)
            .from(table)
            .all(decoding: JSON.self)
            .commit()
    }

    /// get all objects matching a list of ids
    func _getAll(from table: String,
                 matchingIds ids: [String],
                 limitingColumnsTo columns: [String] = ["*"]) async throws -> [JSON] {
        try await self.db.select()
            .columns(columns)
            .where("id", .in, ids)
            .from(table)
            .all(decoding: JSON.self)
            .commit()
    }

    /// get all objects where value stored at 'key' contains value
    func _getAll(from table: String,
                 whereKey key: String,
                 contains value: String,
                 limitingColumnsTo columns: [String] = ["*"]) async throws -> [JSON] {
        try await self.db.select()
            .columns(columns)
            .where(SQLIdentifier(key), .like, "%\(value)%")
            .from(table)
            .all(decoding: JSON.self)
            .commit()
    }

    /// create in database, will throw if already exists
    func _create(in table: String, _ contents: JSON) async throws {
        try await self.db.insert(into: table)
            .model(contents)
            .run()
            .commit()
    }

    /// create in database, throws on existing
    func _create(in table: String, _ obs: [JSON]) async throws {
        /// lazy for now, more optimized ways buggy, no time
        try await obs.asyncForEach { try await _create(in: table, $0) }
    }

    /// update in database, if exists, otherwise no writes
    func _update(in table: String, _ json: JSON) async throws {
        try await self.db
            .update(table)
            .where("id", .equal, json._id)
            .set(model: json)
            .run()
            .commit()
    }

    /// update in database, if exists, otherwise no writes
    func _update(in table: String, _ obs: [JSON]) async throws {
        /// lazy for now, more optimized ways buggy, no time
        try await obs.asyncForEach { try await _update(in: table, $0) }
    }

    /// remove individual object
    func _delete(from table: String, matchingId id: String) async throws {
        try await self.db.delete(from: table)
            .where("id", .equal, id)
            .run()
            .commit()
    }

    /// remove all objects in a table, maintain schema
    func _deleteAll(from table: String) async throws {
        try await self.db.delete(from: table)
            .run()
            .commit()
    }

    /// delete all objects that match the given ids
    func _deleteAll(from table: String, matchingIds ids: [String]) async throws {
        try await self.db.delete(from: table)
            .where("id", .in, ids)
            .run()
            .commit()
    }

    // MARK: SQL Interactors

    func unsafe_getAllTables() async throws -> [String] {
        struct Table: Decodable {
            let name: String
        }
        let results = try await db.select().column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .commit()
        return results.map(\.name)
    }

    func unsafe_tableExists(_ table: String) async throws -> Bool {
        // "SELECT * FROM sqlite_master WHERE name ='myTable' and type='table';"
        let results = try await db.select().column("name")
            .from("sqlite_master")
            .where("name", .equal, table)
            .where("type", .equal, "table")
            .all()
            .commit()
        return results.count == 1
    }

    func unsafe_dropTable(_ table: String) async throws {
        let disable = SQLRawExecute("PRAGMA foreign_keys = OFF;\n")
        let enable = SQLRawExecute("PRAGMA foreign_keys = ON;\n")
        try await self.db.execute(sql: disable) { row in
            Log.warn("disabling foreign key checks: \(row)")
        }.commit()
        try await self.db.drop(table: table).run().commit()
        try await self.db.execute(sql: enable) { row in
            Log.info("ENABLED foreign key checks: \(row)")
        } .commit()
    }

    // MARK: FATAL

    func unsafe_fatal_deleteAllEntries() async throws {
        Log.warn("fatal process deleting all entries")
//        try unsafe_getAllTables().forEach(_deleteAll)
        let tables = try await unsafe_getAllTables()
        try await tables.asyncForEach(_deleteAll)
    }

    func unsafe_fatal_dropAllTables() async throws {
        Log.warn("fatal process deleting tables")
        /// idk how to just delete all at once
//        try await unsafe_getAllTables().forEach(unsafe_dropTable)
        let tables = try await unsafe_getAllTables()
        try await tables.asyncForEach(unsafe_dropTable)
    }
}

extension JSON {
    fileprivate var sqlDataType: SQLDataType {
        switch self {
        case .int:
            return .int
        case .double:
            return .real
        case .str:
            return .text
        case .bool:
            return .int
        case .obj:
            return .text
        case .array:
            return .text
        case .null:
            fatalError("unable to infer type from null json")
        }
    }
}

extension EventLoopFuture {
    func commit() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            self.whenComplete(continuation.resume)
        }
    }
}
