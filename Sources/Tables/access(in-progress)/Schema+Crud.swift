import Logging
import SQLiteKit
import Foundation

// MARK: Create

extension Schema {
    public static func new(referencing db: SQLDatabase = SQLManager.shared.db) -> Ref<Self> {
        Ref(db)
    }
}

extension SQLDatabase {
    @TablesActor
    public func new<S: Schema>(_ schema: S.Type) -> Ref<S> {
        S.new(referencing: self)
    }
}

// MARK: Retrieve

extension Schema {
    public static func load(id: String, in db: SQLDatabase = SQLManager.shared.db) throws -> Ref<Self>? {
        try db.load(id: id)
    }
    
    public static func load(ids: [String], in db: SQLDatabase = SQLManager.shared.db) throws -> [Ref<Self>] {
        try db.loadAll(ids: ids)
    }
    
    public static func loadAll(in db: SQLDatabase = SQLManager.shared.db) throws -> [Ref<Self>] {
        try db.loadAll()
    }
}

extension Schema {
    
    // One
    
    public static func loadFirst<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                               matches value: T,
                                               in db: SQLDatabase = SQLManager.shared.db) throws -> Ref<Self>? {
        try db.loadFirst(where: Self.template[keyPath: column].name,
                               matches: value)
    }
    
    // Many
    
    public static func loadAll<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                             matches compare: T,
                                             in db: SQLDatabase = SQLManager.shared.db) throws -> [Ref<Self>] {
        try db.loadAll(where: Self.template[keyPath: column].name,
                             matches: compare)
    }
    
    public static func loadAll<T: Encodable>(where column: KeyPath<Self, Column<T>>,
                                             in compare: [T],
                                             in db: SQLDatabase = SQLManager.shared.db) throws -> [Ref<Self>] {
        try db.loadAll(where: Self.template[keyPath: column].name,
                             in: compare)
    }
    
    public static func loadAll<T>(where column: KeyPath<Self, Column<T>>,
                                  contains compare: String,
                                  in db: SQLDatabase = SQLManager.shared.db) throws -> [Ref<Self>] {
        try db.loadAll(where: Self.template[keyPath: column].name,
                             contains: compare)
    }
}

// MARK: Delete

@TablesActor
public protocol Deletable {
    func delete() throws
}

extension Ref: Deletable {
    public func delete() throws {
        try db.delete(self)
    }
}

@TablesActor
extension Array where Element: Deletable {
    public func delete() throws {
        try forEach { try $0.delete() }
    }
}

/// mass creations

extension Schema {
    public static func make<C: BaseColumn>(on db: SQLDatabase,
                                   columns: KeyPath<Self, C>...,
                                   rows: [[Any]]) throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try rows.map { row in
            let new = Self.new(referencing: db)
            try zip(columns, row).forEach { k, v in
                let column = template[keyPath: k]
                let js = try JSON(fuzzy: v)
                new._unsafe_setBacking(column: column, value: js)
            }
            try new.save()
            return new
        }
    }

    static func make<C: BaseColumn>(on db: SQLDatabase,
                                   with columns: KeyPath<Self, C>...,
                                   and rows: [[JSON]])  throws -> [Ref<Self>] {
        let counts = rows.map(\.count)
        assert(counts.allSatisfy { columns.count == $0 })
        return try rows.map { row in
            let new = Self.new(referencing: db)
            zip(columns, row).forEach { k, v in
                let column = template[keyPath: k]
                new._unsafe_setBacking(column: column, value: v)
            }
            try  new.save()
            return new
        }
    }
}

/// used to execute raw sql
/// !!!! use caution !!!!!
/// possible to circumvent sql safeguards
internal struct SQLRawExecute: SQLExpression {
    let raw: String
    init(_ raw: String) {
        self.raw = raw
    }

    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write(raw)
    }
}

// MARK: Async Extensions

//extension Sequence {
//    public func asyncForEach(_ op: (Element) async throws -> Void) async rethrows {
//        for e in self {
//            try await op(e)
//        }
//    }
//    public func asyncMap<T>(_ op: (Element) async throws -> T) async rethrows -> [T] {
//        var mapped = [T]()
//        for e in self {
//            let new = try await op(e)
//            mapped.append(new)
//        }
//        return mapped
//    }
//    public func asyncFlatMap<T>(_ op: (Element) async throws -> T?) async rethrows -> [T] {
//        var mapped = [T]()
//        for e in self {
//            guard let new = try await op(e) else { continue }
//            mapped.append(new)
//        }
//        return mapped
//    }
//}


// MARK: KeyPath

extension KeyPath where Value: BaseColumn {
    var detyped: KeyPath<Root, BaseColumn> {
        appending(path: \.root)
    }
}

extension BaseColumn {
    var root: BaseColumn {
        return self
    }
}
