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

extension FileManager {
    var documentsDir: URL {
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
    }
}

typealias Block = () -> Void
typealias ThrowingBlock = () throws -> Void

extension SQLManager {
    final class Operation<T> {
        private var hasCommited: Bool = false

        fileprivate(set) var _operation: () throws -> T = { fatalError() }
        fileprivate(set) var _onError: (Error) -> Void = { error in Log.error(error) }
        fileprivate(set) var _onComplete: ((T) -> Void)? = nil

        unowned private let sql: SQLManager

        fileprivate init(on sql: SQLManager, op: @escaping () throws -> T) {
            self.sql = sql
            self._operation = { [unowned self] in
                /// could lock this further so that this is only place that can set it
                self.sql.isOpen = true
                defer { self.sql.isOpen = false }
                return try op()
            }
        }

        deinit {
            if !hasCommited { Log.warn("operation deallocated before commiting") }
        }

        @discardableResult
        func onError(_ error: @escaping (Error) -> Void) -> Self {
            _onError = DispatchQueue.main.wrap(error)
            return self
        }

        @discardableResult
        func onComplete(_ complete: @escaping (T) -> Void) -> Self {
            _onComplete = DispatchQueue.main.wrap(complete)
            return self
        }

        func commit() {
            hasCommited = true
            sql.queue.run {
                do {
                    let result = try self._operation()
                    self._onComplete?(result)
                } catch {
                    self._onError(error)
                }
            }
        }

        /// would be nice if compiler could rethrow based on operation initialized with
        /// could maybe do w/ subclassing? like ThrowingOperation maybe
        func commitSynchronously() -> T {
            try! commitSynchronouslyThrowing()
        }

        func commitSynchronouslyThrowing() throws -> T {
            hasCommited = true
            assert(_onComplete == nil, "synchronous commits will not run completion block")
            guard !sql.isOpen else { throw "sql is already open, nested synchronous operations will fail" }

            let syncError = "sync-failed"
            var result = Result<T, Error>.failure(syncError)
            let group = DispatchGroup()
            group.enter()
            sql.queue.run {
                print("running queue")
                do {
                    let val = try self._operation()
                    result = .success(val)
                } catch {
                    result = .failure(error)
                }

                group.leave()
            }
            group.wait()

            let err = result.error ?? "ok"
            guard "\(err)" != syncError else { fatalError("sychronizing failed") }

            switch result {
            case .success(let val):
                return val
            case .failure(let err):
                throw err
            }
        }
    }

    fileprivate final class Queue {
        private let operations = OperationQueue()

        init() {
            operations.maxConcurrentOperationCount = 1
        }

        func run(_ op: @escaping Block) {
            let op = BlockOperation(block: op)
            operations.addOperation(op)
        }
    }

    func open(_ runner: @escaping () throws -> Void) -> Operation<Void> {
        return Operation<Void>(on: self, op: runner)
    }

    func open<T>(_ runner: @escaping () throws -> T) -> Operation<T> {
        return Operation<T>(on: self, op: runner)
    }
}

extension DispatchQueue {
    fileprivate func wrap<T>(_ value: @escaping (T) -> Void) -> (T) -> Void {
        return { input in
            self.async { value(input) }
        }
    }
}

/// interact w sql database
final class SQLManager {
    fileprivate let queue = Queue()

    @ThreadSafe
    fileprivate var isOpen: Bool = false
    func _unsafe_testable_setIsOpen(_ isOpen: Bool) -> Self {
        self.isOpen = isOpen
        return self
    }

    private(set) static var shared: SQLManager = .default

    static func unsafe_overrideSharedManager(_ manager: SQLManager) {
        Log.warn("changing sqlmanager current")
        shared = manager
    }

    static let unsafe_testable = SQLManager(storage: .memory)
    private static let `default` = SQLManager(storage: .file(path: sql_directory.path))

