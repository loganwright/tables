import SQLKit

extension Schema {
    @TablesActor
    public static func prepare(in db: SQLDatabase = SQLManager.shared.db) throws {
        try db.prepare(Self.self)
    }
}

extension Array where Element == Schema.Type {
    @TablesActor
    public func prepare(in db: SQLDatabase = SQLManager.shared.db) throws {
        try self.forEach { try $0.prepare(in: db) }
    }
}

/// overkill prolly, lol
@TablesActor
@resultBuilder
public class Preparer {
    public static func buildBlock(_ schema: Schema.Type...) -> [Schema.Type] { schema }
}

import Foundation

extension Array: Error where Element: Error {}

@TablesActor
public func Prepare(_ db: SQLDatabase = SQLManager.shared.db, @Preparer _ build: @TablesActor @escaping () -> [Schema.Type]) throws {
    try build().prepare(in: db)
//    let group = DispatchGroup()
//    group.enter()
//    actor Store {
//        var anyErrors = [Error]()
//        func callAsFunction(_ err: Error) {
//            anyErrors.append(err)
//        }
//    }
//    let store = Store()
//    Task {
//        do {
//            try await build().prepare(in: db)
//        } catch {
//            await store(error)
//        }
//        group.leave()
//    }
//    group.wait()
//    guard store.anyErrors.isEmpty else { throw store.anyErrors }
}


@TablesActor
extension SQLManager {
    func prepare(@Preparer _ build: () throws -> [Schema.Type]) throws {
        let schemas = try build()
        try schemas.forEach { try db.prepare($0) }
        Log.info("done preparing.s")
    }
}

@TablesActor
extension SQLDatabase {
    func prepare(@Preparer _ build: () throws -> [Schema.Type]) throws {
        let schemas = try build()
        try schemas.forEach { try prepare($0) }
        Log.info("done preparing.s")
    }

    func prepare(_ schema: Schema.Type) throws {
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

        try prepare.run().wait()
    }
}

extension SQLCreateTableBuilder {
    @TablesActor
    func add(column: BaseColumn) -> SQLCreateTableBuilder {
        self.column(column.name, type: column.type, column.constraints)
    }
}

extension SQLCreateTableBuilder {
    @TablesActor
    func add(custom: (SQLCreateTableBuilder) -> SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        custom(self)
    }
}
