import XCTest
import SQLKit
import Tables
@testable import Commons

class SieqlTersts: XCTestCase {
    var db: SQLDatabase { SQLManager.shared.db }
    
    override func setUp() {
        super.setUp()
        SQLManager.shared = .inMemory
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        try await SQLManager.shared.destroyDatabase()
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

    func testForeignKey() async throws {
        try await Prepare {
            Car.self
            User.self
        }

        let car = try await Car.new { car in
            car.color = "#aaa832"
        }
        XCTAssertNotNil(car.id, "testing an option to initialize this way.. not done")

        let user = User.new()
        user.set(\.car, to: car)
//        user.car = car
        try await user.save()

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

    func testOneToManyKey() async throws {
        try await Prepare {
            Author.self
            Book.self
        }

        let author = Author.new()
        author.name = "hughes"
        try await author.save()

        let booktitless = ["a", "b", "c", "d"]
        let books = try await booktitless.asyncMap { title in
            try await Book.new { new in
                new.title = title
                new.set(\.author, to: author)
            }
        }
        
        XCTAssert(books.count == booktitless.count)
        let ids = try await books.asyncFlatMap { try await $0.author?.id }
        XCTAssert(Set(ids).count == 1)
        XCTAssert(ids.count == booktitless.count)
        let pass = try await author.books.count == booktitless.count
        XCTAssert(pass)
    }

    struct Person: Schema {
        let id = PrimaryKey<String>()
        let phone = ToOne<Phone>(linkedBy: \.owner)
    }

    struct Phone: Schema {
        let owner = ForeignKey<Person>(pointingTo: \.id)
    }

    func testToOne() async throws {
        try await Prepare {
            Person.self
            Phone.self
        }

        let person = Person.new()
        try await person.save()

        let phone = Phone.new()
        phone.set(\.owner, to: person)
//        phone.owner = person
        try await phone.save()

        let ownerId = try await phone.owner?.id
        XCTAssertEqual(ownerId, person.id)
        XCTAssertNotNil(try await person.phone)
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

    func testOneToOne() async throws {
        try await Prepare {
            Moon.self
            Sun.self
            Star.self
        }

        let moon = Moon.new()
        try await moon.save()
        let nosun = try await moon.sunFriend
        XCTAssertNil(nosun)

        let sun = Sun.new()
        try await sun.save()

        moon.set(\.sunFriend, to: sun)
//        moon.sunFriend = sun
        XCTAssertNotNil(try await moon.sunFriend)
        /// will still be `nil` because we dno't have a child relationship
        /// a child will look in the db for matching keys
        /// a separate foreignKey will be as it is
        XCTAssertNil(try await sun.moonFriend)


//        sun.moonFriend = moon
        sun.set(\.moonFriend, to: moon)
        try await sun.save()
        try await moon.save()

        XCTAssertNotNil(try await moon.sunFriend)
        XCTAssertNotNil(try await sun.moonFriend)
        let a = try await moon.starFriends.isEmpty
        let b = try await sun.starFriends.isEmpty
        XCTAssert(a)
        XCTAssert(b)

        let fifty = 50
        for int in (1...fifty) {
//        try (1...fifty).forEach { int in
            let star = Star.new()
            star.id = int
            star.set(\.sunFriend, to: sun)
//            star.sunFriend = sun
            star.set(\.moonFriend, to: moon)
//            star.moonFriend = moon
            print("saving star..")
            try await star.save()
            print("done saving star..")
        }

        let mc = try await moon.starFriends.count
        let sc = try await sun.starFriends.count
        XCTAssertEqual(mc, 50)
        XCTAssertEqual(sc, 50)
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

    func testManyToMany() async throws {
        try await Prepare {
            Course.self
            Student.self
            PivotSchema<Course, Student>.self
        }

        let science = try await Course.new { new in
            new.name = "science"
        }
        let gym = try await Course.new { new in
            new.name = "gym"
        }


        let student_names = ["jorb", "smalshe", "morp", "blarm"]
        let students = try await student_names.asyncMap { name in
            try await Student.new { new in
                new.name = name
            }
        }
        
        try await students.asyncForEach {
            try await $0.set(\.classes, to: [science])
        }
        let yea = try await students[2].classes.contains(where: { $0.id == science.id })
        XCTAssertTrue(yea)
        try await students.asyncForEach {
            try await $0.remove(from: \.classes, [science])
        }
        let naw = try await students[2].classes.contains(where: { $0.id == science.id })
        XCTAssertFalse(naw)
        
        XCTAssertNotNil(students.first?.id)

        let student_group_a = Array(students[0...1])
        let student_group_b = Array(students[2...3])
        try await science.set(\.students, to: student_group_a + student_group_b)
        try await gym.set(\.students, to: student_group_b)

        let science_only = try await student_group_a.asyncFlatMap { try await $0.classes }
        let allscienc = science_only.flatMap { $0 } .allSatisfy { $0.name == "science" }
        XCTAssert(allscienc == true)

        try await student_group_b.asyncMap { try await $0.classes } .forEach { classes in
            let names = classes.map(\.name)
            XCTAssert(names.contains("gym"))
            XCTAssert(names.contains("science"))
        }
        XCTAssert(!student_group_b.isEmpty)

        let jorb = students[0]
        XCTAssertEqual(try await jorb.classes.count, 1)
        try? await jorb.remove(from: \.classes, [gym])
        XCTAssertEqual(try await jorb.classes.count, 1)
        try? await jorb.remove(from: \.classes, [science])
        XCTAssertEqual(try await jorb.classes.count, 0)
        try? await jorb.add(to: \.classes, [gym, science])
        XCTAssertEqual(try await jorb.classes.count, 2)
        try? await gym.add(to: \.students, [jorb])

        try? await jorb.remove(from: \.classes, [gym, science])
        let a = try await jorb.classes
        XCTAssertEqual(a.count, 0)
        try? await jorb.add(to: \.classes, [gym, science])
        let b = try await jorb.classes
        XCTAssertEqual(b.count, 2)
        try? await jorb.add(to: \.classes, [gym, science])
        let c = try await jorb.classes
        XCTAssertEqual(c.count, 2, "shouldn't duplicate")
    }


    func testDualForeignKey() {
        // dual foreign key not supported
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

    func testUnique() async throws {
        struct Test: Schema {
            let id = PrimaryKey<Int>()

            let favoriteColor = Unique<String>()
            let favoriteNumber = Unique<Int>()
            let favoriteWord = Unique<String>()

            let boring = Column<Int>()
        }
        
        try await Test.prepare(in: db)

        try await Test.new { new in
            new.favoriteColor = "yellow"
            new.favoriteNumber = 8
            new.favoriteWord = "arbledarble"
            new.boring = 111
        }

        let e = await expectError {
            try await Test.new { no in
                no.favoriteColor = "yellow"
                no.favoriteNumber = 4
                no.favoriteWord = "copycats"
                no.boring = 111
            }
        }
        XCTAssert("\(e ?? "")".contains("UNIQUE"))
        XCTAssert("\(e ?? "")".contains("favoriteColor"))

        let n = await expectError {
            try await Test.new { new in
                new.favoriteColor = "orignal-orange"
                new.favoriteNumber = 8
                new.favoriteWord = "yarmal"
                new.boring = 111
            }
        }
        XCTAssert("\(n!)".contains("UNIQUE"))
        XCTAssert("\(n!)".contains("favoriteNumber"))


        let w = await expectError {
            try await Test.new { new in
                new.favoriteColor = "bluelicious"
                new.favoriteNumber = 43
                new.favoriteWord = "arbledarble"
                new.boring = 111
            }
        }
        XCTAssert("\(w!)".contains("UNIQUE"))
        XCTAssert("\(w!)".contains("favoriteWord"))


        try await Test.new { orig in
            orig.favoriteColor = "sknvwob"
            orig.favoriteNumber = 99877
            orig.favoriteWord = "01111110"
            orig.boring = 111
        }

        let all = try await Test.loadAll(in: db)
        XCTAssertEqual(all.count, 2)
    }

    func ignore_too_long_testBlob() async throws {
        try await SQLManager.shared.destroyDatabase()
        let _url = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Image_created_with_a_mobile_phone.png/440px-Image_created_with_a_mobile_phone.png"
        let url = URL(string: _url)!
        let data = try Data(contentsOf: url)

        struct Blobby: Schema {
            let id = PrimaryKey<Int>()
            let img = Column<Data>()
        }

        try await Prepare { Blobby.self }
        
        let blobster = try await Blobby.new { new in
            new.img = data
        }
        XCTAssert(blobster.img == data)

        let fetched = try await Blobby.load(id: blobster.id!.description)
        XCTAssertNotNil(fetched)
        XCTAssert(fetched?.img == data)
        XCTAssertFalse(fetched?.img.isEmpty ?? false)
    }

    func testIncompatiblePropertyWarn() {
        Log.unsafe_collectDebugLogs = true

        struct Foo: Schema {
            var id = PrimaryKey<Int>()
            var ohnooo = "that's not right"
        }

        /// I think we should probably throw or exit on incompatible properties,
        /// but right now just warning
        let _ = Foo.template.columns
        XCTAssert(Log.fetchLogs().contains(where: { $0.contains("incompatible schema property") }))
        XCTAssert(Log.fetchLogs().contains(where: { $0.contains("\(Foo.self)") }))
    }


    func testPrepareAuto() async throws {
        try await Prepare {
            Item.self
            Food.self
            Hero.self
        }


        let prepared = try! await db.unsafe_getAllTables()
        XCTAssert(prepared.contains("item"))
        XCTAssert(prepared.contains("food"))
        XCTAssert(prepared.contains("hero"))
        XCTAssert(prepared.count == 3)

        let w_meta = try await db.unsafe_table_meta("item")
        XCTAssertEqual(w_meta.count, 3)
        XCTAssertEqual(w_meta.map(\.name).sorted(),Item.template.columns.map(\.name).sorted())

        let h_meta = try await db.unsafe_table_meta(Hero.table)
        XCTAssertEqual(h_meta.count, 5)
        let storedNames = h_meta.map(\.name).sorted()
        let expected = Hero.template.columns.map(\.name).sorted()
        XCTAssertEqual(storedNames, expected)
    }

    func testParentChild() async throws {
        try await Prepare {
            Item.self
            Food.self
            Hero.self
        }

        let banana = Food.new()
        XCTAssertFalse(banana.exists)
        banana.health = 50
        banana.id = "banana"
        XCTAssertFalse(banana.exists)
        try await banana.save()
        XCTAssertTrue(banana.exists)

        let lorbo = Hero.new()
        lorbo.name = "lorbo"
        lorbo.age = 234
        let lunch = try await lorbo.lunch
        XCTAssertNil(lunch)
        try await lorbo.save()
        banana.set(\.owner, to: lorbo)
        try await banana.save()
        let _banan = try await lorbo.lunch
        XCTAssertNotNil(_banan)
        
        let one = try await Hero.loadFirst(where: \.name, matches: "lorbo")
        let two = try await Hero.loadFirst(where: \.age, matches: 234)
        XCTAssertNotNil(two)
        XCTAssertNotNil(one)
    }

    func testSave() async throws {
        try await Prepare {
            Item.self
            Food.self
            Hero.self
        }

        let sword = Item.new()
        sword.power = 83
        XCTAssertNil(sword.id)
        try await sword.save()
        XCTAssertFalse(sword.isDirty)
        XCTAssertNotNil(sword.id)

        let hero = Hero.new()
        hero.name = "hiro"
        hero.nickname = "the good one"
        hero.age = 120


        XCTAssertNil(hero.id)
        try await hero.save()
        /// 1 to 1, both have a parent relationship
//        sword.equippedBy = hero
        sword.set(\.equippedBy, to: hero)
//        hero.equipped = sword
        hero.set(\.equipped, to: sword)
        try await hero.save()

        XCTAssertFalse(hero.isDirty)
        XCTAssertNotNil(hero.id)
        
        let _hero = try await Hero.load(id: hero.id!)
        XCTAssertEqual(_hero?.id, hero.id)
        let id = try await _hero?.equipped?.id
        XCTAssertEqual(id, sword.id)
    }

    func testOneToMany() async throws {
        try await Prepare {
            ManyOb.self
            One.self
        }

        let many: [Ref<ManyOb>] = ["a", "b", "c", "d", "e"].map {
            let ref = ManyOb.new()
            ref.name = $0
            return ref
        }

        try await many.save()

        let one = One.new()
        one.name = "blarb"
        try await one.save()

        let oe = try await one.many.isEmpty
        XCTAssert(oe)
        
        try await many.asyncForEach { indi in
//            indi.oneyy = one
            indi.set(\.oneyy, to: one)
            try await indi.save()
        }
        
        let oe2 = try await !one.many.isEmpty
        XCTAssert(oe2)

        let two = try await One.load(id: "1")!
        let tc = try await two.many.count
        let oc = try await one.many.count
        XCTAssert(tc == oc)
    }

    func testMatch() async throws {
        try await Prepare {
            Team.self
            SportsFan.self
        }

        let cats = Team.new()
        cats.name = "the Catz"
        cats.mascot = "cats"
        cats.rating = 5
        try await cats.save()
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

func expectError(test: () async throws -> Void) async -> Error? {
    do {
        try await test()
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
    var name = Column<String>()
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")
    var nemesis = ForeignKey(pointingTo: \Human.id)
}


func XCTAssertNotNil<T>(_ n: T?) {
    // workaround
    if n == nil { XCTFail("Found nil") }
}

func XCTAssertNil<T>(_ n: T?) {
    // workaround
    if n != nil { XCTFail("Found nil") }
}
func XCTAssertEqual<A: Equatable>(_ lhs: A, _ rhs: A) {
    if lhs != rhs { XCTFail("\(lhs) != \(rhs)")}
}
