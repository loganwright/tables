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
public final class SQLManager {
    public static var shared: SQLManager = .default
    
    public static let inMemory = SQLManager(storage: .memory)
    public static let `default` = SQLManager(storage: .file(path: sql_directory.path))
    
    public var db: SQLDatabase { self.connection.sql() }
    
    private let eventLoopGroup: EventLoopGroup
    private let threadPool: NIOThreadPool
    let connection: SQLiteConnection
    
    public init(storage: SQLiteConfiguration.Storage) {
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
    
    public func destroyDatabase() async throws {
        try await db.unsafe_fatal_dropAllTables()
    }
}

// MARK: CRUD

extension SQLDatabase {
    func _loadFirst<E: Encodable>(from table: String,
                                  where key: String,
                                  equals compare: E,
                                  limitingColumnsTo columns: [String] = ["*"]) async throws -> [String: JSON]? {
        try await self.select()
            .columns(columns)
            .where(key._sqlid, .equal, compare)
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
            .where(key._sqlid, .equal, compare)
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    /// get all objects matching a list of ids
    func _loadAll<E: Encodable>(from table: String,
                                where key: String,
                                `in` compare: [E],
                                limitingColumnsTo columns: [String] = ["*"]) async throws -> [[String: JSON]] {
        try await self.select()
            .columns(columns)
            .where(key._sqlid, .in, compare)
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
            .where(key._sqlid, .like, "%\(value)%")
            .from(table)
            .all(decoding: [String: JSON].self)
            .commit()
    }
    
    /// create in database, will throw if already exists
    func _create(in table: String, _ contents: [String: JSON]) async throws {
        try await self.insert(into: table)
            .model(contents)
            .run()
            .commit()
    }
    
    /// create in database, throws on existing
    func _create(in table: String, _ obs: [[String: JSON]]) async throws {
        /// lazy for now, more optimized ways buggy, no time
        try await obs.asyncForEach { try await _create(in: table, $0) }
    }
    
    /// update in database, if exists, otherwise no writes
    func _update<E: Encodable>(in table: String,
                               where key: String,
                               matches compare: E,
                               _ json: [String: JSON]) async throws {
        try await self.update(table)
            .where(key._sqlid, .equal, compare)
            .set(model: json)
            .run()
            .commit()
    }
    
    /// update in database, if exists, otherwise no writes
    func _update(in table: String,
                 where key: String,
                 matches kp: KeyPath<Dictionary<String, JSON>, JSON?>,
                 _ obs: [[String: JSON]]) async throws {
        /// lazy for now, more optimized ways buggy, no time
        try await obs.asyncForEach {
            try await _update(
                in: table,
                where: key,
                matches: $0[keyPath: kp],
                $0
            )
            
        }
    }
    
    /// remove individual object
    func _deleteAll<E: Encodable>(from table: String, where key: String, matches compare: E) async throws {
        try await self.delete(from: table)
            .where(key._sqlid, .equal, compare)
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
    func _deleteAll(from table: String, where key: String, `in` group: [String]) async throws {
        try await self.delete(from: table)
            .where(key._sqlid, .in, group)
            .run()
            .commit()
    }
    
    // MARK: SQL Interactors
    
    public func unsafe_getAllTables() async throws -> [String] {
        try await self.select()
            .column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            
            .all(decoding: Table.self)
            .commit()
            .map(\.name)
    }
    
    public func unsafe_tableExists(_ table: String) async throws -> Bool {
        // "SELECT * FROM sqlite_master WHERE name ='myTable' and type='table';"
        try await self.select().column("name")
            .from("sqlite_master")
            .where("name", .equal, table)
            .where("type", .equal, "table")
            .all()
            .commit()
            .count == 1
    }
    
    public func unsafe_dropTable(_ table: String) async throws {
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
    
    public func unsafe_fatal_deleteAllEntries() async throws {
        Log.warn("fatal process deleting all entries")
        try await unsafe_getAllTables().asyncForEach(_deleteAll)
    }
    
    public func unsafe_fatal_dropAllTables() async throws {
        Log.warn("fatal process deleting tables")
        /// idk how to just delete all at once, maybe delete file?
        let tables = try await unsafe_getAllTables()
        try await tables.asyncForEach(unsafe_dropTable)
    }
}

extension String {
    var _sqlid: SQLIdentifier { .init(self) }
}

public struct TableColumnMeta: Codable {
    // column_id
    public let cid: Int
    public let name: String
    public let type: String
    public let notnull: Bool
    public let dflt_value: JSON?
    public let pk: Bool
}

private struct Table: Decodable {
    let name: String
}

extension SQLDatabase {
    public func unsafe_table_meta(_ table: String) async throws -> [TableColumnMeta] {
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
        case .string:
            return .text
        case .bool:
            return .int
        case .object:
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
