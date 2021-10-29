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

// MARK: Create

extension Schema {
    public static func new(referencing db: SQLDatabase = SQLManager.shared.db) -> Ref<Self> {
        Ref(db)
    }
    
    // TODO: is `insert(into:` better?
    @discardableResult
    public static func new(referencing db: SQLDatabase = SQLManager.shared.db, apply: (Ref<Self>) async throws -> Void) async throws -> Ref<Self> {
        let n = Self.new(referencing: db)
        try await apply(n)
        try await n.save()
        return n
    }
}

// MARK: Retrieve

extension Schema {
    
    // One
    
    public static func load(id: String, in db: SQLDatabase = SQLManager.shared.db) async throws -> Ref<Self>? {
        try await db.load(id: id)
    }
    
    public static func load(ids: [String], in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(ids: ids)
    }
    
    // Many
    
    public static func loadAll<T: Encodable>(where key: String,
                                      matches compare: T,
                                      in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: key,
                             matches: compare)
    }
    public static func loadAll<T: Encodable>(where key: String,
                                      `in` compare: [T],
                                      in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: key,
                             in: compare)
    }
    public static func loadAll(where key: String,
                        contains compare: String,
                        in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: key,
                             contains: compare)
    }
    
    public static func loadAll(in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll()
    }
    
    public static func loadFirst<T: Encodable>(where key: String,
                                        matches value: T,
                                        in db: SQLDatabase = SQLManager.shared.db) async throws -> Ref<Self>? {
        try await db.loadFirst(where: key,
                               matches: value)
    }
}

extension Schema {
    
    // One
    
    public static func loadFirst<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                               matches value: T,
                                               in db: SQLDatabase = SQLManager.shared.db) async throws -> Ref<Self>? {
        try await loadFirst(where: Self.template[keyPath: column].name,
                            matches: value,
                            in: db)
    }
    
    // Many
    
    public static func loadAll<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                             matches compare: T,
                                             in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: Self.template[keyPath: column].name,
                             matches: compare)
    }
    
    public static func loadAll<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                             in compare: [T],
                                             in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: Self.template[keyPath: column].name,
                             in: compare)
    }
    
    public static func loadAll<T>(where column: KeyPath<Self, Column<T>>,
                                  contains compare: String,
                                  in db: SQLDatabase = SQLManager.shared.db) async throws -> [Ref<Self>] {
        try await db.loadAll(where: Self.template[keyPath: column].name,
                             contains: compare)
    }
}

// MARK: Delete

public protocol Deletable {
    func delete() async throws
}

extension Ref: Deletable {
    public func delete() async throws {
        try await db.delete(self)
    }
}

extension Array where Element: Deletable {
    public func delete() async throws {
        try await asyncForEach { try await $0.delete() }
    }
}
///
extension Schema {

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

// MARK: Async Extensions

extension Sequence {
    public func asyncForEach(_ op: (Element) async throws -> Void) async rethrows {
        for e in self {
            try await op(e)
        }
    }
    public func asyncMap<T>(_ op: (Element) async throws -> T) async rethrows -> [T] {
        var mapped = [T]()
        for e in self {
            let new = try await op(e)
            mapped.append(new)
        }
        return mapped
    }
    public func asyncFlatMap<T>(_ op: (Element) async throws -> T?) async rethrows -> [T] {
        var mapped = [T]()
        for e in self {
            guard let new = try await op(e) else { continue }
            mapped.append(new)
        }
        return mapped
    }
}
