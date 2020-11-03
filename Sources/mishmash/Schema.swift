// MARK: Schema

protocol Schema {
    init()
    static var table: String { get }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased()}
}

// MARK:

extension Schema {
    /// load the template for a given schema type
    /// loading this way also ensures that labels are set
    /// according to swift properties
    static var template: Self {
        if self is Team {
            print("found team: \(Team.self)")
        }
        if let existing = _templates[table] as? Self { return existing }
        let new = Self.init()
        /// populates the names of the columns with introspected values
        /// maybe a better way, but for now is helpful
        let columns = new._unsafe_forceColumns()
        _templates[table] = new
        if self is Team {
            print("loaded team: \(Team.self): \(columns)")
            print("")
        }
        return new
    }

    static var _type_erased_template: Schema {
        guard let type_erased = _templates[table] else { fatalError("template not yet created") }
        return type_erased
    }
}

extension Schema {
    var columns: [SQLColumn] {
        _unsafe_forceColumns()
    }

    var relations: [Relation] {
        _unsafe_forceProperties().compactMap {
            $0.val as? Relation
        }
    }
}

extension Schema {
    func _unsafe_forceColumns() -> [SQLColumn] {
        _unsafe_forceProperties().compactMap { prop in
            guard let column = prop.val as? SQLColumn else {
                if prop.val is Relation { return nil }
                Log.warn("incompatible schema property: \(Self.self).\(prop.label): \(prop.columntype)")
                Log.info("expected \(SQLColumn.self), ie: \(Column<String>.self)")
                return nil
            }

            if column.name.isEmpty { column.name = prop.label }
            return column
        }
    }

    /// storing this in any way kills everything, I can't explain why, everything is identical, but it's subtle
    /// load all introspectable properties from an instance
    func _unsafe_forceProperties() -> [Property] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label else { fatalError("expected a label for template property") }
            return Property(label, child.value)
        }
    }
}

// MARK: PrimaryKeys

extension Schema {
    /// whether the schema contains a primary key
    /// one can name their primary key as they'd like, this is
    /// a generic name that will extract
    var primaryKey: PrimaryKeyBase? {
        columns.lazy.compactMap { $0 as? PrimaryKeyBase } .first
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

protocol OptionalProtocol {
    associatedtype Wrapped
}
extension Optional: OptionalProtocol {}


func replacedDynamically() -> Never { fatalError() }


protocol PrimaryKeyValue: DatabaseValue {}
extension String: PrimaryKeyValue {}
extension Int: PrimaryKeyValue {}


protocol UniqueKeyValue: DatabaseValue {}

class UniqueKey<T: Hashable>: Column<T> {
    init(_ key: String = "", _ keyType: SQLDataType, _ constraints: [SQLColumnConstraintAlgorithm]) {
        super.init(key, keyType, Later([.notNull, .unique] + constraints))
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


// MARK: Relationships

extension SQLColumnConstraintAlgorithm {
    /// working around inline foreign key support
    static func inlineForeignKey(name: String) -> SQLColumnConstraintAlgorithm {
        return .custom(SQLRawExecute(", FOREIGN KEY (\"\(name)\")"))
    }
}


/**
 parentIdKey
 * parentIdValue
 childAssociatedIdKey
 * childAssociatedValue
 */




final class Box<T> {
    var boxed: T

    init(_ boxed: T) {
        self.boxed = boxed
    }
}


@_functionBuilder
struct TableBuilder {
    static func buildBlock(_ tables: Table...) -> [Table] {
        return tables
    }

    static func buildBlock(_ schema: Schema.Type...) -> [Table] {
        schema.map { Table($0) }
    }
}

@_functionBuilder
struct ListBuilder<T> {
    static func buildBlock(_ list: T...) -> [T] {
        return list
    }
}


struct Table {
    let name: String
    let columns: [SQLColumn]

    init(_ name: String, _ columns: [SQLColumn]) {
        self.name = name
        self.columns = columns
    }

    init(_ name: String, @ListBuilder<SQLColumn> _ builder: () -> [SQLColumn]) {
        let columns = builder()
        self.init(name, columns)
    }

    init(_ schema: Schema.Type) {
        /// ideally, all schema instances would use 'template' but here we need
        /// to set again
//        let template = schema._type_erased_template
        let columns = schema.init().columns
        print("columns: \(columns.map(\.name))")
        columns.validate()
        self.init(schema.table, columns)
    }
}

extension Array where Element: SQLColumn {
    func validate() {
        assert(map(\.name).first(where: \.isEmpty) == nil)
    }
}

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

final class SeeQuel {
    static let shared: SeeQuel = SeeQuel(storage: .memory) // SeeQuel(storage: .file(path: seequel_directory.path))

//    private var db: SQLDatabase = TestDatabase()
    var db: SQLDatabase {
        self.connection.sql()
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

    func save<S>(_ ref: Ref<S>)
    func load<S>(id: String) -> Ref<S>?
    func load<S>(ids: [String]) -> [Ref<S>]

    func prepare(_ table: Table) throws
    func prepare(_ tables: [Table]) throws

    func getOne<S: Schema, T: Encodable>(where key: String, matches: T) -> Ref<S>?
    func getAll<S: Schema, T: Encodable>(where key: String, matches: T) -> [Ref<S>]
//    func getAll<S: Schema, T: Encodable>(where key: String, containedIn: [T]) -> [Ref<S>]

//    func delete<T>(where key: String, contains: T)
}

extension Database {
    func save<S>(_ refs: [Ref<S>]) {
        refs.forEach(save)
    }

    func prepare(_ tables: [Table]) {
        do {
            try tables.forEach(prepare)
        } catch {
            Log.error("table prepare failed: \(error)")
        }
    }
}

extension Database {
    func prepare(@TableBuilder _ builder: () -> [Table]) throws {
        let tables = builder()
        try self.prepare(tables)
    }
}
