//
//class PrimaryKeyGroup: PrimaryKeyBase {
//    let keys: [PrimaryKeyBase]
//    init(_ keys: [PrimaryKeyBase]) {
//        self.keys = keys
//        fatalError()
//    }
//}

//extension PrimaryKeyBase {
//    func group<T>(with: KeyPath<T, PrimaryKey<String>>) -> PrimaryKeyGroup {
//        fatalError()
//    }
//    func group<T>(with: KeyPath<T, PrimaryKey<Int>>) -> PrimaryKeyGroup {
//        fatalError()
//    }
//}
//extension PrimaryKeyGroup {
//    func group<T>(with: KeyPath<T, PrimaryKey<String>>) -> PrimaryKeyGroup {
//        fatalError()
//    }
//    func group<T>(with: KeyPath<T, PrimaryKey<Int>>) -> PrimaryKeyGroup {
//        fatalError()
//    }
//}

protocol _Schema: Schema {
    var PRIMARY_KEY: [KeyPath<Self, SQLColumn>] { get }
}

extension SQLColumn {
    var detyped: SQLColumn {
        return self
    }
}

extension KeyPath where Value: SQLColumn {
    var detyped: KeyPath<Root, SQLColumn> {
        appending(path: \.detyped)
    }
}

extension _Schema {
//    static func compoundPrimary(_ primaries: KeyPath<Self, Any>...) -> Compound<Self> {
//        fatalError()
//    }
//    static func constraining<T: SQLColumn, U: SQLColumn>(_ t: KeyPath<Self, T>,
//                                                        _ u: KeyPath<Self, U>) -> Compound<Self, T, U> {
//        fatalError()
//    }
//
//    static func constraining<T: SQLColumn, U: SQLColumn, V: SQLColumn>(
//        _ t: KeyPath<Self, T>,
//        _ u: KeyPath<Self, U>,
//        _ v: KeyPath<Self, V>) -> Compound<Self, T, U> {
//        fatalError()
//    }
    static func compounding<T: SQLColumn, U: SQLColumn>(_ t: KeyPath<Self, T>,
                                                        _ u: KeyPath<Self, U>) -> [KeyPath<Self, SQLColumn>]{
        return [
            t.detyped,
            u.detyped,
        ]
    }

//
//    static func compounding<T: SQLColumn, U: SQLColumn, V: SQLColumn>(
//        _ t: KeyPath<Self, T>,
//        _ u: KeyPath<Self, U>,
//        _ v: KeyPath<Self, V>) -> Compound<Self, T, U> {
//        fatalError()
//    }
//    static func compoundKey<T: PrimaryKeyBase, U: PrimaryKeyBase>(_ l: KeyPath<Self, T>, _ u: KeyPath<Self, U>) -> Compound<Self> {
//        fatalError()
//    }
}

class BaseballPlayer {
    let id = PrimaryKey<Int>()
    let name = Column<String>()

    ///
    ///   these two things are unique together, but not unique to the player because they may
    ///   change teams and another player would take over
    ///
    let team = Column<String>()
    let jerseyNumber = Column<Int>()
}

struct KeyGroup<T> {}

/// automatically group foreign keys and primary keys?

struct _TABLE_CONSTRAINT_CONSTRUCTOR<Schema> {

}


struct Example: Schema {
    let keyOne = Column<String>()
    let keyTwo = Column<Int>()

    static let constraints = TableConstraints {
        PrimaryKeyGroup(\.keyOne, \.keyTwo)
    }
}

struct Ah: Schema {
    let foo = Column<String>()
    let foh = Column<String>()

    let constraints = TableConstraints {
        PrimaryKeyGroup(\.foo, \.foh)
    }
}
struct Ba: Schema {
    let a_foo = Column<String>()
    let b_foo = Column<String>()

    static let tableConstraints = TableConstraints {
        ForeignKeyGroup(
            \.a_foo, \.b_foo,
            referencing:
                \Ah.foo, \Ah.foh
        )
        UniqueGroup(
            \.a_foo,
            \.b_foo
        )
    }
}

//@_functionBuilder
//struct _UNIQUE {
//
//    init(@_UNIQUE _ build: () -> TableConstraint) {
//        fatalError()
//    }
//
//    func  asdf() {
//    }
//
//    static func buildBlock<T: SQLColumn, U: SQLColumn>(
//        _ t: KeyPath<Self, T>,
//        _ U: KeyPath<Self, U>) -> TableConstraint {
//        fatalError()
//    }
//}
//
//@_functionBuilder
//struct _PRIMARY_KEYS<S: Schema> {
//    func callAsFunction<T: SQLColumn, U: SQLColumn>(
//        _ t: KeyPath<S, T>,
//        _ U: KeyPath<S, U>) -> TableConstraint {
//        fatalError()
//    }
////
////    func callAsFunction<T: SQLColumn, U: SQLColumn>(@_PRIMARY_KEYS<S> _ build: () -> TableConstraint) -> TableConstraint {
////        fatalError()
////    }
//
//    static func buildBlock<T: SQLColumn, U: SQLColumn>(
//        _ t: KeyPath<S, T>,
//        _ U: KeyPath<S, U>) -> TableConstraint {
//        fatalError()
//    }
//}

