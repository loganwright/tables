protocol Schema {
    init()
    static var table: String { get }
}

extension Schema {
    // special case, handled by database?
    // will crash if accessed outside of Ref
//    var id: Column<String?> { Column("id") }
    static func _primaryKeyStr() -> String? {
        primaryKey?.key
    }

    static var primaryKey: PrimaryKeyBase? {
        // todo: optimize?
        unsafe_getColumns().lazy.compactMap { $0 as? PrimaryKeyBase } .first
    }

//    static var primaryKey: _PuhrimaryKey? {
//        unsafe_getColumns().lazy.compactMap { $0 as? _PuhrimaryKey } .first
//    }
}

//protocol IDSchema: Schema {
//    associatedtype ID: IDType
//    var id: IDColumn<ID> { get set }
//}
//
//struct Plant: IDSchema {
//    var id = IDColumn<String>()
//}

//protocol SchemaID: Schema {
//    associatedtype IDType: PrimaryKey
//    var id: IDType { get }
//}

extension Schema {
    static var table: String { "\(Self.self)".lowercased() }
}

private var templates: [String: Schema] = [:]
extension Schema {
    static var template: Self {
        if let existing = templates[table] as? Self { return existing }
        let new = Self.init()
        templates[table] = new
        return new
    }
}


// MARK: Reference {
@dynamicMemberLookup
final class Ref<S: Schema> {
    /// leaving this note, don't use the backing, for schema, they should never really be instantiated outside
    /// of the template
    ///
    /// this ensures that schema are only accessed through a Ref<> object, which can then
    /// control access, retain database/connections, mark dirty, etc.
    ///    private var backing: S = .template
    ///
    ///
    /// *****************************



    /// there's maybe a better way to do this that avoids all the json conversions?
    /// maybe a protocol String -> Thing
    fileprivate(set) var backing: [String: JSON] {
        didSet { isDirty = true }
    }

    /// whether or not the reference has changed since it came from the database
    fileprivate(set) var isDirty: Bool = false

//    var exists: Bool {
//        /// TODO: we want to more or less set ids automatically?
//        raw["id"] != nil
//    }
    let db: Database

    init(_ raw: [String: JSON], _ database: Database) {
        self.backing = raw
        self.db = database
    }

    /// this is a new object, restrict this creation
    convenience init(_ database: Database) {
        self.init([:], database)
    }

