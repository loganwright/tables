@testable import mishmash

class CompositeKeyTests: SieqlTersts {

    struct Team: Schema {
        let id = PrimaryKey<Int>()
    }

    struct Player: Schema {
        let id = PrimaryKey<Int>()

        /// must be unique as pair
        let team = ForeignKey<Team>(pointingTo: \.id)
        let jerseyNumber = Column<Int>()

        let tableConstraints = TableConstraints {
            UniqueGroup(\.team, \.jerseyNumber)
        }
    }

    func testUniqueGroup() {
        
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
