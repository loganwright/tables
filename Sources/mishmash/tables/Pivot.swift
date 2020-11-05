import SQLKit

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
        let reminder = """
        I set up nesting, but when I implemented on pivot, it broke down kinda quick
        I thinkmight be better to try again w property wrappers or sth else

        or, inverse the pointers

            struct InnerGroupDefine {
                let one = \\Outer.outer
            }

            let outer = PrimaryKey()
        """
        Log.warn(reminder)
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

    let tableConstraints = TableConstraints {
        PrimaryKeyGroup(\.left, \.right)
    }
}


extension BaseColumn {
    @discardableResult
    func constraining(by constraints: SQLColumnConstraintAlgorithm...) -> Self {
        assert(constraints.allSatisfy(\.isValidColumnAddConstraint),
               "invalid add on constraint, these are usually supported via types")
        self.constraints.append(contentsOf: constraints)
        return self
    }
}

extension SQLColumnConstraintAlgorithm {
    /// idk what to na
    fileprivate var isValidColumnAddConstraint: Bool {
        switch self {
        /// just foreign key it seems now needs to be declared at end
        /// or if things are grouped or so
        case .unique, .foreignKey, .primaryKey:
            Log.warn("invalid additional constraint use a corresponding column type")
            Log.info("ie: .unique => Unique<Type>(), .foreignKey => ForeignKey<Type>()")
            return false
        default:
            return true
        }
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

