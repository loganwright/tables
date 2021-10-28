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

extension Schema {
    static func new(referencing db: SQLDatabase = SQLManager.shared.db) -> Ref<Self> {
        Ref(db)
    }
    
    // TODO: is `insert(into:` better?
    @discardableResult
    static func new(referencing db: SQLDatabase = SQLManager.shared.db, apply: (Ref<Self>) async throws -> Void) async throws -> Ref<Self> {
        let n = Self.new(referencing: db)
        try await apply(n)
        try await n.save()
        return n
    }
    
    // MARK: Load
    
    static func load(id: String, in db: SQLDatabase = SQLManager.shared.db) async throws -> Ref<Self>? {
        try await db.load(id: id)
    }
    
    static func load(ids: [String], in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.load(ids: ids)
    }
    
    static func loadAll<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                      matches compare: T,
                                      in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: Self.template[keyPath: column].name,
                             matches: compare)
    }
    
    static func loadAll(in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll()
    }
    
    static func loadFirst<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                        matches value: T,
                                        in db: SQLDatabase = SQLManager.shared.db) async throws -> Ref<Self>? {
        let column = Self.template[keyPath: column]
        return try await db.select()
            .columns(["*"])
            .where(column._sqlIdentifier, .equal, value)
            .from(Self.table)
            .first(decoding: [String: JSON].self)
            .commit()
            .flatMap { Ref($0, db, exists: true) }
    }
    
    // MARK:
}

///
extension Schema {
//    public static func on(_ db: SQLDatabase) -> Ref<Self> {
//        return Ref(db)
//    }
    
//    public static func load(id: String, on db: SQLDatabase) async throws -> Ref<Self>? {
//        try await db.load(id: id)
//    }
//
//    public static func loadAll(on db: SQLDatabase) async throws -> [Ref<Self>] {
//        try await db.loadAll()
//    }

//    @discardableResult
//    public static func on(_ db: SQLDatabase, creator: (Ref<Self>) throws -> Void) async throws -> Ref<Self> {
//        let new = Self.on(db)
//        try creator(new)
//        try await new.save()
//        return new
//    }

    public static func make<C: BaseColumn>(on db: SQLDatabase,
                                   columns: KeyPath<Self, C>...,
                                   rows: [[Any]]) async throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try await rows.asyncMap { row in
            try await Self.new(referencing: db) { new in
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
                                   and rows: [[JSON]]) async throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try await rows.asyncMap { row in
            try await Self.new(referencing: db) { new in
                zip(columns, row).forEach { k, v in
                    let column = template[keyPath: k]
                    new._unsafe_setBacking(column: column, value: v)
                }
            }
        }
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

//private struct SQLTableSchema: SQLExpression {
//    let table: String
//
//    public init(_ table: String) {
//        self.table = table
//    }
//
//    public func serialize(to serializer: inout SQLSerializer) {
//        serializer.write("pragma table_info(\(table));")
//    }
//}

// MARK: Database

//protocol Databasej {
//    func save(to table: String, _ body: [String: JSON]) async throws
//    func save<S>(_ ref: Ref<S>) async throws
//    func load<S>(id: String) async throws -> Ref<S>?
//    func load<S>(ids: [String]) async throws -> [Ref<S>]
//    func loadAll<S: Schema>() async throws -> [Ref<S>]
//    func loadFirst<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> Ref<S>?
//    func loadAll<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> [Ref<S>]
//}

// MARK: Async Extensions

extension Sequence {
    func asyncForEach(_ op: (Element) async throws -> Void) async rethrows {
        for e in self {
            try await op(e)
        }
    }
    func asyncMap<T>(_ op: (Element) async throws -> T) async rethrows -> [T] {
        var mapped = [T]()
        for e in self {
            let new = try await op(e)
            mapped.append(new)
        }
        return mapped
    }
    func asyncFlatMap<T>(_ op: (Element) async throws -> T?) async rethrows -> [T] {
        var mapped = [T]()
        for e in self {
            guard let new = try await op(e) else { continue }
            mapped.append(new)
        }
        return mapped
    }
}
