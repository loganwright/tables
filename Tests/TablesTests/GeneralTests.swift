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

struct FlatMap<A: Decodable, B: Decodable>: Decodable {
    let a: A
    let b: B
    
    init(from decoder: Decoder) throws {
        self.a = try A(from: decoder)
        self.b = try B(from: decoder)
    }
}


class JoinTests: XCTestCase {
    struct Car: Schema {
        let id = PrimaryKey<Int>()
        let color = Column<String>()
    }

    struct User: Schema {
        let id = PrimaryKey<String>()
        var car = ForeignKey<Car>(pointingTo: \.id)
        let foo = Column<String>()
    }
    
    @TablesActor
    func testJoin() async throws {
        try Prepare {
            Car.self
            User.self
        }

        
        let car = Car.new()
        car.color = "#aaa832"
        try car.save()
        
        let rob = User.new()
        
    }
}

///
///
///
///
///
@TablesActor
final class RelationTests : SieqlTersts {

    struct Car: Schema {
        let id = PrimaryKey<Int>()
        let color = Column<String>()
    }

    struct User: Schema {
        let id = PrimaryKey<String>()
        var car = ForeignKey<Car>(pointingTo: \.id)
        let foo = Column<String>()
    }

    func testForeignKey() async throws {
        try Prepare {
            Car.self
            User.self
        }

        let car = Car.new()
        car.color = "#aaa832"
        XCTAssertNil(car.id, "car not yet created")
        try car.save()
        XCTAssertNotNil(car.id, "testing an option to initialize this way.. not done")

        let user = User.new()
        try user.car = car
        user.foo = "hootie"
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

    @TablesActor
    func testOneToManyKey() async throws {
        try Prepare {
            Author.self
            Book.self
        }

        let author = Author.new()
        author.name = "hughes"
        try author.save()

        let booktitless = ["a", "b", "c", "d"]
        let books = try booktitless.map { title -> Ref<Book> in
            let book = Book.new()
            book.title = title
            book.author = author
            try book.save()
            return book
        }
        
        XCTAssert(books.count == booktitless.count)
        let ids = books.compactMap { $0.author?.id }
        XCTAssert(Set(ids).count == 1)
        XCTAssert(ids.count == booktitless.count)
        let pass = try author.books.count == booktitless.count
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
        try Prepare {
            Person.self
            Phone.self
        }
        
        let person = Person.new()
        try person.save()
        
        let phone = Phone.new()
        phone.owner = person
        //        phone.set(\.owner, to: person)
        //        phone.owner = person
        try phone.save()
        
        let ownerId = phone.owner?.id
        XCTAssertEqual(ownerId, person.id)
        XCTAssertNotNil(try person.phone)
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
        try Prepare {
            Moon.self
            Sun.self
            Star.self
        }

        let moon = Moon.new()
        try moon.save()
        let nosun = moon.sunFriend
        XCTAssertNil(nosun)

        let sun = Sun.new()
        try sun.save()

        moon.sunFriend = sun
//        moon.set(\.sunFriend, to: sun)
//        moon.sunFriend = sun
        XCTAssertNotNil(try moon.sunFriend)
        /// will still be `nil` because we dno't have a child relationship
        /// a child will look in the db for matching keys
        /// a separate foreignKey will be as it is
        XCTAssertNil(try sun.moonFriend)


//        sun.moonFriend = moon
        try sun.moonFriend = moon
//        sun.set(\.moonFriend, to: moon)
        try sun.save()
        try moon.save()

        XCTAssertNotNil(moon.sunFriend)
        XCTAssertNotNil(sun.moonFriend)
        let a = try await moon.starFriends.isEmpty
        let b = try await sun.starFriends.isEmpty
        XCTAssert(a)
        XCTAssert(b)

        let fifty = 50
        for int in (1...fifty) {
//        try (1...fifty).forEach { int in
            let star = Star.new()
            star.id = int
            star.sunFriend = sun
            star.moonFriend = moon
//            star.set(\.sunFriend, to: sun)
//            star.sunFriend = sun
//            star.set(\.moonFriend, to: moon)
//            star.moonFriend = moon
            print("saving star..")
            try star.save()
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

        let science = Course.new()
        science.name = "science"
        try await science.save()
        let gym = Course.new()
        gym.name = "gym"
        try await gym.save()
        


        let student_names = ["jorb", "smalshe", "morp", "blarm"]
        let students = try await student_names.asyncMap { name -> Ref<Student> in
            let student = Student.new()
            student.name = name
            try await student.save()
            return student
        }
        
        try await students.asyncForEach {
            try await $0.classes = [science]
        }
        let yea = try await students[2].classes.contains(where: { $0.id == science.id })
        XCTAssertTrue(yea)
        try students.forEach {
            try $0.remove(from: \.classes, [science])
        }
        let naw = try await students[2].classes.contains(where: { $0.id == science.id })
        XCTAssertFalse(naw)
        
        XCTAssertNotNil(students.first?.id)

        let student_group_a = Array(students[0...1])
        let student_group_b = Array(students[2...3])
        science.students = student_group_a + student_group_b
        gym.students = student_group_b
//        try await science.set(\.students, to: student_group_a + student_group_b)
//        try await gym.set(\.students, to: student_group_b)

        let science_only = try student_group_a.compactMap { $0.classes }
        let allscienc = science_only.flatMap { $0 } .allSatisfy { $0.name == "science" }
        XCTAssert(allscienc == true)

        try await student_group_b.map { $0.classes } .forEach { classes in
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
        // dual foreign key not supported
    }
}

@TablesActor
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

        let new = Test.new()
        new.favoriteColor = "yellow"
        new.favoriteNumber = 8
        new.favoriteWord = "arbledarble"
        new.boring = 111
        try await new.save()

        let e = await expectError {
            let no = Test.new()
            no.favoriteColor = "yellow"
            no.favoriteNumber = 4
            no.favoriteWord = "copycats"
            no.boring = 111
            try await no.save()
        }
        XCTAssert("\(e ?? "")".contains("UNIQUE"))
        XCTAssert("\(e ?? "")".contains("favoriteColor"))

        let n = await expectError {
            let new = Test.new()
            new.favoriteColor = "orignal-orange"
            new.favoriteNumber = 8
            new.favoriteWord = "yarmal"
            new.boring = 111
            try await new.save()
        }
        XCTAssert("\(n!)".contains("UNIQUE"))
        XCTAssert("\(n!)".contains("favoriteNumber"))


        let w = await expectError {
            let new = Test.new()
            new.favoriteColor = "bluelicious"
            new.favoriteNumber = 43
            new.favoriteWord = "arbledarble"
            new.boring = 111
            try await new.save()
        }
        XCTAssert("\(w!)".contains("UNIQUE"))
        XCTAssert("\(w!)".contains("favoriteWord"))


        let orig = Test.new()
        orig.favoriteColor = "sknvwob"
        orig.favoriteNumber = 99877
        orig.favoriteWord = "01111110"
        orig.boring = 111
        try await orig.save()

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
        
        let blobster = Blobby.new()
        blobster.img = data
        try await blobster.save()
        XCTAssert(blobster.img == data)

        let fetched = try await Blobby.load(id: blobster.id!.description)
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
        XCTAssert(Log.memoryLogs.contains(where: { $0.msg.contains("incompatible schema property") }))
        XCTAssert(Log.memoryLogs.contains(where: { $0.msg.contains("\(Foo.self)") }))
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
        try Prepare {
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
        let lunch = try lorbo.lunch
        XCTAssertNil(lunch)
        try lorbo.save()
        banana.owner = lorbo
        try banana.save()
        let _banan = try lorbo.lunch
        XCTAssertNotNil(_banan)
        
        let one = try Hero.loadFirst(where: \.name, matches: "lorbo")
        let two = try Hero.loadFirst(where: \.age, matches: 234)
        XCTAssertNotNil(two)
        XCTAssertNotNil(one)
    }

    func testSave() async throws {
        try Prepare {
            Item.self
            Food.self
            Hero.self
        }

        let sword = Item.new()
        sword.power = 83
        XCTAssertNil(sword.id)
        try sword.save()
        XCTAssertFalse(sword.isDirty)
        XCTAssertNotNil(sword.id)

        let hero = Hero.new()
        hero.name = "hiro"
        hero.nickname = "the good one"
        hero.age = 120


        XCTAssertNil(hero.id)
        try hero.save()
        /// 1 to 1, both have a parent relationship
//        sword.equippedBy = hero
        try sword.equippedBy = hero
        // try sword.equippedBy.set { hero }
//        sword.set(\.equippedBy, to: hero)
//        hero.equipped = sword
        try hero.equipped = sword
//        hero.set(\.equipped, to: sword)
        try await hero.save()
        try await sword.save()

        XCTAssertFalse(hero.isDirty)
        XCTAssertNotNil(hero.id)
        
        let fetched = try await Item.loadFirst(where: \.power, matches: 83)
        let _ = try await fetched?.equippedBy
        try await XCTAssertEqual(fetched?.equippedBy?.id, hero.id)
        
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
            try indi.oneyy = one
//            indi.set(\.oneyy, to: one)
            try indi.save()
        }
        
        let oe2 = try !one.many.isEmpty
        XCTAssert(oe2)

        let two = try One.load(id: "1")!
        let tc = try two.many.count
        let oc = try one.many.count
        XCTAssert(tc == oc)
    }

    func testMatch() async throws {
        try Prepare {
            Team.self
            SportsFan.self
        }

        let cats = Team.new()
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

@discardableResult
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
