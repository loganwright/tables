import SQLKit

/// overkill prolly, lol
@resultBuilder
class Preparer {
    static func buildBlock(_ schema: Schema.Type...) -> [Schema.Type] { schema }
}

struct DoubleGenerator: AsyncSequence {
    typealias Element = Int

    struct AsyncIterator: AsyncIteratorProtocol {
        var current = 1

        mutating func next() async -> Int? {
            defer { current &*= 2 }

            if current < 0 {
                return nil
            } else {
                return current
            }
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator()
    }
}
extension SQLDatabase {
    func prepare(@Preparer _ build: () throws -> [Schema.Type]) async throws {
        let schemas = try build()
        for schema in schemas {
            try await prepare(schema)
        }
        
//        try schemas.forEach(prepare)
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