    subscript<C: Codable>(dynamicMember key: KeyPath<S, Column<C>>) -> C {
        get {
            let column = S.template[keyPath: key]
            let json = backing[column.key] ?? .null
            return try! C(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            backing[column.key] = newValue.json
        }
    }

    subscript<PK: Codable>(dynamicMember key: KeyPath<S, PrimaryKey<PK>>) -> PK? {
        get {
            let pk = S.template[keyPath: key]
            guard let value = backing[pk.name] else { return nil }
            return try! PK(json: value)
        }
        set {
            let pk = S.template[keyPath: key]
            backing[pk.key] = newValue.json
        }
    }

    // MARK: Relations

    ///
    /// for now, the only relations supported are one-to-one where the link MUST be optional
    /// for one to many relations, it MUST not be optional, and will instead return empty arrays
    ///

    subscript<Link: Schema>(dynamicMember key: KeyPath<S, Column<Link?>>) -> Ref<Link>? {
        get {
            let column = S.template[keyPath: key]
            guard let foreignId = backing[column.key]?.string else { return nil }
            return db.load(id: foreignId)
        }
        set {
            /// maybe just check that it exists?
            let column = S.template[keyPath: key]
            guard let foreignKey = Link.primaryKey else { fatalError("primary key required for relations") }
            guard let new = newValue else {
                backing[column.key] = nil
                return
            }
            guard let foreignId = new.backing[foreignKey.key] else {
                /// make sure to have saved first
                fatalError("foreignKey: \(foreignKey.key) not set on: \(new)")
            }
            backing[column.key] = foreignId
        }
    }


    subscript<Link: Schema>(dynamicMember key: KeyPath<S, Column<[Link]>>) -> [Ref<Link>] {
        get {
            let column = S.template[keyPath: key]
            let ids = backing[column.key]?
                .array?
                .compactMap(\.string)
                ?? []

            fatalError()
//            return database.load(ids: ids)
        }
        set {
            // TODO: should this check if they exist? maybe just be a little fuzzy
//            let hasUnsavedItems = newValue
//                .map(\.isDirty)
//                .reduce(false, { $0 || $1 })
//            guard !hasUnsavedItems else {
//                fatalError("can not set unsaved many relations")
//            }

            let column = S.template[keyPath: key]
            guard let foreignKey = Link._primaryKeyStr() else { fatalError("primary key required for relations") }
            backing[column.key] = newValue.compactMap { $0.backing[foreignKey].json } .json
            // try to get this back to stronger keypaths, maybe w other protocol
            // backing[column.key] = newValue.map(\.id)
            fatalError()
        }
    }

//    subscript<C: Schema>(dynamicMember key: KeyPath<S, Column<[C]?>>) -> [Ref<C>]? {
//        get {
//            let column = S.template[keyPath: key]
//            guard let ids = backing[column.key]?.array?.compactMap(\.string) else {
//                return nil
//            }
//            return database.load(ids: ids)
//        }
//        set {
//            let hasUnsavedItems = newValue?
//                .map(\.isDirty)
//                .reduce(false, { $0 || $1 })
//                ?? false
//            guard !hasUnsavedItems else {
//                fatalError("can not set unsaved many relations")
//            }
//
//            let column = S.template[keyPath: key]
//            backing[column.key] = newValue?.compactMap(\.id).json
//        }
//    }

//    subscript<Many: Schema>(dynamicMember key: KeyPath<S, OneToMany<Many>>) -> [Ref<Many>] {
//        get {
//            // generalized
//            let oneToMany = S.template[keyPath: key]
////
////            let ids = raw[oneToMany.key] ?? .null
////            return try! C(json: ids)
//        }
//        set {
//            let column = S.template[keyPath: key]
//            newValue
//            raw[column.key] = newValue.json
//
//            // not saved
//            isDirty = true
//        }
//    }

//    subscript<C: ColumnProtocol>(dynamicMember key: KeyPath<S, C>) -> C.Wrapped where C.Wrapped: Schema {
//        get {
//            let column = S.template[keyPath: key]
//            let json = raw[column.key] ?? .null
//            Ref<C.Wrapped>(raw: json.obj!)
//            return try! C.Wrapped(json: json)
//        }
//        set {
//            let column = S.template[keyPath: key]
//            raw[column.key] = newValue.json
//
//            // not saved
//            dirty = true
//        }
//    }
}

@dynamicMemberLookup
final class Ref2<S: Schema> {
//    private(set)
    var raw: [String: JSON]
    private(set) var dirty: Bool = false

    /// todo: pass db stuff, or protocol, or connection?
    init(raw: [String: JSON]) {
        self.raw = raw
    }

    init(new: S) {
        fatalError()
    }

    subscript<C: Codable>(dynamicMember key: KeyPath<S, Column<C>>) -> C {
        get {
            let column = S.template[keyPath: key]
            let json = raw[column.key] ?? .null
            return try! C(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            raw[column.key] = newValue.json

            // not saved
            dirty = true
        }
    }
}

// MARK: Column

@propertyWrapper
struct _Column<C: Codable> {
    let name: String

    var isReady: Bool { return _wrappedValue != nil }

    private var _wrappedValue: C? = nil
    var wrappedValue: C {
        get {
            guard let existing = _wrappedValue else {
                fatalError("value not yet set on column")
            }
            return existing
        }
        set {
            _wrappedValue = newValue
        }
    }

    var projectedValue: Self { self }

    init(_ name: String) {
        self.name = name
        self._wrappedValue = nil
    }

//    init(_ name: String, `default`: C) {
//        self.name = name
//        self._wrappedValue = `default`
//    }

    /// required initializer
    init(wrappedValue: C?, _ name: String) {
        self.name = name
        self._wrappedValue = wrappedValue
    }
}

import SQLKit

class SQLColumn {
    let key: String
    /// I can never decide
    var name: String { key }
    let type: SQLDataType
    let constraints: [SQLColumnConstraintAlgorithm]


    /// I will maybe try to set from the introspected label, ie:
    /// `var name = Column<String()` would infer `"name"` as the key
    var unsafe_testing_inferKey: String? = nil

    init(_ key: String, _ type: SQLDataType, _ constraints: [SQLColumnConstraintAlgorithm]) {
        self.key = key
        self.type = type
        self.constraints = constraints
    }

