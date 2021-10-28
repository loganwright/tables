import SQLKit

extension SQLDatabase {
    func delete<S: Schema>(_ ref: Ref<S>) async throws {
        let idColumn = S.template._primaryKey
        let idValue = ref._id
        try await self.delete(from: S.table)
            .where(idColumn._sqlIdentifier, .equal, idValue)
            .run()
            .commit()
    }

    func fetch<S: Schema>(where column: KeyPath<S, BaseColumn>, equals value: String) async throws -> [Ref<S>] {
        let column = S.template[keyPath: column]
        let results = try await self.select()
            .columns(["*"])
            .where(column._sqlIdentifier, .equal, value)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .commit()
        return results.map { Ref($0, self, exists: true) }
    }

    func fetch<S: Schema>(_ type: S.Type = S.self, where columns: [KeyPath<S, BaseColumn>], equal matches: [Any]) async throws -> [Ref<S>] {
        /// star here is columns to return
        var query = self.select().columns(["*"]).from(S.table)

        assert(columns.count == matches.count)
        let columns = columns.map { S.template[keyPath: $0]._sqlIdentifier }
        let values = try matches.map { try JSON(fuzzy: $0) }

        query = zip(columns, values).reduce(query) { query, pair in
            query.where(pair.0, .equal, pair.1)
        }

        let results = try await query.all(decoding: [String: JSON].self).commit()
        return results.map { Ref($0, self, exists: true) }
    }
}
