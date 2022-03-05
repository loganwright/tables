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
    
    public func destroyDatabase() throws {
        try  db.unsafe_fatal_dropAllTables()
    }
}

// MARK: CRUD

extension SQLDatabase {
    @TablesActor
    func __loadFirst<E: Encodable>(from table: String,
                                  where key: String,
                                  equals compare: E,
                                  limitingColumnsTo columns: [String] = ["*"]) throws -> [String: JSON]? {
        try self.select()
            .columns(columns)
            .where(key._sqlid, .equal, compare)
            .from(table)
            .first(decoding: [String: JSON].self)
            .wait()
    }
    
    func _loadFirst<E: Encodable>(from table: String,
                                  where key: String,
                                  equals compare: E,
                                  limitingColumnsTo columns: [String] = ["*"]) throws -> [String: JSON]? {
        try self.select()
            .columns(columns)
            .where(key._sqlid, .equal, compare)
            .from(table)
            .first(decoding: [String: JSON].self)
            .wait()
    }
    
    /// get all objects in table
    func _loadAll(from table: String,
                  limitingColumnsTo columns: [String] = ["*"]) throws -> [[String: JSON]] {
        try self.select()
            .columns(columns)
            .from(table)
            .all(decoding: [String: JSON].self)
            .wait()
    }
    
    
    func _loadAll<E: Encodable>(from table: String,
                                where key: String,
                                equals compare: E,
                                limitingColumnsTo columns: [String] = ["*"]) throws -> [[String: JSON]] {
        try self.select()
            .columns(columns)
            .where(key._sqlid, .equal, compare)
            .from(table)
            .all(decoding: [String: JSON].self)
            .wait()
    }
    
    /// get all objects matching a list of ids
    func _loadAll<E: Encodable>(from table: String,
                                where key: String,
                                `in` compare: [E],
                                limitingColumnsTo columns: [String] = ["*"]) throws -> [[String: JSON]] {
        try self.select()
            .columns(columns)
            .where(key._sqlid, .in, compare)
            .from(table)
            .all(decoding: [String: JSON].self)
            .wait()
    }
    
    /// get all objects where value stored at 'key' contains value
    func _loadAll(from table: String,
                                where key: String,
                                contains value: String,
                                limitingColumnsTo columns: [String] = ["*"]) throws -> [[String: JSON]] {
        try self.select()
            .columns(columns)
            .where(key._sqlid, .like, "%\(value)%")
            .from(table)
            .all(decoding: [String: JSON].self)
            .wait()
    }
    
    /// create in database, will throw if already exists
    func _create(in table: String, _ contents: [String: JSON]) throws {
        try self.insert(into: table)
            .model(contents)
            .run()
            .wait()
    }
    
    /// create in database, throws on existing
    func _create(in table: String, _ obs: [[String: JSON]]) throws {
        /// lazy for now, more optimized ways buggy, no time
        try obs.forEach { try _create(in: table, $0) }
    }
    
    /// update in database, if exists, otherwise no writes
    func _update<E: Encodable>(in table: String,
                               where key: String,
                               matches compare: E,
                               _ json: [String: JSON]) throws {
        try self.update(table)
            .where(key._sqlid, .equal, compare)
            .set(model: json)
            .run()
            .wait()
    }
    
    /// update in database, if exists, otherwise no writes
    func _update(in table: String,
                 where key: String,
                 matches kp: KeyPath<Dictionary<String, JSON>, JSON?>,
                 _ obs: [[String: JSON]]) throws {
        /// lazy for now, more optimized ways buggy, no time
        try obs.forEach {
            try _update(
                in: table,
                where: key,
                matches: $0[keyPath: kp],
                $0
            )
            
        }
    }
    
    /// remove individual object
    func _deleteAll<E: Encodable>(from table: String, where key: String, matches compare: E) throws {
        try self.delete(from: table)
            .where(key._sqlid, .equal, compare)
            .run()
            .wait()
    }
    
