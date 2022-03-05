import SQLKit
import SQLiteKit

@TablesActor
extension SQLDatabase {
    
    // IDs
    
    func load<S>(id: String) throws -> Ref<S>? where S : Schema {
        try loadFirst(
            where: S.template._primaryKey.name,
            matches: id
        )
    }

    func loadAll<S: Schema>(ids: [String]) throws -> [Ref<S>] {
        try loadAll(where: S.template._primaryKey.name, in: ids)
    }
    
    // One
    
    func loadFirst<S: Schema, T: Encodable>(where key: String, matches compare: T) throws -> Ref<S>? {
        try _loadFirst(
            from: S.table,
            where: key,
            equals: compare
        ) .flatMap { Ref($0, self, exists: true) }
    }
    
    // Many
    
    func loadAll<S: Schema>() throws -> [Ref<S>] {
        try _loadAll(from: S.table).map {
            Ref($0, self, exists: true)
        }
    }
    
    func loadAll<S: Schema, E: Encodable>(where key: String, matches compare: E) throws -> [Ref<S>] {
        try _loadAll(
            from: S.table,
            where: key,
            equals: compare
        ) .map { Ref($0, self, exists: true) }
    }
    
    func loadAll<S: Schema, E: Encodable>(where key: String, `in` compare: [E]) throws -> [Ref<S>] {
        try _loadAll(
            from: S.table,
            where: key,
            in: compare
        ) .map { Ref($0, self, exists: true) }
    }
    
    func loadAll<S: Schema>(where key: String, contains compare: String) throws -> [Ref<S>] {
        try _loadAll(
            from: S.table,
            where: key,
            contains: compare
        ) .map { Ref($0, self, exists: true) }
    }
    
    // make
    
    func create<S: Schema>(_ ref: Ref<S>) throws {
        try _create(in: S.table, ref.backing)
    }
    
    // update

    func update<S: Schema>(_ ref: Ref<S>) throws {
        let primary = S.template._primaryKey
        try _update(
            in: S.table,
            where: primary.name,
            matches: ref.backing[primary.name],
            ref.backing
        )
    }
    
    // delete
    
    func delete<S: Schema>(_ ref: Ref<S>) throws {
        let idColumn = S.template._primaryKey
        let idValue = ref._id
        try _deleteAll(
            from: S.table,
            where: idColumn.name,
            matches: idValue
        )
    }
    
    private func unsafe_lastInsertedRowId() throws -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try self.execute(sql: raw) { (row) in
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

//import SQLKit
//
//@propertyWrapper
//struct SQLLoggingDatabase<DB: SQLDatabase>: SQLDatabase {
//    var logger: Logger { wrappedValue.logger }
//    var eventLoop: EventLoop { wrappedValue.eventLoop }
//    var dialect: SQLDialect { wrappedValue.dialect }
//
//    let wrappedValue: DB
//
//    init(_ wrapped: DB) {
//        self.wrappedValue = wrapped
//    }
//    func execute(sql query: SQLExpression,
//                 _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
//        print(query)
//        return wrappedValue.execute(sql: query, onRow)
//    }
//}
