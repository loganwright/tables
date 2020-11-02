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

class SieqlTersts: XCTestCase {
    var db: SeeQuel! = SeeQuel(storage: .memory(identifier: "tests"))
    override func tearDown() {
        super.tearDown()
        db = nil
    }

}
final class SchemaTests: SieqlTersts {
    struct Car: Schema {
        let id = PrimaryKey<Int>()
        let color = Column<String>()
    }

    struct User: Schema {
        let id = PrimaryKey<String>()
        let car = ForeignKey<Car>(linking: \.id)
    }

    func testForeignKey() throws {
        try db.prepare {
            Car.self
            User.self
        }
        
        let car = Car.on(db) { car in
            car.color = "#aaa832"
        }
        XCTAssertNotNil(car.id, "should come with id from db")

        let user = User.on(db)
        user.car = car
        try user.save()

        XCTAssertEqual(user.backing["car"]?.int, car.id)
    }


    struct Author: Schema {
        let id = PrimaryKey<Int>()
        let name = Column<String>()
        let books = ToMany<Book>(linkedBy: \.author)
    }

    struct Book: Schema {
        let title = Column<String>()
        let author = ForeignKey<Author>(linking: \.id)
    }

    func testToManyKey() throws {
        try db.prepare {
            Author.self
            Book.self
        }

        let author = Author.on(db)
        author.name = "hughes"
        try author.save()

        let booktitless = ["a", "b", "c", "d"]
        let books: [Ref<Book>] = try booktitless.map { title in
            let book = Book.on(db)
            book.title = title
            book.author = author
            try book.save()
            return book
        }
        XCTAssert(books.count == booktitless.count)
        let ids = books.compactMap(\.author).compactMap(\.id)
        XCTAssert(Set(ids).count == 1)
        XCTAssert(ids.count == booktitless.count)
        XCTAssert(author.books.count == booktitless.count)
    }
}

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
            Table("item") {
                PrimaryKey<Int>("id")
                Column<Int>("power")
            }
            Table("food") {
                PrimaryKey<Int>("id")
                Column<String>("item")
                Column<Int>("health")
            }
        }

        let prepared = try db.unsafe_getAllTables()
        XCTAssert(prepared.contains("item"))
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
        XCTAssertEqual(w_meta.count, 3)
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
        lorbo.age = 234
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


        XCTAssertNil(hero.id)
        try hero.save()
        /// 1 to 1, both have a parent relationship
        sword.equippedBy = hero
        hero.equipped = sword
        try hero.save()

        XCTAssertFalse(hero.isDirty)
        XCTAssertNotNil(hero.id)

        let _hero: Ref<Hero>? = db.load(id: hero.id!)
        XCTAssertNotNil(_hero)
        XCTAssertEqual(_hero?.id, hero.id)
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
        try one.save()

        XCTAssert(one.many.isEmpty)
        try! many.forEach { indi in
            indi.oneyy = one
            try indi.save()
        }
        XCTAssert(!one.many.isEmpty)

        let two: Ref<One>  = db.load(id: "1")!
        XCTAssert(two.many.count == one.many.count)
    }

    func testMatch() throws {
        let db = SeeQuel.shared
        try! db.prepare {
            Team.self
            Player.self
        }

        let cats = Ref<Team>(db)
        cats.name = "the Catz"
        cats.mascot = "cats"
        cats.rating = 5
        try cats.save()
    }

    func testFancy() throws {
        let db = SeeQuel.shared
        try! db.prepare { Team.self }
        let columns = Team.template.unsafe_getColumns()
        let instance = Ref<Team>(db)
        for column in columns {
//            instance[keyPath: column] = ""
        }
    }
}

//protocol PrimaryKeyProtocol {}
//
//protocol ID {
//    var id: PrimaryKeyProtocol { get }
//}
//
//extension PrimaryKey: PrimaryKeyProtocol {}
//
//struct Foob: Schema, ID {
//    var id = PrimaryKey<String>()
//}



struct Team: Schema {
    let id = PrimaryKey<String>()
    let name = Column<String>()
    let mascot = Column<String>()
    let rating = Column<Int>()

    ///
    let rival = ForeignKey<Team>(linking: \.id)
    ///
    let players = ToMany<Player>(linkedBy: \.team)
}

struct Player: Schema {
    let id = PrimaryKey<Int>()
    let team = ForeignKey<Team>(linking: \.id)
}

@_functionBuilder
struct FuzzyBuilder<S: Schema> {
    static func buildBlock(_ db: Database) -> Database {
        return db
    }
    static func buildBlock(_ db: Database, _ block: Default<S>...) -> Ref<S> {
        return Ref(db)
    }
}
struct Default<S: Schema> {

    init<T>(_ kp: KeyPath<S, Column<T>>, _ def: T) {
//        self.val = val
        fatalError()
    }
}

extension Schema {
    static func on(_ db: Database) -> Ref<Self> {
        return Ref(db)
    }

    static func on(_ db: Database, creator: (Ref<Self>) -> Void) -> Ref<Self> {
        let new = Ref<Self>(db)
        creator(new)
        let attributes = template.columns.filter(\.shouldSerialize).filter { !($0 is PrimaryKeyBase)}

        guard new.backing.keys.count == attributes.count else {
            fatalError("\(Ref<Self>.self) not properly instantiated")
        }
        try! new.save()
        return new
    }
}

func play() throws {
    let db = SeeQuel.shared


    try! db.prepare {
        Team.self
        Player.self
    }

    let bears = Team.on(db)
    bears.mascot = "bear"
    bears.rating = 8
    try bears.save()

    let ducks = Team.on(db)
    ducks.mascot = "duck"
    ducks.rating = 7
    ducks.rival = bears
    try ducks.save()

    let al = Player.on(db)
    al.team = bears

    let gal = Player.on(db)
    gal.team = bears

    let dale = Player.on(db)
    dale.team = ducks
}

func new<T>(_ t: T.Type) {

}

extension Schema {
    static func make(on db: Database) -> Ref<Self> {
        return Ref<Self>(db)
       }
    static func query(on db: Database) -> Ref<Self> {
        return Ref<Self>(db)
    }
}

struct Location: Schema {
    let id = PrimaryKey<String>()
    let name = Column<String>()
    let nickname = Column<String?>()
}

struct Plant: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()
    let origin = ForeignKey<Location>(linking: \.id)
}



struct Many: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()
    let oneyy = ForeignKey<One>(linking: \.id)
}


struct One: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()

    let many = ToMany<Many>(linkedBy: \.oneyy)
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

    var equippedBy = ForeignKey<Hero>(linking: \.id)
}

struct Food: Schema {
    var id = PrimaryKey<String>()
    var health = Column<Int>()

    var owner = ForeignKey<Hero>(linking: \.id)
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
    var equipped = ForeignKey<Item>(linking: \.id)

    var lunch = ToOne<Food>(referencedBy: \.owner)
}
