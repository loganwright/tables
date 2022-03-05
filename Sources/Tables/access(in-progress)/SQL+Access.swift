import SQLKit

@TablesActor
extension SQLDatabase {
    func fetch<S: Schema>(where column: KeyPath<S, BaseColumn>, equals value: String) throws -> [Ref<S>] {
        let column = S.template[keyPath: column]
        let results = try self.select()
            .columns(["*"])
            .where(column._sqlIdentifier, .equal, value)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .wait()
        return results.map { Ref($0, self, exists: true) }
    }

    func fetch<S: Schema>(_ type: S.Type = S.self, where columns: [KeyPath<S, BaseColumn>], equal matches: [Any]) throws -> [Ref<S>] {
        /// star here is columns to return
        var query = self.select().columns(["*"]).from(S.table)

        assert(columns.count == matches.count)
        let columns = columns.map { S.template[keyPath: $0]._sqlIdentifier }
        let values = try matches.map { try JSON(fuzzy: $0) }

        query = zip(columns, values).reduce(query) { query, pair in
            query.where(pair.0, .equal, pair.1)
        }

        let results = try query.all(decoding: [String: JSON].self).wait()
        return results.map { Ref($0, self, exists: true) }
    }
}
