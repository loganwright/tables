

/// POSSIBBLE VALIDATION
///
///
///    a schema shouldn't have more than one foreign keys to a single foreign table
///    (this will be supported in the future with composite keys that are surfaced to
///    end users via a single property, so the validation will stand.. for now keeps
///    from making issues)
///    WORKAROUND:
///    - use table constraints to manually add foreign key attributes
///    - create a property that queries by both properties
///    LIMITATIONS:
///    - don't get automated setters and such :)
///
///
///    a schema shouldn't have more than one primary key.
///    for basically the same reasons mentioned above
///    WORKAROUND:
///    - manual table constraints, not exposed
///    LIMITATIONS:
///
///
///

import SQLKit

typealias QueryBuildStep = (SQLCreateTableBuilder) -> (SQLCreateTableBuilder)

@resultBuilder
struct ListBuilder<T> {
    static func buildBlock(_ items: T...) -> [T] {
        items
    }
}

final class TableConstraints {
    @Later var steps: [QueryBuildStep]
    init(@ListBuilder<QueryBuildStep> _ build: @escaping () -> [QueryBuildStep]) {
        self._steps = Later(build)
    }

    func prepare(_ builder: SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        steps.reduce(builder) { builder, constraint in
            constraint(builder)
        }
    }
}

extension SQLCreateTableBuilder {
    func add(tableConstraints: TableConstraints) -> SQLCreateTableBuilder {
        tableConstraints.steps.reduce(self) { prepare, constraint in
            constraint(prepare)
        }
    }
}

/**
 For table constraints, we will only support PRIMARY KEY and UNIQUE

 PRIMARY KEY supports multiple keys

 UNIQUE COLUMN makes THAT column individually unique
 UNIQUE creates a group unique constraint, this means, (1, 2) and (1, 3) would both be allowed
 it would only throw if ALL columns in the unque set match

 FOREIGN KEY while it is possible for a foreign key to point to a non primary key
 this is considered to be not best practice as they could represent something like
 an address and won't always uniquely identify a foreign table which is the intent

 for alternative practices, I think the case is low enough and discouraged to not include it

 in this library, we could instead enforce ids and foreign keys link directly to a foreign type

 actually, I believe all of the relationships can then be inferred except for unique groups
 */
extension Schema {
    // MARK: PRIMARY KEY

    static func PrimaryKeyGroup<A: BaseColumn, B: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _primary_key(t.detyped, u.detyped)
    }

    static func PrimaryKeyGroup<A: BaseColumn, B: BaseColumn, C: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>,
        _ v: KeyPath<Self, C>) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _primary_key(t.detyped, u.detyped, v.detyped)
    }

    static func PrimaryKeyGroup<A: BaseColumn, B: BaseColumn, C: BaseColumn, D: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>,
        _ v: KeyPath<Self, C>,
        _ x: KeyPath<Self, D>) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _primary_key(t.detyped, u.detyped, v.detyped, x.detyped)
    }

    private static func _primary_key(_ paths: KeyPath<Self, BaseColumn>...)
    -> (SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        assert(!Self.template.isPrimaryKeyed,
               "composite primaries not yet exposed to the general api")
        return { builder in
            let template = Self.template
            let collumns = paths.map { template[keyPath: $0] } .map(\.name)
            assert(collumns.first(where: \.isEmpty) == nil,
                   "found empty name somehow")
            return builder.primaryKey(collumns)
        }
    }

    // MARK: UNIQUE

    static func UniqueGroup<A: BaseColumn, B: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>
    ) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _unique_key(t.detyped, u.detyped)
    }

    static func UniqueGroup<A: BaseColumn, B: BaseColumn, C: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>,
        _ v: KeyPath<Self, C>
    ) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _unique_key(t.detyped, u.detyped, v.detyped)
    }

    static func UniqueGroup<A: BaseColumn, B: BaseColumn, C: BaseColumn, D: BaseColumn>(
        _ t: KeyPath<Self, A>,
        _ u: KeyPath<Self, B>,
        _ v: KeyPath<Self, C>,
        _ x: KeyPath<Self, D>
    ) -> (SQLCreateTableBuilder) -> (SQLCreateTableBuilder) {
        _unique_key(t.detyped, u.detyped, v.detyped, x.detyped)
    }

    private static func _unique_key(
        _ paths: KeyPath<Self, BaseColumn>...
    ) -> (SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        return { builder in
            let template = Self.template
            let collumns = paths.map { template[keyPath: $0] } .map(\.name)
            return builder.unique(collumns)
        }
    }

    // MARK: FOREIGN KEY

    static func ForeignKeyGroup<Foreign: Schema, A: BaseColumn, B: BaseColumn>(
        _ a_: KeyPath<Self, A>,
        _ b_: KeyPath<Self, B>,
        referencing _a: KeyPath<Foreign, A>,
        _ _b: KeyPath<Foreign, B>
    ) -> (SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        let from = [a_.detyped, b_.detyped]
        let to = [_a.detyped, _b.detyped]
        return _foreign_key(from, referencing: to)
    }

    static func ForeignKeyGroup<Foreign: Schema, A: BaseColumn, B: BaseColumn, C: BaseColumn>(
        _ a_: KeyPath<Self, A>,
        _ b_: KeyPath<Self, B>,
        _ c_: KeyPath<Self, B>,
        referencing _a: KeyPath<Foreign, A>,
        _ _b: KeyPath<Foreign, B>,
        _ _c: KeyPath<Foreign, C>)
    -> (SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        let from = [a_.detyped, b_.detyped, c_.detyped]
        let to = [_a.detyped, _b.detyped, _c.detyped]
        return _foreign_key(from, referencing: to)
    }

    private static func _foreign_key<Foreign: Schema>(
        _ from: [KeyPath<Self, BaseColumn>],
        referencing to: [KeyPath<Foreign, BaseColumn>])
    -> (SQLCreateTableBuilder) -> SQLCreateTableBuilder {
        return { builder in
            let from_template = Self.template
            let to_template = Foreign.template

            let from_collumnRefs = from.map { from_template[keyPath: $0] }
            let from_collumns =  from_collumnRefs.map(\.name)
            let hasForeignColumnConstraints = from_collumnRefs.lazy.compactMap {
                $0 as? ForeignColumnKeyConstraint
            } .first != nil
            assert(!hasForeignColumnConstraints,
                   "ForeignKey<> column attribute not currently supported as also part of group")
            let to_collumn_refs = to.map { to_template[keyPath: $0] }
            let to_collumns = to_collumn_refs.map(\.name)
            let to = Foreign.table
            assert(from_collumnRefs.count == to_collumns.count)
            return builder.foreignKey(from_collumns, references: to, to_collumns)
        }
    }
}
