import XCTest
@testable import mishmash

/**

 database.prepare {
    Table("user") {
        Column("id", .text, ..primaryKey(autoIncrement: false), .notNull)
        Column("name", .text, .notNull)
        Column("age", .int, .notNull
    }
 }
 */

final class DBTests: XCTestCase {
    let sql = SQLManager.unsafe_testable

    func testExtractProperties() {
        let properties = Item.template.unsafe_getProperties()
        let columns = properties.compactMap { $0.val as? SQLColumn }
        XCTAssertEqual(properties.count, 3)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.name).contains("id"))
        XCTAssert(columns.map(\.name).contains("power"))
    }

    func testIncompatiblePropertyWarn() {
        struct Foo: Schema {
            var id = PrimaryKey<Int>()
            var ohnooo = "that's not right"
        }

        /// I think we should probably throw or exit on incompatible properties,
        /// but right now just warning
        let _ = Foo.template.unsafe_getColumns()
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("incompatible schema property") }))
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("\(Foo.self)") }))
    }

    func testPrepare() throws {
        let db = SeeQuel(storage: .memory)
        try db.prepare {
            Table("weapon") {
                PrimaryKey<Int>("id")
                Column<Int>("power")
            }
            Table("food") {
                PrimaryKey<Int>("id")
                Column<String>("name")
                Column<Int>("health")
            }
        }

        let prepared = try db.unsafe_getAllTables()
        XCTAssert(prepared.contains("weapon"))
        XCTAssert(prepared.contains("food"))
    }

    func testPrepareAuto() throws {
        let db = SeeQuel(storage: .memory)
        try! db.prepare {
            Item.self
            Food.self
            Hero.self
        }


        let prepared = try db.unsafe_getAllTables()
        XCTAssert(prepared.contains("item"))
        XCTAssert(prepared.contains("food"))
        XCTAssert(prepared.contains("hero"))
        XCTAssert(prepared.count == 3)

        let w_meta = try db.unsafe_table_meta("item")
        XCTAssertEqual(w_meta.count, 2)
        XCTAssertEqual(w_meta.map(\.name).sorted(),Item.template.unsafe_getColumns().map(\.name).sorted())

        let h_meta = try db.unsafe_table_meta(Hero.table)
        print(h_meta)
        print()
    }

    func testParentChild() throws {
        let db = SeeQuel(storage: .memory)
        try! db.prepare {
            Item.self
            Food.self
            Hero.self
        }

        let banana = Ref<Food>(db)
        XCTAssertFalse(banana.exists)
        banana.health = 50
        banana.id = "banana"
        XCTAssertFalse(banana.exists)
        try banana.save()
        XCTAssertTrue(banana.exists)
        
        let lorbo = Ref<Hero>(db)
        lorbo.name = "lorbo"
        print(lorbo.lunch)
        XCTAssertNil(lorbo.lunch)
        try lorbo.save()
        banana.owner = lorbo
        try banana.save()
        let _banan = lorbo.lunch
        XCTAssertNotNil(_banan)
//        print(lorbo.lunch)
    }

    func testSave() throws {
        let db = SeeQuel(storage: .memory)
        try db.prepare {
            Item.self
            Food.self
            Hero.self
        }

        let sword = Ref<Item>(db)
        sword.power = 83
        XCTAssertNil(sword.id)
        try sword.save()
        XCTAssertFalse(sword.isDirty)
        XCTAssertNotNil(sword.id)

        let hero = Ref<Hero>(db)
        hero.name = "hiro"
        hero.nickname = "the good one"
        hero.age = 120
        XCTFail("uncast")
        let e = sword.equippedBy
        print(e)
        try hero.save()
        sword.equippedBy = hero
        hero.equipped = sword

        XCTAssertNil(hero.id)
//        try hero.save()
        XCTAssertFalse(hero.isDirty)
        XCTAssertNotNil(hero.id)

        let _hero: Ref<Hero>? = db.load(id: hero.id!)
        XCTAssertNotNil(_hero)
        XCTAssertEqual(_hero?.id, hero.id)
        let props = Hero.template.unsafe_propertyList()
        XCTFail("uncomment: \(props)")
        XCTAssertEqual(_hero?.equipped?.id, sword.id)
    }

    func testOneToMany() throws {

        let db = SeeQuel(storage: .memory)
        try db.prepare {
            Many.self
            One.self
        }

        let many: [Ref<Many>] = ["a", "b", "c", "d", "e"].map {
            let ref = Ref<Many>(db)
            ref.name = $0
            return ref
        }

        try many.forEach { try $0.save() }

        let one = Ref<One>(db)
        one.name = "blarb"
        XCTFail("nooooo")
//        one.many = many
        try one.save()

        let two: Ref<One>  = db.load(id: "1")!
        XCTFail("make the map work again")
//        XCTAssertEqual(many.map(\.id), two.many.map(\.id))
    }
}

struct Many: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()
    let parent = Parent<One>(references: \.id)
}


struct One: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()

    let many = Children<Many>(foreign: \.parent)

//    let many = Children<Many>(foreign: \.parent)
//    let many = Column<[Many]>(\One.id, matches: \Many.parent)
}

