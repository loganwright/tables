import SQLKit

extension Schema {
    static func prepare(in db: SQLDatabase = SQLManager.shared.db) async throws {
        try await db.prepare(Self.self)
    }
}

extension Array where Element == Schema.Type {
    func prepare(in db: SQLDatabase = SQLManager.shared.db) async throws {
        try await self.asyncForEach { try await $0.prepare(in: db) }
    }
}

/// overkill prolly, lol
@resultBuilder
class Preparer {
    static func buildBlock(_ schema: Schema.Type...) -> [Schema.Type] { schema }
}

extension SQLDatabase {
    func prepare(@Preparer _ build: () throws -> [Schema.Type]) async throws {
        let schemas = try build()
        try await schemas.asyncForEach(prepare)
        Log.info("done preparing.s")
    }

    func prepare(_ schema: Schema.Type) async throws {
        Log.info("preparing: \(schema.table)")

        // INTROSPECT

        let template = schema.init()
        /// all sql columns to be stored
        let columns = template.columns
        // special handling, multiple foreign columns but not a composite
        // where each points to a different table
        let foreignColumnConstraints = columns.compactMap { $0 as? ForeignColumnKeyConstraint }
        // additional constraints for the table
        // right now only key groups
        let tableConstraints = template.tableConstraints

        // PREPARE

        var prepare = self.create(table: schema.table)

        /// add all column attributes
        prepare = columns.reduce(prepare) { prepare, column in
            prepare.add(column: column)
        }

        /// more than one foreign key columns need to be declared at end
        prepare = foreignColumnConstraints.reduce(prepare) { prepare, constraint in
            prepare.add(foreignColumnConstraint: constraint)
        }

        /// table constraints at end, pretty much just composite keys / groups
        /// to say again.. foreign individual columns to unique tables != foreign composite keys
        prepare = tableConstraints.steps.reduce(prepare) { prepare, step in
            prepare.add(custom: step)
        }

        // EXECUTE

        try await prepare.run().commit()
    }
}

extension SQLCreateTableBuilder {
    func add(column: BaseColumn) -> SQLCreateTableBuilder {
        self.column(column.name, type: column.type, column.constraints)
    }
}

extension SQLCreateTableBuilder {
    func add(custom: (SQLCreateTableBuilder) -> SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        custom(self)
    }
}
