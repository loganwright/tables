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

/**

 Car.on(db) { new in

 }
 */
final class RelationTests: SieqlTersts {
    struct Car: Schema {
        let id = PrimaryKey<Int>()
        let color = Column<String>()
    }

    struct User: Schema {
        let id = PrimaryKey<String>()
        let car = ForeignKey<Car>(pointingTo: \.id)
    }

    func testForeignKey() throws {
        try db.prepare {
            Car.self
            User.self
        }
        
        let car = try Car.on(db) { car in
            car.color = "#aaa832"
        }
        XCTAssertNotNil(car.id, "testing an option to initialize this way.. not done")

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
        let author = ForeignKey<Author>(pointingTo: \.id)
    }

    func testOneToManyKey() throws {
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

    struct Person: Schema {
        let id = PrimaryKey<String>()
        let phone = ToOne<Phone>(linkedBy: \.owner)
    }

    struct Phone: Schema {
        let owner = ForeignKey<Person>(pointingTo: \.id)
    }

    func testToOne() throws {
        try db.prepare {
            Person.self
            Phone.self
        }

        let person = Person.on(db)
        try person.save()

        let phone = Phone.on(db)
        phone.owner = person
        try phone.save()

        XCTAssertEqual(phone.owner?.id, person.id)
        XCTAssertNotNil(person.phone)
    }


    struct Moon: Schema {
        let id = PrimaryKey<String>()
        let sunFriend = ForeignKey<Sun>(pointingTo: \.id)
        let starFriends = ToMany<Star>(linkedBy: \.moonFriend)
    }

    struct Sun: Schema {
        let id = PrimaryKey<String>()
        let moonFriend = ForeignKey<Moon>(pointingTo: \.id)
        let starFriends = ToMany<Star>(linkedBy: \.sunFriend)
    }

    struct Star: Schema {
        let id = PrimaryKey<Int>()
        let moonFriend = ForeignKey<Moon>(pointingTo: \.id)
        let sunFriend = ForeignKey<Sun>(pointingTo: \.id)
    }

    func testOneToOne() throws {
        try db.prepare {
            Moon.self
            Sun.self
            Star.self
        }

        let moon = Moon.on(db)
        try moon.save()
        XCTAssertNil(moon.sunFriend)

        let sun = Sun.on(db)
        try sun.save()

        moon.sunFriend = sun
        XCTAssertNotNil(moon.sunFriend)
        /// will still be `nil` because we dno't have a child relationship
        /// a child will look in the db for matching keys
        /// a separate foreignKey will be as it is
        XCTAssertNil(sun.moonFriend)


        sun.moonFriend = moon
        try sun.save()
        try moon.save()

        XCTAssertNotNil(moon.sunFriend)
        XCTAssertNotNil(sun.moonFriend)
        XCTAssert(moon.starFriends.isEmpty)
        XCTAssert(sun.starFriends.isEmpty)

        let fifty = 50
        try (1...fifty).forEach { int in
            let star = Star.on(db)
            star.id = int
            star.sunFriend = sun
            star.moonFriend = moon
            print("saving star..")
            try star.save()
            print("done saving star..")
        }

        XCTAssertEqual(moon.starFriends.count, 50)
        XCTAssertEqual(sun.starFriends.count, 50)
    }


    struct Course: Schema {
        let id = PrimaryKey<String>()
        let name = Column<String>()
        let students = Pivot<Course, Student>()
    }

    struct Student: Schema {
        let id = PrimaryKey<Int>()
        let name = Column<String>()
        let classes = Pivot<Student, Course>()

    }

    func testManyToMany() throws {
        try db.prepare {
            Course.self
            Student.self
            PivotSchema<Course, Student>.self
        }

        let science = try Course.on(db) { new in
            new.name = "science"
        }
        let gym = try Course.on(db) { new in
            new.name = "gym"
        }


        let student_names = ["jorb", "smalshe", "morp", "blarm"]
        let students = try student_names.map { name in
            try Student.on(db) { new in
                new.name = name
            }
        }

        let student_group_a = Array(students[0...1])
        let student_group_b = Array(students[2...3])
        science.students = student_group_a + student_group_b
        gym.students = student_group_b

        let science_only =  student_group_a.flatMap(\.classes)
        let noGym = science_only.allSatisfy { $0.name == "science" }
        XCTAssert(noGym == true)

//        let both = student_group_b.flatMap(\.classes).map(\.name)
        student_group_b.map(\.classes).forEach { classes in
            let names = classes.map(\.name)
            XCTAssert(names.contains("gym"))
            XCTAssert(names.contains("science"))
        }
        XCTAssert(!student_group_b.isEmpty)

        let jorb = students[0]
        jorb.drop(gym)
    }
}

extension Ref {
    func drop<Drop>(_ toRemove: Ref<Drop>) {
//        S.template.sqlColumns
    }
}

final class DBTests: XCTestCase {
    let sql = SQLManager.unsafe_testable

