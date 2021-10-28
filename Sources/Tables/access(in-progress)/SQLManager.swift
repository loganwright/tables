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
    
    var db: SQLDatabase { self.connection.sql() }
    
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
    
    func destroyDatabase() async throws {
        try await db.unsafe_fatal_dropAllTables()
    }
}

// MARK: CRUD

extension String {
    fileprivate var sqlid: SQLIdentifier { .init(self) }
}

extension SQLDatabase {
    func _loadFirst<E: Encodable>(from table: String,
                                  where key: String,
                                  equals compare: E,
                                  limitingColumnsTo columns: [String] = ["*"]) async throws -> [String: JSON]? {
        try await self.select()
            .columns(columns)
            .where(key.sqlid, .equal, compare)
            .from(table)
            .first(decoding: [String: JSON].self)
            .commit()
    }
    
    /// get all objects in table
    func _loadAll(from table: String,
                  limitingColumnsTo columns: [String] = ["*"]) async throws -> [[String: JSON]] {
        try await self.select()
            .columns(columns)
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    
    func _loadAll<E: Encodable>(from table: String,
                                where key: String,
                                equals compare: E,
                                limitingColumnsTo columns: [String] = ["*"]) async throws -> [[String: JSON]] {
        try await self.select()
            .columns(columns)
            .where(key.sqlid, .equal, compare)
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    /// get all objects matching a list of ids
    func _loadAll(from table: String,
                  where key: String,
                  `in` pass: [String],
                  limitingColumnsTo columns: [String] = ["*"]) async throws -> [[String: JSON]] {
        try await self.select()
            .columns(columns)
            .where(key.sqlid, .in, pass)
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    /// get all objects where value stored at 'key' contains value
    func _loadAll(from table: String,
                  where key: String,
                  contains value: String,
                  limitingColumnsTo columns: [String] = ["*"]) async throws -> [[String: JSON]] {
        try await self.select()
            .columns(columns)
            .where(key.sqlid, .like, "%\(value)%")
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    /// create in database, will throw if already exists
    func _create(in table: String, _ contents: JSON) async throws {
        try await self.insert(into: table)
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
        try await self.update(table)
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
        try await self.delete(from: table)
            .where("id", .equal, id)
            .run()
            .commit()
    }
    
    /// remove all objects in a table, maintain schema
    func _deleteAll(from table: String) async throws {
        try await self.delete(from: table)
            .run()
            .commit()
    }
    
    /// delete all objects that match the given ids
    func _deleteAll(from table: String, matchingIds ids: [String]) async throws {
        try await self.delete(from: table)
            .where("id", .in, ids)
            .run()
            .commit()
    }
    
    // MARK: SQL Interactors
    
    func unsafe_getAllTables() async throws -> [String] {
        try await self.select()
            .column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .commit()
            .map(\.name)
    }
    
    func unsafe_tableExists(_ table: String) async throws -> Bool {
        // "SELECT * FROM sqlite_master WHERE name ='myTable' and type='table';"
        try await self.select().column("name")
            .from("sqlite_master")
            .where("name", .equal, table)
            .where("type", .equal, "table")
            .all()
            .commit()
            .count == 1
    }
    
    func unsafe_dropTable(_ table: String) async throws {
        let disable = SQLRawExecute("PRAGMA foreign_keys = OFF;\n")
        let enable = SQLRawExecute("PRAGMA foreign_keys = ON;\n")
        
        try await self.execute(sql: disable) { row in
            Log.warn("disabling foreign key checks: \(row)")
        } .commit()
        
        try await self.drop(table: table).run()
            .commit()
        
        try await self.execute(sql: enable) { row in
            Log.info("ENABLED foreign key checks: \(row)")
        } .commit()
    }
    
    // MARK: FATAL
    
    func unsafe_fatal_deleteAllEntries() async throws {
        Log.warn("fatal process deleting all entries")
        try await unsafe_getAllTables().asyncForEach(_deleteAll)
    }
    
    func unsafe_fatal_dropAllTables() async throws {
        Log.warn("fatal process deleting tables")
        /// idk how to just delete all at once, maybe delete file?
        let tables = try await unsafe_getAllTables()
        try await tables.asyncForEach(unsafe_dropTable)
    }
}

extension String {
    var _sqlid: SQLIdentifier { .init(self) }
}

struct TableColumnMeta: Codable {
    // column_id
    let cid: Int
    let name: String
    let type: String
    let notnull: Bool
    let dflt_value: JSON?
    let pk: Bool
}

private struct Table: Decodable {
    let name: String
}

extension SQLDatabase {
    func unsafe_table_meta(_ table: String) async throws -> [TableColumnMeta] {
        var meta = [TableColumnMeta]()
        let tableInfo = SQLRawExecute("pragma table_info(\(table));\n")
        try await execute(sql: tableInfo) { (row) in
            let next = try! row.decode(model: TableColumnMeta.self)
            meta.append(next)
        } .commit()
        return meta
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