    convenience init(_ key: String, _ type: SQLDataType, _ constraints: SQLColumnConstraintAlgorithm...) {
        self.init(key, type, constraints)
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

protocol IDType: DatabaseValue {}
extension String: IDType {}
extension Int: IDType {}

class OrigPrimaryKey: SQLColumn {
    override init(_ key: String, _ type: SQLDataType, _ constraints: [SQLColumnConstraintAlgorithm]) {
        let primary = constraints.first { const in
            switch const {
            case .primaryKey: return true
            default: return false
            }
        }
        assert(primary != nil)

        super.init(key, type, constraints)
    }
}

func replacedDynamically() -> Never { fatalError() }


protocol PrimaryKeyType {}
extension String: PrimaryKeyType {}
extension Int: PrimaryKeyType {}

class PrimaryKeyBase: SQLColumn {
    enum KeyType: Equatable {
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
    let keyType: KeyType

    fileprivate init(_ key: String, _ keyType: KeyType) {
        self.keyType = keyType
        super.init(key, keyType.sqltype, [keyType.constraint, .notNull])
    }
}

@propertyWrapper
class PrimaryKey<RawType: PrimaryKeyType>: PrimaryKeyBase {
    var wrappedValue: RawType? { replacedDynamically() }

    init(_ key: String = "id", type: RawType.Type = RawType.self) where RawType == String {
        super.init(key, .uuid)
    }

    init(_ key: String = "id", type: RawType.Type = RawType.self) where RawType == Int {
        super.init(key, .incrementing)
    }
}
/////
//class OrigPrimaryKeyBase: SQLColumn {
//    enum KeyType {
//        /// combining multiple keys not supported
//        case uuid, incrementing
//
//        fileprivate var sqltype: SQLDataType {
//            switch self {
//            case .uuid: return .text
//            case .incrementing: return .int
//            }
//        }
//
//        fileprivate var constraint: SQLColumnConstraintAlgorithm {
//            let auto: Bool
//            switch self {
//            case .uuid:
//                auto = false
//            case .incrementing:
//                auto = true
//            }
//            return .primaryKey(autoIncrement: auto)
//        }
//    }
//
//    // MARK: Attributes
//    let keyType: KeyType
//
//    fileprivate init(_ key: String, _ keyType: KeyType) {
//        self.keyType = keyType
//        super.init(key, keyType.sqltype, [keyType.constraint, .notNull])
//    }
//}
//
//@propertyWrapper
//class OrigPrimaryKey<RawType: PrimaryKeyType>: OrigPrimaryKeyBase {
//    var wrappedValue: RawType? { replacedDynamically() }
//
//    init(_ key: String = "id", type: RawType.Type = RawType.self) where RawType == String {
//        super.init(key, .uuid)
//    }
//
//    init(_ key: String = "id", type: RawType.Type = RawType.self) where RawType == Int {
//        super.init(key, .incrementing)
//    }
//}


//@propertyWrapper
//class _PrimaryKey: SQLColumn {
//    enum KeyType {
//        case uuid, incrementing
//
//        fileprivate var sqltype: SQLDataType {
//            switch self {
//            case .uuid: return .text
//            case .incrementing: return .int
//            }
//        }
//
//        fileprivate var constraint: SQLColumnConstraintAlgorithm {
//            let auto: Bool
//            switch self {
//            case .uuid:
//                auto = false
//            case .incrementing:
//                auto = true
//            }
//            return .primaryKey(autoIncrement: auto)
//        }
//    }
//
//    let keyType: KeyType
//
//    var wrappedValue: String { replacedDynamically() }
//
//    convenience init(_ key: String) {
//        self.init(key, .incrementing)
//    }
//
//    convenience init(_ keyType: KeyType) {
//        self.init("id", keyType)
//    }
//
//    init(_ key: String, _ keyType: KeyType) {
//        self.keyType = keyType
//        super.init(key, keyType.sqltype, [keyType.constraint, .notNull])
//    }
//}

//extension Schema {
//    static func _validate() throws {
//        let columns = unsafe_getColumns()
//
//        let primaries = columns.compactMap { $0 as? PrimaryKey }
//        guard primaries.count <= 1 else { throw "can only have one primary key on a schema" }
//    }
//}

/// should this stay a property wrapper?
//@propertyWrapper
//class IDColumn<C: IDType>: OrigPrimaryKey {
//    public var wrappedValue: C? { wontRun() }
//}
//
//extension IDColumn where C == String {
//    convenience init(_ key: String = "id") {
//        self.init(key,
//                  C.sqltype,
//                  [.primaryKey(autoIncrement: false), .notNull])
//    }
//}

//extension IDColumn where C == Int {
//    convenience init(_ key: String = "id") {
//        self.init(key,
//                  C.sqltype,
//                  [.primaryKey(autoIncrement: true), .notNull])
//    }
//}

/// should this stay a property wrapper?
@propertyWrapper
class Column<Value>: SQLColumn {
    open var wrappedValue: Value { replacedDynamically() }
}

extension Column where Value: DatabaseValue {
    convenience init(_ key: String, _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.sqltype, constraints + [.notNull])
    }
}

extension Column where Value: OptionalProtocol, Value.Wrapped: DatabaseValue {
    convenience init(_ key: String, _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        self.init(key, Value.Wrapped.sqltype, constraints)
    }
}

// MARK: One to One

/// for now, the only one to one is optional
extension Column where Value: OptionalProtocol, Value.Wrapped: Schema {
//    convenience init<IDType>(_ key: String,
//                             _ foreign: KeyPath<Value.Wrapped, IDColumn<IDType>>,
//                             _ constraints: [SQLColumnConstraintAlgorithm] = []) {
//        let foreignColumn = Value.Wrapped.template[keyPath: foreign]
//        let defaults: [SQLColumnConstraintAlgorithm] = [
//            .references(Value.Wrapped.table,
//                        foreignColumn.key,
//                        onDelete: .setNull,
//                        onUpdate: .cascade)
//        ]
//        self.init(key, type: IDType.sqltype, constraints: constraints + defaults)
//    }

    convenience init<PK>(_ key: String,
                         foreignKey: KeyPath<Value.Wrapped, PrimaryKey<PK>>,
                         _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        let foreignColumn = Value.Wrapped.template[keyPath: foreignKey]
        let defaults: [SQLColumnConstraintAlgorithm] = [
            .references(Value.Wrapped.table,
                        foreignColumn.key,
                        onDelete: .setNull,
                        onUpdate: .cascade)
        ]
        self.init(key, foreignColumn.keyType.sqltype, constraints + defaults)
    }
}

// MARK: One to Many

extension Column where Value: Sequence, Value.Element: Schema {
    convenience init<PK>(_ key: String,
                         containsForeignKey foreignKey: KeyPath<Value.Element, PrimaryKey<PK>>,
                         _ constraints: [SQLColumnConstraintAlgorithm] = []) {
        let foreignColumn = Value.Element.template[keyPath: foreignKey]
        let defaults: [SQLColumnConstraintAlgorithm] = [
            .references(Value.Element.table,
                        foreignColumn.key,
                        onDelete: .setNull,
                        onUpdate: .cascade)
        ]

        self.init(key,
                  /// will be an array of id's which we store as text, regardless if those are 'Int' or 'UUID'
                  .text,
                  constraints + defaults)
    }
}

extension Schema {
    static func unsafe_getColumns() -> [SQLColumn] {
        return unsafe_getProperties().compactMap { prop in
            guard let column = prop.val as? SQLColumn else {
                Log.warn("incompatible schema property: \(Self.self).\(prop.label): \(prop.type)")
                Log.info("expected \(SQLColumn.self), ie: \(Column<String>.self)")
                return nil
            }

            column.unsafe_testing_inferKey = prop.label
            return column
        }
    }

    static func unsafe_getProperties() -> [(label: String, type: String, val: Any)] {
        Mirror(reflecting: template).children.compactMap { child in
            assert(child.label != nil, "expected a label for template property")
            guard let label = child.label else { return nil }
            return (label, "\(type(of: child.value))", child.value)
        }
    }
}

//extension TypedColumn where C == Optional<DatabaseValue> {
//    convenience init(_ key: String, constraints: [SQLColumnConstraintAlgorithm] = []) {
//        self.init(key, type: C.Wrapped.sqltype, constraints: constraints)
//    }
//}

//class TypeErasedColumn {
//    let key: String
//
//    init(_ key: String) {
//        self.key = key
//    }
//}

/// should this stay a property wrapper?
//@propertyWrapper
//class Column<C>: TypeErasedColumn {
////    public var projectedValue: Column<C> { self }
//
//    public var wrappedValue: C {
//        fatalError("columns should only be accessed from within a 'Ref' object")
//    }
//}

//protocol ColumnProtocol {
//    var key: String { get }
//}
//extension Column: ColumnProtocol {}
//
//@propertyWrapper
//open class SAVEColumn<C> {
//    let key: String
//
//    var isReady: Bool { return _wrappedValue != nil }
//
//    private var _wrappedValue: C? = nil
//    public var wrappedValue: C {
//        get {
//            print("DOES THIS EVEN RUN, SHOULD IT FATAL ERROR?")
//            guard let existing = _wrappedValue else {
//                fatalError("value not yet set on column")
//            }
//            return existing
//        }
//        set {
//            print("DOES THIS EVEN RUN, SHOULD IT FATAL ERROR?")
//            _wrappedValue = newValue
//        }
//    }
//
//    public var projectedValue: SAVEColumn<C> { self }
//
//    init(_ name: String) {
//        self.key = name
//        self._wrappedValue = nil
//    }
//
////    init(_ name: String, `default`: C) {
////        self.name = name
////        self._wrappedValue = `default`
////    }
//
//    /// required initializer
//    init(wrappedValue: C?, _ name: String) {
//        self.key = name
//        self._wrappedValue = wrappedValue
//    }
//}


enum DBOperator {
    case equals
}

//extension Schema {
////    static func fetch<T>(where: KeyPath<Self, T>)
////    static func fetch(id: String) -> Ref<Self> {
////        fatalError()
////    }
//
//    static func fetch<T>(where: KeyPath<Self, Column<T>>, _ op: DBOperator, _ expectation: T) -> Ref<Self> {
//        fatalError()
//    }
//}

//@propertyWrapper
//struct _Link<Base: Schema, Node: Schema> {
////    let key: PartialKeyPath<To>
////    let asdf: KeyPath<
//    var wrappedValue: Ref<Node> {
//        get {
//            fatalError()
//        }
//    }
//
//    init<A, B>(where parent: KeyPath<Base, Column<A>>, equals child: KeyPath<Node, Column<B>>) {
////        self.key = key
////        fatalError()
//    }
//}

//@propertyWrapper
//struct Relation<Base: Schema, Node: Schema> {
////    let key: PartialKeyPath<To>
////    let asdf: KeyPath<
//    var wrappedValue: Ref<Node> {
//        get {
//            fatalError()
//        }
//    }
//
//    init<A, B>(where parent: KeyPath<Base, Column<A>>, equals child: KeyPath<Node, Column<B>>) {
////        self.key = key
////        fatalError()
//    }
//}


//@propertyWrapper
//struct Link<Left: Schema, Right: Schema> {
////    let left: Column
////    let key: PartialKeyPath<To>
////    let asdf: KeyPath<
//    var wrappedValue: Ref<Right> {
//        get {
//            fatalError()
////            Right.fetch(where: T##KeyPath<Schema, Column<Decodable & Encodable>>, T##op: DBOperator##DBOperator, T##expectation: Decodable & Encodable##Decodable & Encodable)
//        }
//    }
//
//    init<A, B>(where left: KeyPath<Left, Column<A>>, equals right: KeyPath<Right, Column<B>>) {
//
//        let l = Left.template[keyPath: left]
//        let r = Right.template[keyPath: right]
////        Right.fetch(where: left, .equals, right)
////        self.key = key
////        fatalError()
//    }
//}

extension Database {
    func prepare<S: Schema>(_ schema: S) {
        let template = S.template

    }
}

@propertyWrapper
struct Nested<S: Schema> {
    var wrappedValue: S { fatalError() }
}

//extension Column: ColumnProtocol {
//    typealias Wrapped = C
//}


//extension OneToMany: ColumnProtocol {
//    typealias Wrapped = S
//}

final class Box<T> {
    var boxed: T

    init(_ boxed: T) {
        self.boxed = boxed
    }
}


//struct OneToMany<S: Schema> {
//
//    var wrappedValue: [Ref<S>] {
//        fatalError()
//    }
//
//    init(_ key: String) {
//
//    }
//}
var sneaky: [String: Any] = [:]


extension Ref {
    func save() throws {
        db.save(self)
        isDirty = false
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
        let columns = schema.unsafe_getColumns()
        self.init(schema.table, columns)
    }
}


func notImplemented(_ label: String = #function) -> Never {
    Log.error("\(label) not implemented")
    exit(1)
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

    static let shared: SeeQuel = SeeQuel(storage: .file(path: seequel_directory.path))

    private var db: SQLDatabase {
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

    deinit {
        let connect = self.connection
        guard !connect.isClosed else { return }
        let _ = connect.close()
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
}

extension Database {
    func prepare(_ tables: [Table]) throws {
        try tables.forEach(prepare)
    }
}

extension Database {
    func prepare(@TableBuilder _ builder: () -> [Table]) throws {
        let tables = builder()
        try self.prepare(tables)
    }
}

protocol IDSchema: Schema {
    associatedtype PKRawType: PrimaryKeyType
    var _pk: PrimaryKey<PKRawType> { get set }
//    var _id: PrimaryKey<PKRawType> { get set }
//    var _idkp: KeyPath<Self, PrimaryKey<PKRawType>> { get set }
}


//extension Ref {
//    var _id: PrimaryKeyBase? {
//        S.primaryKey
//    }
//
//    fileprivate func setId() throws {
//        guard let _id else {
//            <#statements#>
//        }
//
//    }
//}

//extension Schema {
//    var primary: PrimaryKeyBase? {
//        self[keyPath: Self.primaryKey]
//    }
//}

extension Database {
//    func save<S: Schema>(_ ref: Ref<S>, primary: KeyPath<S, PrimaryKey<String>>) {
//        let pk = S.template[keyPath: primary]
////        guard ref[keyPath: primary] == nil else { fatalError("id already set on object") }
//
//    }
//
//    func save<S: Schema>(_ ref: Ref<S>, primary: KeyPath<S, PrimaryKey<Int>>) {
//
//    }

//    func save<S: IDSchema>(_ ref: Ref<S>) where S.PKRawType == String {
////        ref._pk
//        fatalError()
//    }

//    func save<S>(_ ref: Ref<S>) {
//        if let primary = S.primaryKey {
//            guard ref.backing[primary.key] == nil else { fatalError("ref already exists") }
//            switch primary.keyType {
//            case .uuid:
//                ref.backing[primary.key] = UUID().json
//            case .incrementing:
//                // set automatically after save by sql
////                incrementing = true
//            break
//            }
//        }
//
//        save(to: S.table, ref.backing)
//        ref.isDirty = false
//
//    }
}

extension Schema {
    var _pkuuid: PrimaryKey<String>? { Self.primaryKey as? PrimaryKey<String> }
    var _pkintid: PrimaryKey<Int>? { Self.primaryKey as? PrimaryKey<Int> }
}

extension SeeQuel: Database {
    func prepare(_ table: Table) throws {
        Log.warn("todo: validate template")
        Log.warn("todo: check if table exists")
        /// all objects have an id column
        var prepare = self.db.create(table: table.name)

        table.columns.forEach { column in
            prepare = prepare.column(column.key, type: column.type, column.constraints)
        }

        try prepare.run().wait()
    }

    func save(to table: String, _ body: [String : JSON]) {
        try! self.db.insert(into: table)
            .model(body)
            .run()
            .wait()
    }

    func save<S>(_ ref: Ref<S>) where S : Schema {
        let primary = S.primaryKey
        if let primary = primary {
            guard ref.backing[primary.key] == nil else { fatalError("ref already exists") }
            switch primary.keyType {
            case .uuid:
                /// uuid not auto generated, needs to be made
                ref.backing[primary.key] = UUID().json
            case .incrementing:
                // set automatically after save by sql
//                incrementing = true
            break
            }
        }

        try! self.db.insert(into: S.table)
            .model(ref.backing)
            .run()
            .wait()

        guard
            let pk = primary,
            pk.keyType == .incrementing
            else { return }
        let id = unsafe_lastInsertedRowId()
        ref.backing[pk.key] = id.json
//        if let primary = ref._pkintid {
//            guard ref.backing[primary.key] == nil else { fatalError("ref already exists") }
//            switch primary.keyType {
//            case .uuid:
//                /// uuid not auto generated, needs to be made
//                ref.backing[primary.key] = UUID().json
//            case .incrementing:
//                // set automatically after save by sql
////                incrementing = true
//            break
//            }
//        }
//        let raw = SQLRawExecute("select last_insert_rowid();")
//        var id: Int = -1
////        try! db.select().execute
//        try! db.execute(sql: raw) { (row) in
//            print("metadata: \(row)")
//            let raw = try! row.decode(model: [String: JSON].self)
//            id = raw.values.first!.int!
////            id.append(next)
//        } .wait()
//        print("saved id: \(id)")
////        let rowId = try! self.db.select()
////        print(result)
//        print()
    }

    private func unsafe_lastInsertedRowId() -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try! db.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .wait()
        return id
    }

    func load<S>(id: String) -> Ref<S>? where S : Schema {
        let columns = S.unsafe_getColumns().map(\.name)
        guard let pk = S.primaryKey?.name else { fatalError("missing primary key") }
        let backing = try! self.db.select()
            .columns(columns)
            .where(SQLIdentifier(pk), .equal, id)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        return Ref<S>(unwrap, self)
    }

    func load<S>(ids: [String]) -> [Ref<S>] where S : Schema {
        notImplemented()
    }
}

extension SeeQuel {
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

    struct _TableColumnMeta: Codable {
        // column_id
        let cid: Int
        let name: String
        let type: String
        let notnull: Bool
        let dflt_value: JSON?
        let pk: Bool
    }

    func unsafe_table_meta(_ table: String) throws -> [_TableColumnMeta] {
        var meta = [_TableColumnMeta]()
        try db.execute(sql: SQLTableSchema(table)) { (row) in
            print("metadata: \(row)")
            let next = try! row.decode(model: _TableColumnMeta.self)
            meta.append(next)
        } .wait()
        return meta
    }
}



//import Foundation
//final class TestDB: Database {
//    func prepare(_ table: Table) throws {
//
//    }
//
//    var tables: [String: [String: [String: JSON]]] = [:]
//
//    func save<S>(_ ref: Ref<S>) {
//        var table = tables[S.table] ?? [:]
//        Log.warn("not setting id")
////        let id = ref.id ?? UUID().uuidString
////        ref.id = id
////        table[id] = ref.backing
//        tables[S.table] = table
//    }
//
//    func load<S>(id: String) -> Ref<S>? where S : Schema {
//        guard let table = tables[S.table] else { return nil }
//        guard let backing = table[id] else { return nil }
//        return Ref(backing, self)
//    }
//
//    /// warn if missing ids?
//    func load<S>(ids: [String]) -> [Ref<S>] where S : Schema {
//        guard let table = tables[S.table] else { fatalError() }
//        return ids.compactMap { table[$0] } .map { Ref($0, self) }
//    }
//}

extension Schema {
//    static func `where`<T>(_ kp: KeyPath<Self, Column<T>>, equals: T) -> Ref<Self> {
//        fatalError()
//    }

    static func `where`<T>(_ kp: KeyPath<Self, Column<T>>, in: [T]) -> [Ref<Self>] {
        fatalError()
    }
}

//extension Array where Element == Bool {
//    var hasUnsavedObjects
//}

//@propertyWrapper
//struct OneToMany<S: Schema> {
//    let key: String
//    private var ids: [String] = []
//    private let _cache: Box<[Ref<S>]> = .init([])
//
//    var wrappedValue: [Ref<S>] {
//        get {
//            guard _cache.boxed.isEmpty else { return _cache.boxed }
////            Log.warn("should seek to make this more async somehow")
//            _cache.boxed = S.where(\.id, in: ids)
//            return _cache.boxed
//        }
//        set {
//            print("*** SHOULD I SAVE HERE? ***")
//            /// for now, objects should be saved first
//            let hasUnsavedItems = newValue
//                .map(\.isDirty)
//                .reduce(false, { $0 || $1 })
//            guard !hasUnsavedItems else {
//                fatalError("can not set unsaved many relations")
//            }
//            ids = newValue.compactMap(\.id)
//            _cache.boxed = newValue
//        }
//    }
//
//    init(_ key: String) {
//        self.key = key
//    }
//}

extension Ref {
    /// one to many
    func relations<P: Schema, C>(matching: KeyPath<P, Column<C>>) -> [Ref<P>] {
        fatalError()
    }

    /// one to one
    func parent<P: Schema, C>(matching: KeyPath<S, Column<C>>) -> Ref<P> {
        fatalError()
    }

    /// one to one
    func child<P: Schema, C>(matching: KeyPath<P, Column<C>>) -> Ref<P> {
        fatalError()
    }
}

//private func unsafe_getProperties<R>(template: Ref<R>) -> [(label: String, type: String)] {
//    Mirror(reflecting: template).children.compactMap { child in
//        assert(child.label != nil, "expected a label for template property")
//        guard let label = child.label else { return nil }
//        return (label, "\(type(of: child.value))")
//    }
//}

@_functionBuilder
struct Preparer {
    static func buildBlock(_ schema: Schema.Type...) {

    }
}

//@dynamicMemberLookup
//struct Database {
//    static let shared = Database()
//
//    func prepare(@Preparer _ builder: () -> Void) {
//        builder()
//    }
//
////    subc
//}


//let db = TestDB()

struct Human: Schema {
    var id = PrimaryKey<String>()
    var name = Column<String>("name")
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")

    // MARK: RELATIONS
    /// one to one
    /// should be able to infer a single id column from type, as well as label,
    /// and have just
    /// `var nemesis = Column<Human?>()`
    /// for now taking out, need to address infinite cycle for schema linking to schema
//    var nemesis = Column<Human?>("nemesis", foreignKey: \.id)
//
//    /// one to many
//    var pets = Column<[Pet]>("pets", containsForeignKey: \.id)
//    var friends = Column<[Human]>("friends", containsForeignKey: \.id)
}

extension Schema {
    static func prepare(in db: Database, paths: [PartialKeyPath<Self>]) {
        print("got paths: \(paths)")
        let loaded = paths.map { template[keyPath: $0] }
        print("loadedd: \(loaded)")
    }
}

extension KeyPath where Root: Schema {
    func prepare() {

    }
}

//struct Pet: Schema {
//    var id = IDColumn<Int>()
//    var name = Column<String>("name")
//}
//
//protocol ColumnMeta {
//
//}

private func unsafe_getProperties<R>(template: Ref<R>) -> [(label: String, type: String)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}
private func unsafe_getProperties<S: Schema>(template: S) -> [(label: String, type: String)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}

private func _unsafe_getProperties<S: Schema>(template: S) -> [(label: String, type: String, val: Any)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))", child.value)
    }
}

@_functionBuilder
struct PreparationBuilder<S: Schema> {
    static func buildBlock(_ paths: PartialKeyPath<S>...) {
        let temp = S.template
        let loaded = paths.map { temp[keyPath: $0] }
        print("loaded: \(loaded)")
    }
}

//@_functionBuilder
//struct ColumnBuilder<S: Schema> {
//    static func buildBlock(_ paths: KeyPath<S, ColumnBase>...) {
//
//    }
//}

extension Schema {
    static func prepare(on db: Database, @PreparationBuilder<Self> _ builder: () -> Void) {

    }
}

func testDatabaseStuff() {
    let huprops = _unsafe_getProperties(template: Human.template)
    print(huprops)
//    Human.prepare(on: db) {
//        \.age
//        \.friends
//        \.name
//        \.pets
//    }
//    Human.prepare(on: db) {
//        \Human.age
//        \Human.friends
//        \Human.name
////        \.age
////        \.friends
////        \.name
////        \.pets
//    }
//
//    Human.prepare(in: db, paths: [\Human.age, \Human.friends, \Human.name, \Human.pets])
//
//    let joe = Ref<Human>(database: db)
//    joe.id = "0"
//    joe.name = "joe"
//    joe.age = 13
//
//    let jan = Ref<Human>(database: db)
//    jan.id = "1"
//    jan.name = "jane"
//    jan.age = 14
//    let frand = jan.nemesis
//    print(frand)
//
//    joe.nemesis = jan
//    jan.nemesis = joe
//
//    joe.friends = [joe, jan]

//    let bobo = Ref<Pet>(db)
//    bobo.name = "bobo"
//    try! bobo.save()
//    let spike = Ref<Pet>(db)
//    spike.name = "spike"
//    try! spike.save()
//    let dolly = Ref<Pet>(db)
//    dolly.name = "dolly"
//    try! dolly.save()
//
////    joe.pets = [bobo, spike, dolly]
////    jan.pets = [bobo]
//
//    print(db.tables[Human.table])
//    try! joe.save()
//    try! jan.save()
//    print(db.tables[Human.table]!)
//    try! joe.save()
//    jan.friend = joe
//    try! jan.save()
//    joe.friend()
//    joe.save()

//    print("Hi: \(joe.friends)")
}

func orig_testDatabaseStuff() {
//    Database.shared.prepare {
//        Pet.self
//        Human.self
//    }

//    Human.prepare {
//        \Human.id
//        \Human._dad
//    }

//    Pet.fetch(where: \.friend, .equals, "joe")
//    newhh.id = ""

//    let new = Ref<Human>()
//    new.id = "asdf"
//    new.age = 13
//    print("Hi: \(new.friend)")
//    let pets = new.pets
//    let a = new.pets
//    let pets = new.relations(matching: \Pet.friend)
//    let parent = new.parent(matching: \._dad) as Ref<Human>
//    new.child(matching: <#T##KeyPath<Schema, Column<Decodable & Encodable>>#>)

//    let a = new.age
//    let asd = unsafe_getProperties(template: new)
//    print(asd)
//    let props = unsafe_getProperties(template: Human.self)
//    print(props)
//    \Human.id
    let all = Human.template.allKeyPaths
    print()
//    new.name = "blorgop"

//    new.age.
    let ref: Ref<Human>! = nil

//    let a = ref.age
}

extension Human: KeyPathListable {}
private func unsafe_getProperties<S: Schema>(template: S.Type) -> [(label: String, type: String)] {
    Mirror(reflecting: S.template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}

protocol KeyPathListable: Schema {
    var allKeyPaths: [String: PartialKeyPath<Self>] { get }
}

extension KeyPathListable {
    private subscript(checkedMirrorDescendant key: String) -> Any {
        return Mirror(reflecting: self).descendant(key)!
    }

    var allKeyPaths: [String: PartialKeyPath<Self>] {
        var membersTokeyPaths = [String: PartialKeyPath<Self>]()
        let mirror = Mirror(reflecting: self)
        for case (let key?, _) in mirror.children {
            membersTokeyPaths[key] = \Self.[checkedMirrorDescendant: key] as PartialKeyPath
        }
        return membersTokeyPaths
    }
}