    /// remove all objects in a table, maintain schema
    func _deleteAll(from table: String) throws {
        try self.delete(from: table)
            .run()
            .wait()
    }
    
    /// delete all objects that match the given ids
    func _deleteAll(from table: String, where key: String, `in` group: [String]) throws {
        try self.delete(from: table)
            .where(key._sqlid, .in, group)
            .run()
            .wait()
    }
    
    // MARK: SQL Interactors
    
    public func unsafe_getAllTables() throws -> [String] {
        try self.select()
            .column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .wait()
            .map(\.name)
    }
    
    public func unsafe_tableExists(_ table: String) throws -> Bool {
        // "SELECT * FROM sqlite_master WHERE name ='myTable' and type='table';"
        try self.select()
            .column("name")
            .from("sqlite_master")
            .where("name", .equal, table)
            .where("type", .equal, "table")
            .first()
            .wait() != nil
    }
    
    public func unsafe_dropTable(_ table: String) throws {
        let disable = SQLRawExecute("PRAGMA foreign_keys = OFF;\n")
        let enable = SQLRawExecute("PRAGMA foreign_keys = ON;\n")
        
        try self.execute(sql: disable) { row in
            Log.info("DISABLED foreign key checks: \(row)")
        } .wait()
        
        try self.drop(table: table).run()
            .wait()
        
        try self.execute(sql: enable) { row in
            Log.info("ENABLED foreign key checks: \(row)")
        } .wait()
    }
    
    // MARK: FATAL
    
    public func unsafe_fatal_deleteAllEntries() throws {
        Log.warn("fatal process deleting all entries")
        try unsafe_getAllTables().forEach(_deleteAll)
    }
    
    public func unsafe_fatal_dropAllTables() throws {
        Log.warn("fatal process deleting tables")
        /// idk how to just delete all at once, maybe delete file?
        let tables = try unsafe_getAllTables()
        try tables.forEach(unsafe_dropTable)
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
    public func unsafe_table_meta(_ table: String) throws -> [TableColumnMeta] {
        var meta = [TableColumnMeta]()
        let tableInfo = SQLRawExecute("pragma table_info(\(table));\n")
        try execute(sql: tableInfo) { (row) in
            let next = try! row.decode(model: TableColumnMeta.self)
            meta.append(next)
        } .wait()
        return meta
    }
}


//extension JSON {
//    fileprivate var sqlDataType: SQLDataType {
//        switch self {
//        case .int:
//            return .int
//        case .double:
//            return .real
//        case .string:
//            return .text
//        case .bool:
//            return .int
//        case .object:
//            return .text
//        case .array:
//            return .text
//        case .null:
//            fatalError("unable to infer type from null json")
//        }
//    }
//}

//extension EventLoopFuture {
////    @TablesActor
////    func wait(timeout: DispatchTime = .distantFuture) throws -> Value {
////        self.wa
////        var result: Result<Value, Error> = .failure("result never set")
////        let group = DispatchGroup()
////        group.enter()
////        whenComplete {
////            result = $0
////            group.leave()
////        }
////        let dispatch = group.wait(timeout: timeout)
////        guard dispatch == .success else {
////            throw "event loop future operation timed out"
////        }
////        return try result.get()
////    }
//
//    func commit() throws -> Value { try wait() }
////    func commit() async throws -> Value {
////        try await withCheckedThrowingContinuation { continuation in
////            self.whenComplete(continuation.resume)
////        }
////    }
//}

/// an empty actor used to synchronize tables interaction
@globalActor
public struct TablesActor {
    public actor ActorType {}
    public static var shared: ActorType = ActorType()
}

public struct TablesOperation {
    /// initial interaction to enter tables context 
    public func `async`(_ operation: @TablesActor @escaping () throws -> Void) {
        Task {
            try await operation()
        }
    }
}

public let tables = TablesOperation()