//@_functionBuilder
//struct KeyPathBuilder {
//    static func buildBlodk(
//}

//struct TableConstraints {
//    init(@ListBuilder<TableConstraint> _ build: () -> [TableConstraint]) {
//        fatalError()
//    }
//}
////protocol TableConstraint {}
////struct UNIQUE: TableConstraint {
////
////}
//
//class ForeignKeyGroup<ReferencingTo: Schema> {
//
//}

//struct Back {
//    class asdfKeyGroup: ForeignKeyGroup<Client> {
//        let clientEmail = ForeignKey<Client>(pointingTo: \.username)
//        let clientUsername = ForeignKey(pointingTo: \Client.email)
//    }
//
//    let client = asdfKeyGroup()
//}


struct MultsssiPrim: _Schema {
    /// primary keys
    let one = Column<String>()
    let two = Column<String>()

    let PRIMARY_KEY = compounding(\.one, \.two)
    let FOREIGN_KEY_SETS = [String]()


    /// we can have multiple unique sets, or unique columns
    let UNIQUE_SETS = [String]()
}


//class PrimaryKeyGroup: PrimaryKeyBase {
//    let keys: [PrimaryKeyBase]
//    init(_ keys: [PrimaryKeyBase]) {
//        self.keys = keys
//        fatalError()
//    }
//}
//
//extension PrimaryKeyBase {
//    var toBaseType: PrimaryKeyBase {
//        return self
//    }
//}
//
//extension KeyPath where Value: PrimaryKeyBase {
//    var toBaseType: KeyPath<Root, PrimaryKeyBase> {
//        appending(path: \.toBaseType)
//    }
//}

//struct TableConstraints<T> {
//    var primaryKeys: [KeyPath<T, PrimaryKeyBase>] = []
//
//    mutating func addPrimary<U>(_ key: KeyPath<T, PrimaryKey<U>>) {
//        primaryKeys.append(
//            key.toBaseType
//        )
//    }
//}

struct CompositeConstraints {
    let primaryKey = PrimaryKey<String>()
}

class CompositeKeyTests: SieqlTersts {

    func testMultiplePrimaryKeys() {
        
    }
//    @dynamicMemberLookup
//    class Composite<Group: KeyGroup> {
//        subscript<T>(dynamicMember key: KeyPath<Group, Column<T>>) -> T {
//            fatalError()
//        }
//    }

    struct Gamer: Schema {
        let gamertag = \Primary.gamertag
        let email = \Primary.gamertag

        struct Primary {
            let gamertag = PrimaryKey<String>()
            let email = PrimaryKey<String>()
        }
    }

    struct HockerPlayer: Schema {
        let id = PrimaryKey<Int>()

        let team = Column<String>()
        let jerseyNumber = Column<Int>()
    }

    struct MultiPrim: Schema {
        let one = PrimaryKey<String>()

        let group = Group()

        let color = Column<String>()
        let number = \Group.nummer

        struct Group: CompositeKey {
            let _color = \MultiPrim.color
            let _number = \MultiPrim.number
            var constraint: ConstraintType = .unique

            var nummer = Column<Int>()
        }
    }

    func testIntrospect() throws {
//        try db.prepare { MultiPrim.self }
//
//        let prim = try MultiPrim.on(db) { new in
//            // throws helpful error, test not broken :)
////            new.color = "asdf"
////            new.number = 9
//        }
//        let all = _unsafe_force_hydrate_columns_on(prim)
//        print(all)
//        print("")
    }
    func testMultiPrimaryKey() throws {
        struct MultiPrimary: Schema {
            let one = PrimaryKey<String>()
            let two = PrimaryKey<Int>()
        }

        let all = _unsafe_force_hydrate_columns_on(MultiPrim())
        print(all)
        print()
//        struct Gamer: Schema {
//            @ConstraintGroup
//            var gamertag = PrimaryKey<String>()
//            @ConstraintGroup
//            var userId = PrimaryKey<String>()
//
//            //
//            var rating = Column<Int>()
//        }
//
//        try db.prepare {
//            Player.self
//            SoccerPlayer.self
//            Gamer.self
//        }
    }

    func testGroupedUnique() {
//
//        ///// can not have same team && number
//        ///// but can have same key in other columns
//        struct HockeyPlayer: Schema {
//            class Group: UniqueKeyGroup {
//                let team = Column<String>()
//                let number = Column<Int>()
//                let nickname = Column<String>()
//            }
//            let group = Group()
//        }

    }

    func testUngroupedUnique() {

    }
}
