// MARK: Pivots

/// a pivot object for connecting many to many relationships
@propertyWrapper
class Pivot<Left: Schema, Right: Schema>: Relation {
    var wrappedValue: [Ref<Right>] { replacedDynamically() }

    @Later var lk: PrimaryKeyBase
    @Later var rk: PrimaryKeyBase

    init() {
        /// this is maybe easier for now, upper version is easier to move to support unique keys
        self._lk = Later { Left.template._primaryKey }
        self._rk = Later { Right.template._primaryKey }
    }
}

/// the underlying schema for storing the pivot
struct PivotSchema<Left: Schema, Right: Schema>: Schema {
    static var table: String {
        [Left.table, Right.table].sorted().joined(separator: "_")
    }

    var left: ForeignKey<Left>
    var right: ForeignKey<Right>

    init() {
        let lpk = \Left._primaryKey
        let rpk = \Right._primaryKey
        let ln = Left.template._pivotIdKey
        let rn = Right.template._pivotIdKey
        self.left = ForeignKey(ln, pointingTo: lpk)
        self.right = ForeignKey(rn, pointingTo: rpk)
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