import SQLKit


//extension Schema {
//    static func make(on: Database) -> Ref<Self> {
//        return .init([:], on)
//    }
//}


struct Item: Schema {
    var id = PrimaryKey<Int>()
    var power = Column<Int>()

    var equippedBy = Parent<Hero>(references: \.id)
//    var _equippedBy = Link<Item, Hero>(references: \Hero._equipped)
}

struct Food: Schema {
    var id = PrimaryKey<String>()
    var health = Column<Int>()

    var owner = Parent<Hero>(references: \.id)
}

struct Hero: Schema {
    // id
    var id = PrimaryKey<String>()

    // basics
    var name = Column<String>()
    var age = Column<Int>()
    // nullable
    var nickname = Column<String?>()

    // relations
//    var equipped = Column<Item?>(foreignKey: \.id)
    var equipped = Parent<Item>(references: \.id)

    var lunch = Child<Food>(referencedBy: \.owner)
//    var equipped = Child<Item>(referencedBy: \.equippedBy)
//    var equipped: Any? = nil

//    var _equipped = Link<Hero, Item>.init(\Item._equippedBy)
//    var __eqqq = Child<Item>(referencedBy: \.equippedBy)
}


func asdfldskjfldk() {
//    \Hero._equipped
}

@propertyWrapper
class Link<Me: Schema, Other: Schema>: SQLColumn {
    var wrappedValue: (left: Me, right: Other) {
        fatalError("")
    }

//    let lhs: KeyPath<Left, Link<Left, Right>>
    let rhs: KeyPath<Other, Link<Other, Me>>

    private let _constraints: LazyHandler<[SQLColumnConstraintAlgorithm]>

    override var constraints: [SQLColumnConstraintAlgorithm] {
        get {
            _constraints.get() + super.constraints
        }
        set {
            _constraints.set(newValue)
            super.constraints = newValue
        }
    }
    init(_ name: String = "",
//         _ lhs: KeyPath<Left, Link<Left, Right>>,
         _ references: KeyPath<Other, Link<Other, Me>>) {
//        self.lhs = lhs
        self.rhs = references
        self._constraints = LazyHandler {
            //        let foreign = ParentSchema.template[keyPath: foreign]
            let foreign = Other.template[keyPath: references]
            let defaults: [SQLColumnConstraintAlgorithm] = [
                .references(Other.table,
                            foreign.name,
                            onDelete: nil,
                            onUpdate: nil)
            ]
            return defaults
        }
        super.init(name, .text, [])
    }
}

@propertyWrapper
class o_Link<Left: Schema, Right: Schema>: SQLColumn {
    var wrappedValue: (left: Left, right: Right) {
        fatalError("")
    }

//    let lhs: KeyPath<Left, Link<Left, Right>>
    let rhs: KeyPath<Right, Link<Right, Left>>

    private let _constraints: LazyHandler<[SQLColumnConstraintAlgorithm]>

    override var constraints: [SQLColumnConstraintAlgorithm] {
        get {
            _constraints.get() + super.constraints
        }
        set {
            _constraints.set(newValue)
            super.constraints = newValue
        }
    }
    init(_ name: String = "",
//         _ lhs: KeyPath<Left, Link<Left, Right>>,
         _ references: KeyPath<Right, Link<Right, Left>>) {
//        self.lhs = lhs
        self.rhs = references
        self._constraints = LazyHandler {
            //        let foreign = ParentSchema.template[keyPath: foreign]
            let foreign = Right.template[keyPath: references]
            let defaults: [SQLColumnConstraintAlgorithm] = [
                .references(Right.table,
                            foreign.name,
                            onDelete: nil,
                            onUpdate: nil)
            ]
            return defaults
        }
        super.init(name, .text, [])
    }
}

@propertyWrapper
class __Link<Left: Schema, Right: Schema>: SQLColumn {
    var wrappedValue: (left: Left, right: Right) {
        fatalError("")
    }

    let lhs: KeyPath<Left, Link<Left, Right>>
    let rhs: KeyPath<Right, Link<Right, Left>>

    private let _constraints: LazyHandler<[SQLColumnConstraintAlgorithm]>

    override var constraints: [SQLColumnConstraintAlgorithm] {
        get {
            _constraints.get() + super.constraints
        }
        set {
            _constraints.set(newValue)
            super.constraints = newValue
        }
    }
    init(_ name: String = "",
         _ lhs: KeyPath<Left, Link<Left, Right>>,
         _ rhs: KeyPath<Right, Link<Right, Left>>) {
        self.lhs = lhs
        self.rhs = rhs
        self._constraints = LazyHandler {
            //        let foreign = ParentSchema.template[keyPath: foreign]
            let foreign = Right.template[keyPath: rhs]
            let defaults: [SQLColumnConstraintAlgorithm] = [
                .references(Right.table,
                            foreign.name,
                            onDelete: nil,
                            onUpdate: nil)
            ]
            return defaults
        }
        super.init(name, .text, [])
    }
}


//func asdf() {
//    let a: Item! = nil
//    let p = a.equippedBy
//}
