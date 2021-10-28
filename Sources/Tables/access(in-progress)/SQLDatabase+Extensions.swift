extension SQLDatabase {
    func load<S>(id: String) async throws -> Ref<S>? where S : Schema {
        try await self.select()
            .columns(["*"])
            .where(SQLIdentifier(S.template._primaryKey.name), .equal, id)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .commit()
            .flatMap { Ref($0, self, exists: true) }
    }

    func load<S: Schema>(ids: [String]) async throws -> [Ref<S>] {
        try await ids.asyncFlatMap(load(id:))
    }
    
    func loadAll<S: Schema>() async throws -> [Ref<S>] {
        try await self.select()
            .columns(["*"])
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .commit()
            .map { Ref($0, self, exists: true) }
    }

    func loadFirst<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> Ref<S>? {
        try await self.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .commit()
            .flatMap { Ref($0, self, exists: true) }
    }
    
    func loadAll<S: Schema, T: Encodable>(where key: String, matches: T) async throws -> [Ref<S>] {
        try await self.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .commit()
            .map { Ref($0, self, exists: true) }
    }

    func save(to table: String, _ body: [String : JSON]) async throws {
        try await self.insert(into: table)
            .model(body)
            .run()
            .commit()
    }

    func update<S: Schema>(_ ref: Ref<S>) async throws {
        let primary = S.template._primaryKey
        try await self.update(S.table)
            .where(primary.name._sqlid, .equal, ref.backing[primary.name])
            .set(model: ref.backing)
            .run()
            .commit()
    }
    
    func delete<S: Schema>(_ ref: Ref<S>) async throws {
        let idColumn = S.template._primaryKey
        let idValue = ref._id
        try await self.delete(from: S.table)
            .where(idColumn._sqlIdentifier, .equal, idValue)
            .run()
            .commit()
    }
    
    private func unsafe_lastInsertedRowId() async throws -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try await self.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .commit()
        guard id != -1 else { throw "unset" }
        return id
    }
}

import SQLKit

@propertyWrapper
struct SQLLoggingDatabase<DB: SQLDatabase>: SQLDatabase {
    var logger: Logger { wrappedValue.logger }
    var eventLoop: EventLoop { wrappedValue.eventLoop }
    var dialect: SQLDialect { wrappedValue.dialect }

    let wrappedValue: DB

    init(_ wrapped: DB) {
        self.wrappedValue = wrapped
    }
    func execute(sql query: SQLExpression,
                 _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
        print(query)
        return wrappedValue.execute(sql: query, onRow)
    }
}
