import SQLKit

// MARK: Pivots

/// a pivot object for connecting many to many relationships
@propertyWrapper
public class Pivot<Left: Schema, Right: Schema>: Relation {
    public var wrappedValue: [Ref<Right>] { replacedDynamically() }

    @Later var lk: PrimaryKeyBase
    @Later var rk: PrimaryKeyBase

    public init() {
        /// this is maybe easier for now, upper version is easier to move to support unique keys
        self._lk = Later { Left.template._primaryKey }
        self._rk = Later { Right.template._primaryKey }
    }
}

// MARK: Backing Schema

/// the underlying schema for storing the pivot
public struct PivotSchema<Left: Schema, Right: Schema>: Schema {
    public static var table: String {
        [Left.table, Right.table].sorted().joined(separator: "_")
    }


    var left: ForeignKey<Left>
    var right: ForeignKey<Right>

    public init() {
        let lpk = \Left._primaryKey
        let rpk = \Right._primaryKey
        let ln = Left.template._pivotIdKey
        let rn = Right.template._pivotIdKey
        let left = ForeignKey(ln, pointingTo: lpk)
            .constraining(by: .notNull)
        let right = ForeignKey(rn, pointingTo: rpk)
            .constraining(by: .notNull)
        self.left = left
        self.right = right
    }

    public let tableConstraints = TableConstraints {
        PrimaryKeyGroup(\.left, \.right)
    }
}

extension Schema {
    var _pivotIdKey: String {
        Self.table + "_" + _primaryKey.name
    }
}

extension Pivot {
    var schema: PivotSchema<Left, Right>.Type { PivotSchema<Left, Right>.self }
}

