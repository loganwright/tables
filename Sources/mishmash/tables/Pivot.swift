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
            .constrainig(by: .notNull)
        let right = ForeignKey(rn, pointingTo: rpk)
            .constrainig(by: .notNull)
        self.left = left
        self.right = right
    }

    let tableConstraints = TableConstraints {
        PrimaryKeyGroup(\.left, \.right)
    }
}

///
/// can not have same team && number
/// but can have same key in other columns
struct __HockeyPlayer: Schema {
    let team = Column<String>()
    let number = Column<Int>()
    let nickname = Column<String>()
//    let group = Unique(\.team, \.number, \.nickname)

    let compound = compounding(\.team, \.number, \.nickname)

    let t = Unique<String>()
    let a = Unique<Int>()

//    struct Combination {
//        let a = \HockeyPlayer.team
//        let b = \HockeyPlayer.number
//        let nickname = \HockeyPlayer.nickname
//    }
}

//class Composite<T> {
//
//}

/////
///// can not have same team && number
///// but can have same key in other columns
//struct HockeyPlayer: Schema {
//    class Group: GroupSchema {
//        let team = Column<String>()
//        let number = Column<Int>()
//        let nickname = Column<String>()
//    }
//    let group = Composite<Group>()
//}

//
//extension Ref {
//    subscript<P>(dynamicMember key: KeyPath<Composite<P)
//}


extension Unique {
    func attach<T, U>(to: KeyPath<T, Unique<U>>) {

    }
}

struct Combine<C: SQLColumn> {

}

//struct Gamer: Schema {
//    let id = PrimaryKey<Int>()
//    let gamerTag = PrimaryKey<String>()
//
//    let adsf = compounding(\.id, \.gamerTag)
//}

//extension KeyPath where Value: SQLColumn {
//    var de_type: KeyPath<Root, SQLColumn> { self }
//}

class CompoundPrimary: PrimaryKeyBase {
    init<A>(_ a: KeyPath<A, PrimaryKeyBase>, _ c: KeyPath<A, PrimaryKeyBase>) {
        fatalError()
    }
}

protocol CompoundableKey {}


//@_functionBuilder
//class CompoundKeys<T> {
//    static func buildBlock(_ schema: KeyPath<T, Column<Any>...) -> [KeyPath<T, SQLColumn>] { schema }
//}

//@dynamicMemberLookup
final class Compound<Holder: Schema, FieldOne: SQLColumn, FieldTwo: SQLColumn> {

    var grouping: [KeyPath<Schema, SQLColumn>]
    init() {
        fatalError()
    }
//    var a: KeyPath<Self, A>
//    var b: KeyPath<Self, B>
//    init(_ a: A, s: B) {
////        self.a = a
////        self.b = b
//        fatalError()
//    }
//
//    subscript<T>(dynamicMember key: KeyPath<A, T>) -> T {
//        return self[keyPath: a][keyPath: key]
//    }
//
//    subscript<T>(dynamicMember key: KeyPath<B, T>) -> T {
//        return self[keyPath: b][keyPath: key]
//    }
}

extension Schema {
//    static func compoundPrimary(_ primaries: KeyPath<Self, Any>...) -> Compound<Self> {
//        fatalError()
//    }
    static func constraining<T: SQLColumn, U: SQLColumn>(_ t: KeyPath<Self, T>,
                                                        _ u: KeyPath<Self, U>) -> Compound<Self, T, U> {
        fatalError()
    }

    static func constraining<T: SQLColumn, U: SQLColumn, V: SQLColumn>(
        _ t: KeyPath<Self, T>,
        _ u: KeyPath<Self, U>,
        _ v: KeyPath<Self, V>) -> Compound<Self, T, U> {
        fatalError()
    }
    static func compounding<T: SQLColumn, U: SQLColumn>(_ t: KeyPath<Self, T>,
                                                        _ u: KeyPath<Self, U>) -> Compound<Self, T, U> {
        fatalError()
    }

    static func compounding<T: SQLColumn, U: SQLColumn, V: SQLColumn>(
        _ t: KeyPath<Self, T>,
        _ u: KeyPath<Self, U>,
        _ v: KeyPath<Self, V>) -> Compound<Self, T, U> {
        fatalError()
    }
//    static func compoundKey<T: PrimaryKeyBase, U: PrimaryKeyBase>(_ l: KeyPath<Self, T>, _ u: KeyPath<Self, U>) -> Compound<Self> {
//        fatalError()
//    }
}
extension Column {
    var ssaqql: SQLColumn {
        return self
    }
}

extension SQLColumn {
    @discardableResult
    func constrainig(by constraints: SQLColumnConstraintAlgorithm...) -> Self {
        let columnConstraints = constraints.filter(\.isValidColumnConstraint)
        self.constraints.append(contentsOf: columnConstraints)
        return self
    }
}

extension SQLColumnConstraintAlgorithm {
    var isValidColumnConstraint: Bool {
        switch self {
        /// just foreign key it seems now needs to be declared at end
        /// or if things are grouped or so
        case .foreignKey:
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