    func testExtractProperties() {
        let properties = Item.template._unsafe_forceProperties()
        let columns = properties.compactMap { $0.val as? SQLColumn }
        XCTAssertEqual(properties.count, 3)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.name).contains("id"))
        XCTAssert(columns.map(\.name).contains("power"))
    }

    func testUnique() throws {
        let db = SeeQuel(storage: .memory)
        struct Test: Schema {
            let id = PrimaryKey<Int>()

            let favoriteColor = Unique<String>()
            let favoriteNumber = Unique<Int>()
            let favoriteWord = Unique<String>()

            let boring = Column<Int>()
        }

        try db.prepare { Test.self }
        let a = try Test.on(db) { new in
            new.favoriteColor = "yellow"
            new.favoriteNumber = 8
            new.favoriteWord = "arbledarble"
            new.boring = 111
        }

        let e = expectError {
            try Test.on(db) { no in
                no.favoriteColor = "yellow"
                no.favoriteNumber = 4
                no.favoriteWord = "copycats"
                no.boring = 111
            }
        }
        XCTAssert("\(e ?? "")".contains("UNIQUE"))
        XCTAssert("\(e ?? "")".contains("favoriteColor"))

        let n = expectError {
            try Test.on(db) { new in
                new.favoriteColor = "orignal-orange"
                new.favoriteNumber = 8
                new.favoriteWord = "yarmal"
                new.boring = 111
            }
        }
        XCTAssert("\(n ?? "")".contains("UNIQUE"))
        XCTAssert("\(n ?? "")".contains("favoriteNumber"))


        let w = expectError {
            try Test.on(db) { new in
                new.favoriteColor = "bluelicious"
                new.favoriteNumber = 43
                new.favoriteWord = "arbledarble"
                new.boring = 111
            }
        }
        XCTAssert("\(w)".contains("UNIQUE"))
        XCTAssert("\(w)".contains("favoriteWord"))


        try Test.on(db) { orig in
            orig.favoriteColor = "sknvwob"
            orig.favoriteNumber = 99877
            orig.favoriteWord = "01111110"
            orig.boring = 111
        }

        let all = try db.getAll() as [Ref<Test>]
        XCTAssertEqual(all.count, 2)
    }

    func testBlob() throws {
        let _url = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/440px-Image_created_with_a_mobile_phone.png"
        let url = URL(string: _url)!
        let data = try Data(contentsOf: url)

        struct Blobby: Schema {
            let id = PrimaryKey<Int>()
            let img = Column<Data>()
        }

        let db = SeeQuel(storage: .memory)
        try db.prepare {
            Blobby.self
        }
        let blobster = try Blobby.on(db) { new in
            new.img = data
        }
        XCTAssert(blobster.img == data)

        let fetched: Ref<Blobby>? = db.getOne(where: "id", matches: blobster.id)
        XCTAssertNotNil(fetched)
        XCTAssert(fetched?.img == data)
        XCTAssertFalse(fetched?.img.isEmpty ?? false)
    }

    func testIncompatiblePropertyWarn() {
        struct Foo: Schema {
            var id = PrimaryKey<Int>()
            var ohnooo = "that's not right"
        }

        /// I think we should probably throw or exit on incompatible properties,
        /// but right now just warning
        let _ = Foo.template._unsafe_forceColumns()
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
        XCTAssertEqual(w_meta.map(\.name).sorted(),Item.template._unsafe_forceColumns().map(\.name).sorted())

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
            ManyOb.self
            One.self
        }

        let many: [Ref<ManyOb>] = ["a", "b", "c", "d", "e"].map {
            let ref = Ref<ManyOb>(db)
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
}

class Grouped: Column<Grouped> {
    
}

protocol IDSchema: Schema {
    var _id: PrimaryKeyBase { get set }
}

//struct Join<L: IDSchema, R: IDSchema>: Schema {
//    let left = ForeignKey<L>(linking: \._id, primary: true)
//    let right = ForeignKey<R>(linking: \._id, primary: true)
//}

struct Team: Schema {
    let id = PrimaryKey<String>()
    let name = Column<String>()
    let mascot = Column<String>()
    let rating = Column<Int>()

    ///
    let rival = ForeignKey<Team>("rival", pointingTo: \.id)
    ///
    let players = ToMany<Player>(linkedBy: \.team)
}

struct Player: Schema {
    let id = PrimaryKey<Int>()
    let team = ForeignKey<Team>(pointingTo: \.id)
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

    @discardableResult
    static func on(_ db: Database, creator: (Ref<Self>) throws -> Void) throws -> Ref<Self> {
        let new = Ref<Self>(db)
        try creator(new)
        try new.save()
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

func expectError(test: () throws -> Void) -> Error? {
    do {
        try test()
        XCTFail("expected failure, but got success")
        return nil
    } catch {
        return error
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
    let origin = ForeignKey<Location>(pointingTo: \.id)
}



struct ManyOb: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()
    let oneyy = ForeignKey<One>(pointingTo: \.id)
}


struct One: Schema {
    let id = PrimaryKey<Int>()
    let name = Column<String>()

    let many = ToMany<ManyOb>(linkedBy: \.oneyy)
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

    var equippedBy = ForeignKey<Hero>(pointingTo: \.id)
}

struct Food: Schema {
    var id = PrimaryKey<String>()
    var health = Column<Int>()

    var owner = ForeignKey<Hero>(pointingTo: \.id)
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
    var equipped = ForeignKey<Item>(pointingTo: \.id)

    var lunch = ToOne<Food>(linkedBy: \.owner)
}
