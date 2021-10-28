import SQLKit

extension String {
    var _sqlid: SQLIdentifier { .init(self) }
}

struct TableColumnMeta: Codable {
    // column_id
    let cid: Int
    let name: String
    let type: String
    let notnull: Bool
    let dflt_value: JSON?
    let pk: Bool
}

private struct Table: Decodable {
    let name: String
}

extension SQLDatabase {
    func unsafe_getAllTables() async throws -> [String] {
        let results = try await select().column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .commit()
        return results.map(\.name)
    }

    func unsafe_table_meta(_ table: String) async throws -> [TableColumnMeta] {
        var meta = [TableColumnMeta]()
        let tableInfo = SQLRawExecute("pragma table_info(\(table));\n")
        try await execute(sql: tableInfo) { (row) in
            let next = try! row.decode(model: TableColumnMeta.self)
            meta.append(next)
        } .commit()
        return meta
    }
}

