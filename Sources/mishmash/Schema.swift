// MARK: Schema

protocol Schema {
    init()
    static var table: String { get }
}

protocol Foojijij {
    var id: PrimaryKeyBase { get }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased()}
}

// MARK:  

extension Schema {
    var primaryKey: PrimaryKeyBase? {
        columns.lazy.compactMap { $0 as? PrimaryKeyBase } .first
    }
    var isPrimaryKeyed: Bool {
        primaryKey != nil
    }
}

extension Ref {
    var primaryKey: PrimaryKeyBase? {
        S.template.primaryKey
    }
    var isPrimaryKeyed: Bool {
        S.template.isPrimaryKeyed
    }
}

// MARK: Template

/// templates help us to use instances of a schema as opposed to trying
/// to infer information from it's more opaque type metadata
/// this caches nicely
private var templates: [String: Schema] = [:]

extension Schema {
    /// load the template for a given schema type
    /// loading this way also ensures that labels are set
    /// according to swift properties
    static var template: Self {
        if let existing = templates[table] as? Self { return existing }
        let new = Self.make()
        templates[table] = new
        return new
    }

    /// constructs a new schema to be used if necessary
    /// calling `template` is usually enough as we should rarely be directly accessing
    /// schema
    static func make() -> Self {
        let new = Self.init()
        new.hydrateColumnKeysWithPropertyLabels()
        return new
    }
}

// MARK: Introspection

/// a model of mirror reflected properties
struct SchemaProperty {
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

extension Schema {
    var columns: [SQLColumn] {
        allColumns.filter(\.shouldSerialize)
    }

    var allColumns: [SQLColumn] {
        unsafe_getColumns()
    }

    /// load all introspectable properties from an instance
    func unsafe_getProperties() -> [SchemaProperty] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label else { fatalError("expected a label for template property") }
            return SchemaProperty(label, child.value)
        }
    }

    /// load all sqlcolumns associated with this schema
    func unsafe_getColumns() -> [SQLColumn] {
        unsafe_getProperties().compactMap { prop in
            guard let column = prop.val as? SQLColumn else {
                Log.warn("incompatible schema property: \(Self.self).\(prop.label): \(prop.columntype)")
                Log.info("expected \(SQLColumn.self), ie: \(Column<String>.self)")
                return nil
            }

            if column.name.isEmpty { column.name = prop.label }
            return column
        }
    }

    /// we need to fill in the templating columns, for example
    ///
    ///  `let note = Column<String>()`
    ///
    ///     if not properly hydrated, the column will have an empty string as a key
    ///
    private func hydrateColumnKeysWithPropertyLabels() {
        let props = unsafe_getProperties()

        props.forEach { prop in
            guard let column = prop.val as? SQLColumn else {
                Log.warn("unexpected property on schema: \(Self.self).\(prop.label)")
                return
            }
            guard column.name.isEmpty else { return }
            column.name = prop.label
        }
    }
}

import SQLKit

extension SQLTableConstraintAlgorithm {

}
extension SQLColumnConstraintAlgorithm {
//    var validInSQLite: Bool {
//
//    }
}

class SQLColumn {
    /// can't decide on naming, going back and forth :/
    var key: String {
        get { name }
        set { name = newValue }
    }

    open var name: String
    open var type: SQLDataType

    /// using the Later attribute to allow nested columns to properly initialize
    @Later open var constraints: [SQLColumnConstraintAlgorithm]

    open var shouldSerialize = true

    init(_ name: String, _ type: SQLDataType, _ constraints: Later<[SQLColumnConstraintAlgorithm]>) {
        self.name = name
        self.type = type
        self._constraints = constraints
    }

    convenience init(_ name: String, _ type: SQLDataType, _ constraints: [SQLColumnConstraintAlgorithm]) {
        self.init(name, type, Later(constraints))
    }

    convenience init(_ name: String, _ type: SQLDataType, _ constraints: SQLColumnConstraintAlgorithm...) {
        self.init(name, type, Later(constraints))
    }
}

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
        case uuid, incrementing

        fileprivate var sqltype: SQLDataType {
            switch self {
            case .uuid: return .text
            case .incrementing: return .int
            }
        }

        fileprivate var constraint: SQLColumnConstraintAlgorithm {
            let auto: Bool
            switch self {
            case .uuid:
                auto = false
            case .incrementing:
                auto = true
            }
            return .primaryKey(autoIncrement: auto)
        }
    }

    // MARK: Attributes
    let pk: Kind

    fileprivate init(_ key: String, _ kind: Kind) {
        self.pk = kind
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
        super.init(key, .incrementing)
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
        schema.map(Table.init)
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
        let columns = schema.init().unsafe_getColumns().filter(\.shouldSerialize)
        self.init(schema.table, columns)
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
