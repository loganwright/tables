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
        let properties = Weapon.unsafe_getProperties()
        let columns = properties.compactMap { $0.val as? SQLColumn }
        XCTAssertEqual(properties.count, 2)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.key).contains("id"))
        XCTAssert(columns.map(\.key).contains("power"))
    }

    func testIncompatiblePropertyWarn() {
        struct Foo: Schema {
            var id = IDColumn<Int>()
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
                IDColumn<Int>("id")
                Column<Int>("power")
            }
            Table("food") {
                IDColumn<Int>("id")
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
            Weapon.self
            Food.self
            Hero.self
        }


        let prepared = try db.unsafe_getAllTables()
        XCTAssert(prepared.contains("weapon"))
        XCTAssert(prepared.contains("food"))
        XCTAssert(prepared.contains("hero"))
        XCTAssert(prepared.count == 3)

        let w_meta = try db.unsafe_table_meta("weapon")
        XCTAssertEqual(w_meta.count, 2)
        XCTAssertEqual(w_meta.map(\.name).sorted(),Weapon.unsafe_getColumns().map(\.key).sorted())

        let h_meta = try db.unsafe_table_meta(Hero.table)
        print(h_meta)
        print()
    }

    func testSave() throws {
        let db = SeeQuel(storage: .memory)
        try db.prepare {
            Weapon.self
            Food.self
            Hero.self
        }

        var sword = Ref<Weapon>(db)
        sword.damage = 83
        try sword.save()

        let hero = Ref<Hero>(db)
        hero.name = "hiro"
        hero.nickname = "the good one"
        hero.age = 120
        hero.weapon = sword
        try hero.save()

        print()
    }
}

struct Weapon: Schema {
    var id = IDColumn<Int>()
    var damage = Column<Int>("damage")
}

struct Food: Schema {
    var id = IDColumn<Int>()
    var health = Column<Int>("health")
}

struct Hero: Schema {
    // id
    var id = IDColumn<String>("id")
    // basics
    var name = Column<String>("name")
    var age = Column<Int>("age")
    // nullable
    var nickname = Column<String?>("nickname")

    // relations
    var weapon = Column<Weapon?>("weapon", foreignKey: \.id)
}