    var testable_db: SQLDatabase {
        self.connection.sql()
    }
    private var db: SQLDatabase {
        assert(isOpen, "sql manager must be opened before accessing")
        return self.connection.sql()
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

    // MARK: CRUD

    /// get object by id
    func _get(from table: String,
              matchingId id: String,
              limitingColumnsTo columns: [String] = ["*"]) throws -> JSON? {
        try self.db.select()
            .columns(columns)
            .where("id", .equal, id)
            .from(table)
            .first(decoding: JSON.self)
            .wait()
    }

    /// get all objects in table
    func _getAll(from table: String,
                 limitingColumnsTo columns: [String] = ["*"]) throws -> [JSON] {
        try self.db.select()
            .columns(columns)
            .from(table)
            .all(decoding: JSON.self)
            .wait()
    }

    /// get all objects matching a list of ids
    func _getAll(from table: String,
                 matchingIds ids: [String],
                 limitingColumnsTo columns: [String] = ["*"]) throws -> [JSON] {
        try self.db.select()
            .columns(columns)
            .where("id", .in, ids)
            .from(table)
            .all(decoding: JSON.self)
            .wait()
    }

    /// get all objects where value stored at 'key' contains value
    func _getAll(from table: String,
                 whereKey key: String,
                 contains value: String,
                 limitingColumnsTo columns: [String] = ["*"]) throws -> [JSON] {
        return try self.db.select()
            .columns(columns)
            .where(SQLIdentifier(key), .like, "%\(value)%")
            .from(table)
            .all(decoding: JSON.self)
            .wait()
    }

    /// create in database, will throw if already exists
    func _create(in table: String, _ contents: JSON) throws {
        try self.db.insert(into: table)
            .model(contents)
            .run()
            .wait()
    }

    /// create in database, throws on existing
    func _create(in table: String, _ obs: [JSON]) throws {
        /// lazy for now, more optimized ways buggy, no time
        try obs.forEach { try _create(in: table, $0) }
    }

    /// update in database, if exists, otherwise no writes
    func _update(in table: String, _ json: JSON) throws {
        try self.db
            .update(table)
            .where("id", .equal, json._id)
            .set(model: json)
            .run()
            .wait()
    }

    /// update in database, if exists, otherwise no writes
    func _update(in table: String, _ obs: [JSON]) throws {
        /// lazy for now, more optimized ways buggy, no time
        try obs.forEach { try _update(in: table, $0) }
    }

    /// remove individual object
    func _delete(from table: String, matchingId id: String) throws {
        try self.db.delete(from: table)
            .where("id", .equal, id)
            .run()
            .wait()
    }

    /// remove all objects in a table, maintain schema
    func _deleteAll(from table: String) throws {
        try self.db.delete(from: table)
            .run()
            .wait()
    }

    /// delete all objects that match the given ids
    func _deleteAll(from table: String, matchingIds ids: [String]) throws {
        try self.db.delete(from: table)
            .where("id", .in, ids)
            .run()
            .wait()
    }

    // MARK: SQL Interactors

    func unsafe_createTable(name: String) throws {
        try self.db.create(table: name)
            .ifNotExists()
            .column("id", type: .text, .primaryKey(autoIncrement: false), .notNull)
            .run()
            .wait()
    }

    func unsafe_getAllTables() throws -> [String] {
        struct Table: Decodable {
            let name: String
        }
        let results = try db.select().column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .wait()
        return results.map(\.name)
    }

    func unsafe_tableExists(_ table: String) throws -> Bool {
        // "SELECT * FROM sqlite_master WHERE name ='myTable' and type='table';"
        let results = try db.select().column("name")
            .from("sqlite_master")
            .where("name", .equal, table)
            .where("type", .equal, "table")
            .all()
            .wait()
        return results.count == 1
    }

    func unsafe_dropTable(_ table: String) throws {
//        let disable = SQLRawExecute("SET FOREIGN_KEY_CHECKS = 0;\n")
//        let enable = SQLRawExecute("SET FOREIGN_KEY_CHECKS = 1;\n")
        let disable = SQLRawExecute("PRAGMA foreign_keys = OFF;\n")
        let enable = SQLRawExecute("PRAGMA foreign_keys = ON;\n")
        try self.db.execute(sql: disable) { row in
            Log.warn("disabling foreign key checks: \(row)")
        }.wait()
        try self.db.drop(table: table).run().wait()
        try self.db.execute(sql: enable) { row in
            Log.info("ENABLED foreign key checks: \(row)")
        } .wait()
    }

    // MARK: Preparations

    /// right now reflection requires an empty object if we mirror on the type itself
    /// it always seems to return empty, seek to avoid when possible
    func unsafe_prepareTable<Ob: Schema>(template: Ob) throws {
        try unsafe_validateTemplate(template: template)

        guard try !unsafe_tableExists(Ob.table) else {
            throw "table already exists: \(Ob.table)"
        }

        /// all objects have an id column
        let prepare = self.db.create(table: Ob.table)
            .column("id", type: .text, .primaryKey(autoIncrement: false), .notNull)

        throw "no longer doing json hack"
//        guard let obj = template.json.obj else {
//            throw "can't prepare table w non object: \(template)"
//        }

        let properties = unsafe_getProperties(template: template)
        let _ = properties
            .filter { $0.type.contains("NullEncoding<") }
            .map(\.label)
            // property wrappers serialize w leading `_`
            .map { $0.dropFirst() }
            .map(String.init)

        throw "not implemented object stuff"
//        obj.forEach { key, val in
//            /// id is special case prepared above
//            guard key != "id" else { return }
//
//            if nullableProperties.contains(key) {
//                prepare = prepare.column(key, type: val.sqlDataType)
//            } else {
//                prepare = prepare.column(key, type: val.sqlDataType, .notNull)
//            }
//        }

        try prepare.run().wait()
    }

    /// do as much front loading as possible on expectations of models to allow early detection of issues with models
    private func unsafe_validateTemplate<Ob: Schema>(template: Ob) throws {
        throw "not implemented"
//        let json = template.json.obj ?? [:]
//        guard !json.isEmpty else { throw "expected object" }
//
//        let properties = unsafe_getProperties(template: template)
//        let invalid = properties.filter { $0.type.contains("Optional<") }
//        let list = invalid.map { "\t\(Ob.self).\($0.label): \($0.type)" } .joined(separator: ",\n")
//
//        let msg = "optionals are not supported, use @NullEncoding property wrapper on:\n\(list)\n"
//        guard invalid.isEmpty else { throw msg }
//
//        let bools = properties.filter { $0.type == "\(Bool.self)" }
//        guard bools.isEmpty else { throw "boolean values not supported, use @FuzzyBool attribute" }
//
//        guard json.values.filter({ $0 == .null }).isEmpty else {
//            throw "templates must not use null values or types can not be inferred"
//        }
//        guard json.keys.count == properties.count else {
//            throw "template mapped keys don't match"
//        }
//
//        guard json.keys.contains("id") else {
//            throw "id must serialize"
//        }
    }

    private func unsafe_getProperties<S: Schema>(template: S) -> [(label: String, type: String, val: Any)] {
        Mirror(reflecting: template).children.compactMap { child in
            assert(child.label != nil, "expected a label for template property")
            guard let label = child.label else { return nil }
            return (label, "\(type(of: child.value))", child.value)
        }
    }

    // MARK: FATAL

    func unsafe_fatal_deleteAllEntries() throws {
        Log.warn("fatal process deleting all entries")
        try unsafe_getAllTables().forEach(_deleteAll)
    }

    func unsafe_fatal_dropAllTables() throws {
        Log.warn("fatal process deleting tables")
        /// idk how to just delete all at once
        try unsafe_getAllTables().forEach(unsafe_dropTable)
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
