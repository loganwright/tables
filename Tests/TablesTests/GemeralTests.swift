import XCTest
import SQLKit
@testable import Tables
@testable import Commons

class SieqlTersts: XCTestCase {
    var db: SQLDatabase { sql.testable_db }
    var sql: SQLManager! = SQLManager.unsafe_testable._unsafe_testable_setIsOpen(true)

    override func tearDown() {
        super.tearDown()
        sql = nil
    }

}

///
///
///
///
///
final class RelationTests : SieqlTersts {

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
        let allscienc = science_only.allSatisfy { $0.name == "science" }
        XCTAssert(allscienc == true)

//        let both = student_group_b.flatMap(\.classes).map(\.name)
        student_group_b.map(\.classes).forEach { classes in
            let names = classes.map(\.name)
            XCTAssert(names.contains("gym"))
            XCTAssert(names.contains("science"))
        }
        XCTAssert(!student_group_b.isEmpty)

        let jorb = students[0]
        XCTAssertEqual(jorb.classes.count, 1)
        try? jorb.remove(from: \.classes, [gym])
        XCTAssertEqual(jorb.classes.count, 1)
        try? jorb.remove(from: \.classes, [science])
        XCTAssertEqual(jorb.classes.count, 0)
        try? jorb.add(to: \.classes, [gym, science])
        XCTAssertEqual(jorb.classes.count, 2)
        try? gym.add(to: \.students, [jorb])

        try? jorb.remove(from: \.classes, [gym, science])
        let a = jorb.classes
        XCTAssertEqual(a.count, 0)
        try? jorb.add(to: \.classes, [gym, science])
        let b = jorb.classes
        XCTAssertEqual(b.count, 2)
        try? jorb.add(to: \.classes, [gym, science])
        let c = jorb.classes
        XCTAssertEqual(c.count, 2, "shouldn't duplicate")
    }


    func testDualForeignKey() {
        struct Bargle: Schema {
            let id = PrimaryKey<String>()
            let a = Column<String>()
            let b = Pivot<Course, Student>()
        }

        struct Student: Schema {
            let id = PrimaryKey<Int>()
            let name = Column<String>()
            let classes = Pivot<Student, Course>()
        }

    }
}

final class DBTests: SieqlTersts {

    func testExtractProperties() {
        let properties = _unsafe_force_Load_properties_on(Item.template)
        let columns = properties.compactMap { $0.val as? BaseColumn }
        XCTAssertEqual(properties.count, 3)
        XCTAssertEqual(properties.count, columns.count)
        XCTAssert(columns.map(\.name).contains("id"))
        XCTAssert(columns.map(\.name).contains("power"))
    }

    func testUnique() throws {
        struct Test: Schema {
            let id = PrimaryKey<Int>()

            let favoriteColor = Unique<String>()
            let favoriteNumber = Unique<Int>()
            let favoriteWord = Unique<String>()

            let boring = Column<Int>()
        }

        try db.prepare { Test.self }
        try Test.on(db) { new in
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
        XCTAssert("\(n!)".contains("UNIQUE"))
        XCTAssert("\(n!)".contains("favoriteNumber"))


        let w = expectError {
            try Test.on(db) { new in
                new.favoriteColor = "bluelicious"
                new.favoriteNumber = 43
                new.favoriteWord = "arbledarble"
                new.boring = 111
            }
        }
        XCTAssert("\(w!)".contains("UNIQUE"))
        XCTAssert("\(w!)".contains("favoriteWord"))


        try Test.on(db) { orig in
            orig.favoriteColor = "sknvwob"
            orig.favoriteNumber = 99877
            orig.favoriteWord = "01111110"
            orig.boring = 111
        }

        let all = try db.getAll() as [Ref<Test>]
        XCTAssertEqual(all.count, 2)
    }

    func ignore_too_long_testBlob() throws {
        let _url = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/440px-Image_created_with_a_mobile_phone.png"
        let url = URL(string: _url)!
        let data = try Data(contentsOf: url)

        struct Blobby: Schema {
            let id = PrimaryKey<Int>()
            let img = Column<Data>()
        }

        try! db.prepare {
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
        let _ = Foo.template.columns
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("incompatible schema property") }))
        XCTAssert(Log._testable_logs.contains(where: { $0.contains("\(Foo.self)") }))
    }


    func testPrepareAuto() throws {
        try sql.unsafe_fatal_dropAllTables()

        try db.prepare {
            Item.self
            Food.self
            Hero.self
        }


        let prepared = try! db.unsafe_getAllTables()
        XCTAssert(prepared.contains("item"))
        XCTAssert(prepared.contains("food"))
        XCTAssert(prepared.contains("hero"))
        XCTAssert(prepared.count == 3)

        let w_meta = try db.unsafe_table_meta("item")
        XCTAssertEqual(w_meta.count, 3)
        XCTAssertEqual(w_meta.map(\.name).sorted(),Item.template.columns.map(\.name).sorted())

        let h_meta = try db.unsafe_table_meta(Hero.table)
        XCTAssertEqual(h_meta.count, 5)
        let storedNames = h_meta.map(\.name).sorted()
        let expected = Hero.template.columns.map(\.name).sorted()
        XCTAssertEqual(storedNames, expected)
    }

    func testParentChild() throws {
        try sql.unsafe_fatal_dropAllTables()

        try db.prepare {
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
        let lunch = lorbo.lunch
        XCTAssertNil(lunch)
        try lorbo.save()
        banana.owner = lorbo
        try banana.save()
        let _banan = lorbo.lunch
        XCTAssertNotNil(_banan)
    }

    func testSave() throws {
        try sql.unsafe_fatal_dropAllTables()

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
        let seq = SeeQuel.shared
        let db = seq.db
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
        try sql.unsafe_fatal_dropAllTables()

        try db.prepare {
            Team.self
            SportsFan.self
        }

        let cats = Ref<Team>(db)
        cats.name = "the Catz"
        cats.mascot = "cats"
        cats.rating = 5
        try cats.save()
        XCTAssertNotNil(cats.id)
    }
}


struct Team: Schema {
    let id = PrimaryKey<String>()
    let name = Column<String>()
    let mascot = Column<String>()
    let rating = Column<Int>()

    ///
    let rival = ForeignKey<Team>("rival", pointingTo: \.id)
    ///
    let fans = ToMany<SportsFan>(linkedBy: \.team)
}

struct SportsFan: Schema {
    let id = PrimaryKey<Int>()
    let team = ForeignKey<Team>(pointingTo: \.id)
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
    var equipped = ForeignKey<Item>(pointingTo: \.id)

    var lunch = ToOne<Food>(linkedBy: \.owner)
}

struct Human: Schema {
    var id = PrimaryKey<String>()
    var name = Column<String>("name")
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")
    var nemesis = ForeignKey(pointingTo: \Human.id)
}
