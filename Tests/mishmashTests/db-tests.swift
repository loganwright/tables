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
        let properties = Item.unsafe_getProperties()
        let columns = properties.compactMap { $0.val as? SQLColumn }
        XCTAssertEqual(properties.count, 2)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.key).contains("id"))
        XCTAssert(columns.map(\.key).contains("power"))
    }

    func testIncompatiblePropertyWarn() {
        struct Foo: Schema {
            var id = PrimaryKey<Int>()
            var ohnooo = "that's not right"
        }

        /// I think we should probably throw or exit on incompatible properties,
        /// but right now just warning
        let _ = Foo.unsafe_getColumns()
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
        try db.prepare {
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
        XCTAssertEqual(w_meta.map(\.name).sorted(),Item.unsafe_getColumns().map(\.key).sorted())

        let h_meta = try db.unsafe_table_meta(Hero.table)
        print(h_meta)
        print()
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
        hero.weapon = sword

        XCTAssertNil(hero.id)
        try hero.save()
        XCTAssertFalse(hero.isDirty)
        XCTAssertNotNil(hero.id)

        let _hero: Ref<Hero>? = db.load(id: hero.id!)
        XCTAssertNotNil(_hero)
        XCTAssertEqual(_hero?.id, hero.id)
        XCTAssertEqual(_hero?.weapon?.id, sword.id)

    }
}


struct Item: Schema {
    var id = PrimaryKey<Int>()
    var power = Column<Int>("power")
}

struct Food: Schema {
    var id = PrimaryKey<Int>()
    var health = Column<Int>("health")
}

struct Hero: Schema {
    // id
    var id = PrimaryKey<String>()

    // basics
    var name = Column<String>("name")
    var age = Column<Int>("age")
    // nullable
    var nickname = Column<String?>("nickname")

    // relations
    var weapon = Column<Item?>("weapon", foreignKey: \.id)
}
