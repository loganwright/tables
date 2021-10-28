import XCTest
@testable import Tables
import Commons
import Endpoints

class CompositeKeyTests: SieqlTersts {

    struct Team: Schema {
        let id = PrimaryKey<Int>()

        /// unique column is not same as unique row
        let name = Unique<String>()
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

    func testUniqueGroup() async throws {
        print("0")
        try! await db.prepare {
            Team.self
            Player.self
        }
        print("1")
        let teams = try! await Team.make(
            on: db,
            columns: \.name.root, \.id.root,
            rows: [
                ["cats", 921],
                ["bears", 12],
                ["barvos", 123],
                ["snardies", 3829384]
            ]
        )
        print("2")
        XCTAssertEqual(teams.count, 4)

        let joe = try! await Player.new(referencing: db) { joe in
//            joe.team = teams[0]
            joe.set(\.team, to: teams[0])
            joe.jerseyNumber = 13
        }

        let jan = try! await Player.new(referencing: db) { jan in
            jan.set(\.team, to: teams[0])
//            jan.team = teams[0]
            jan.jerseyNumber = 84
        }

        let ohno = try? await Player.new(referencing: db) { ohno in
//            ohno.team = teams[0]
            ohno.set(\.team, to: teams[0])
            ohno.jerseyNumber = 84
        }
        XCTAssertNil(ohno)

        let pass = try await joe.team?.name == jan.team?.name
        XCTAssert(pass)
        let team = try await joe.team
        XCTAssertNotNil(team)
    }


    struct Guest: Schema {
        let firstName = Column<String>()
        let lastName = Column<String>()
        let email = Column<String>()


        /// I think there's better fits for this in practice, but I couldn't think of an
        let tableConstraints = TableConstraints {
            PrimaryKeyGroup(\.firstName, \.lastName, \.email)
        }
    }

    struct Reservation: Schema {
        let id = PrimaryKey<Int>()

        let guestFirstName = Column<String>()
        let guestLastName = Column<String>()
        let guestEmail = Column<String>()

        /// note,
        let tableConstraints = TableConstraints {
            ForeignKeyGroup(\.guestFirstName, \.guestLastName, \.guestEmail,
                            referencing: \Guest.firstName, \Guest.lastName, \Guest.email)
        }
    }

    ///
    ///
    ///
    ///   NOTE THIS ISN'T THE BEST API YET, I'M JUST VERIFYING FUNCTIONALITY
    ///   IT'S NOT THE CORE USE CASE TO USE MULTIPLE PRIMARY KEYS RHIS WAY
    ///   SO I'M JUST MAKING SURE IT'S POSSIBLE
    ///
    ///   FUTURE API WILL EXPOSE A SINGLE PRIMARY/FOREIGN KEY RELATIONSHIP
    ///   AND MAP THE GROUPED KEYS UNDER THE HOOD AS WITH CORE API
    ///
    ///
    func testMultipleForeignAndPrimaryKeys() async {
        try! await db.prepare {
            Guest.self
            Reservation.self
        }

        let guests = try! await Guest.make(
            on: db,
            columns: \.firstName, \.lastName, \.email,
            rows: [
                ["jorny", "blorny", "sadlkfj@123.co"],
                ["vlorb", "sleojj", "snclw@sd.co"],
                ["slarni", "kadorpin", "slar.kad@garboogle.come"]
            ]
        )

        let reservations = try! await Reservation.make(
            on: db,
            columns: \.guestFirstName, \.guestLastName, \.guestEmail,
            rows: guests.map({[$0.firstName, $0.lastName, $0.email]})
        )

        zip(guests, reservations).forEach { guest, reservation in
            XCTAssertEqual(guest.email, reservation.guestEmail)
            XCTAssertEqual(guest.firstName, reservation.guestFirstName)
            XCTAssertEqual(guest.lastName, reservation.guestLastName)
        }


        let guest = guests[2]
        let check = try! await db.fetch(Reservation.self,
                                  where: [
                                    \.guestEmail.root,
                                    \.guestFirstName.root,
                                    \.guestLastName.root],
                             equal: [guest.email, guest.firstName, guest.lastName])
        XCTAssertEqual(check.count, 1)
    }
}


struct Critter: Schema {
    var id = PrimaryKey<String>()
    var name = Column<String>("name")
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")
    var nemesis = ForeignKey(pointingTo: \Hero.id)
}
