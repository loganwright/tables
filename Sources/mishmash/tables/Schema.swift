// MARK: Schema

protocol Schema {
    init()
    static var table: String { get }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased()}
}

protocol TableBindings: Schema {
    
}

// MARK:

extension Schema {
    /// load the template for a given schema type
    /// loading this way also ensures that labels are set
    /// according to swift properties
    static var template: Self {
        if let existing = _templates[table] as? Self { return existing }
        let new = Self.init()
        /// populates the names of the columns with introspected values
        /// maybe a better way, but for now is helpful
        let _ = _unsafe_force_hydrate_columns_on(new)
        _templates[table] = new
        return new
    }

    static var _type_erased_template: Schema {
        guard let type_erased = _templates[table] else { fatalError("template not yet created") }
        return type_erased
    }
}

extension Schema {
    /// SQLColumn and ComositeCollection
    var _allColumns: [Any] {
        _unsafe_force_hydrate_columns_on(self)
    }

    /// these discourage bad things and are confusing, organize when time
    var sqlColumns: [SQLColumn] {
        _allColumns.compactMap { $0 as? SQLColumn }
    }

    /// compositeColumn or constraintGroup
    var compositeColumns: [CompositeColumn] {
        _allColumns.compactMap { $0 as? CompositeColumn }
    }

    var _relations: [Relation] {
        _unsafe_force_Load_properties_on(self)
            .compactMap { $0.val as? Relation }
    }
}

extension CompositeKeys {
    /// SQLColumn and ComositeCollection
    var _allColumns: [Any] {
        _unsafe_force_hydrate_columns_on(self)
    }

    /// these discourage bad things and are confusing, organize when time
    var sqlColumns: [SQLColumn] {
        _allColumns.compactMap { $0 as? SQLColumn }
    }

    /// compositeColumn or constraintGroup
    var compositeColumns: [CompositeColumn] {
        _allColumns.compactMap { $0 as? CompositeColumn }
    }

    var _relations: [Relation] {
        _unsafe_force_Load_properties_on(self)
            .compactMap { $0.val as? Relation }
    }
}

/// storing this in any way kills everything, I can't explain why, everything is identical, but it's subtle
/// load all introspectable properties from an instance
///
/// ok, I was thinking about it.. when the nested key declares a key path of it's container
/// `let friend = ForeignKey<Self>(\.id)`
/// and if there's anything in the column creators, it seems to choke, idk, in that case, declare a key
///
/// that was when it was nested tho
///
func _unsafe_force_Load_properties_on(_ subject: Any) -> [Property] {
    Mirror(reflecting: subject).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        return Property(child.label!, child.value)
    }
}

/// should this use a base 'Column' protocol? it's nice having them separate at the moment
func _unsafe_force_hydrate_columns_on(_ subject: Any) -> [Any] {
    let properties = _unsafe_force_Load_properties_on(subject)
    return properties.compactMap { prop in
        switch prop.val {
        /// standard persisted column
        case let column as SQLColumn:
            if column.name.isEmpty { column.name = prop.label }
            return column
        /// standard reulation, not a column, but ok
        case _ as Relation:
            return nil
        /// not a column, but sort of, special considerations
        case let composite as CompositeColumn:
            return composite
        default:
            Log.warn("incompatible schema property: \(type(of: subject)).\(prop.label): \(prop.columntype)")
            Log.info("expected \(SQLColumn.self), ie: \(Column<String>.self)")
            return nil
        }
    }
}

// MARK: PrimaryKeys

extension Schema {
    /// whether the schema contains a primary key
    /// one can name their primary key as they'd like, this is
    /// a generic name that will extract
    var primaryKey: PrimaryKeyBase? {
        sqlColumns.lazy.compactMap { $0 as? PrimaryKeyBase } .first
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

// MARK: SchemaMaps

/// templates help us to use instances of a schema as opposed to trying
/// to infer information from it's more opaque type metadata
/// this caches nicely
private var _templates: [String: Schema] = [:]
/// it's not sooo important, but caching maybe will help performance
/// the amount of data isn't so much to add to memory
/// but introspection processes are expensive
private var _properties: [String: [Property]] = [:]
private var _columns: [String: [SQLColumn]] = [:]
private var _relations: [String: [Relation]] = [:]

// MARK: Introspection

/// a model of mirror reflected properties
struct Property {
    let label: String
    let columntype: Any.Type
    let val: Any

    init(_ label: String, _ val: Any) {
        self.label = label
        let t = Swift.type(of: val)
        self.columntype = t
        self.val = val
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
        case uuid, int

        var sqltype: SQLDataType {
            switch self {
            case .uuid: return .text
            case .int: return .int
            }
        }

        fileprivate var constraint: SQLColumnConstraintAlgorithm {
            let auto: Bool
            switch self {
            case .uuid:
                auto = false
            case .int:
                auto = true
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
struct PrimaryKeyed {
    func asdf() {
//        SQLiteData
    }
//    var key([SQLD])
}

//protocol
//@propertyWrapper
//class Unique<

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

//@propertyWrapper
//class _Column<Value>: SQLColumn

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
        return Ref(db)
    }

    @discardableResult
    static func on(_ db: SQLDatabase, creator: (Ref<Self>) throws -> Void) throws -> Ref<Self> {
        let new = Ref<Self>(db)
        try creator(new)
        try new.save()
        return new
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
