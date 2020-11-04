


///
///
// MARK: Cleanup And move Out

extension SQLDatabase {
    func getAll<S: Schema>() throws -> [Ref<S>] {
        let all = try self.select()
            .columns(["*"])
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .wait()
        return all.map { Ref($0, self) }
    }

    func getAll<S: Schema, T: Encodable>(where key: String, matches: T) -> [Ref<S>] {
        let all = try! self.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .wait()
        return all.map { Ref($0, self) }
    }

    func getOne<S: Schema, T: Encodable>(where key: String, matches: T) -> Ref<S>? {
        let backing = try! self.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        return Ref<S>(unwrap, self)
    }

    func save(to table: String, _ body: [String : JSON]) {
        try! self.insert(into: table)
            .model(body)
            .run()
            .wait()
    }

    func update<S>(_ ref: Ref<S>) where S: Schema {
        let primary = S.template._primaryKey
        try! self.update(S.table)
            .where(primary.name.sqlid, .equal, ref.backing[primary.name])
            .set(model: ref.backing)
            .run()
            .wait()
    }

    private func unsafe_lastInsertedRowId() throws -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try self.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .wait()
        guard id != -1 else { throw "unset" }
        return id
    }

    func load<S>(id: String) -> Ref<S>? where S : Schema {
        let pk = S.template._primaryKey.name
        let backing = try! self.select()
            .columns(["*"])
            .where(SQLIdentifier(pk), .equal, id)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        // move to higher layer
        let ref = Ref<S>(unwrap, self)
        Log.warn("exists stuff isn't so strong")
//        ref.exists = true
        return ref
    }

    func load<S>(ids: [String]) -> [Ref<S>] where S : Schema {
        alert/
    }
}

@propertyWrapper
struct SQLWrappedLogging<DB: SQLDatabase>: SQLDatabase {
    var logger: Logger { wrappedValue.logger }
    var eventLoop: EventLoop { wrappedValue.eventLoop }
    var dialect: SQLDialect { wrappedValue.dialect }

    let wrappedValue: DB

    init(_ wrapped: DB) {
        self.wrappedValue = wrapped
    }
    func execute(sql query: SQLExpression,
                 _ onRow: @escaping (SQLRow) -> ()) -> EventLoopFuture<Void> {
        print(query)
        return wrappedValue.execute(sql: query, onRow)
    }
}
//
//extension SQLColumn {
//    var hasForeignKeyConstraints: Bool {
//        return constraints.lazy.compactMap { c in
//            if case .foreignKey = c {
//                return true
//            } else { return nil }
//        } .first ?? false
//    }
//}

import SQLKit
extension String {
    fileprivate var sqlid: SQLIdentifier { .init(self) }
}

struct TableColumnMeta: Codable {
    // column_id
    let cid: Int
    let name: String
    let type: String
    let notnull: Bool
    let dflt_value: JSON?
    let pk: Bool
}

private struct Table: Decodable {
    let name: String
}

extension SQLDatabase {
    func unsafe_getAllTables() throws -> [String] {
        let results = try select().column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .wait()
        return results.map(\.name)
    }

    func unsafe_table_meta(_ table: String) throws -> [TableColumnMeta] {
        var meta = [TableColumnMeta]()
        try execute(sql: SQLTableSchema(table)) { (row) in
            let next = try! row.decode(model: TableColumnMeta.self)
            meta.append(next)
        } .wait()
        return meta
    }
}

private struct SQLTableSchema: SQLExpression {
    let table: String

    public init(_ table: String) {
        self.table = table
    }

    public func serialize(to serializer: inout SQLSerializer) {
        serializer.write("pragma table_info(\(table));")
    }
}



struct Human: Schema {
    var id = PrimaryKey<String>()
    var name = Column<String>("name")
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")

    // MARK: RELATIONS
    /// one to one
    /// should be able to infer a single id column from type, as well as label,
    /// and have just
    var nemesis = ForeignKey(pointingTo: \Human.id)
    /// for now taking out, need to address infinite cycle for schema linking to schema
//    var nemesis = Column<Human?>("nemesis", foreignKey: \.id)
//
//    /// one to many
//    var pets = Column<[Pet]>("pets", containsForeignKey: \.id)
//    var friends = Column<[Human]>("friends", containsForeignKey: \.id)
}

extension Schema {
    static func prepare(in db: Database, paths: [PartialKeyPath<Self>]) {
        print("got paths: \(paths)")
        let loaded = paths.map { template[keyPath: $0] }
        print("loadedd: \(loaded)")
    }
}

extension KeyPath where Root: Schema {
    func prepare() {

    }
}

//struct Pet: Schema {
//    var id = IDColumn<Int>()
//    var name = Column<String>("name")
//}
//
//protocol ColumnMeta {
//
//}

private func unsafe_getProperties<R>(template: Ref<R>) -> [(label: String, type: String)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}
private func unsafe_getProperties<S: Schema>(template: S) -> [(label: String, type: String)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}

private func _unsafe_getProperties<S: Schema>(template: S) -> [(label: String, type: String, val: Any)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))", child.value)
    }
}


//@_functionBuilder
//struct PreparationBuilder<S: Schema> {
//    static func buildBlock(_ paths: PartialKeyPath<S>...) {
//        let temp = S.template
//        let loaded = paths.map { temp[keyPath: $0] }
//        print("loaded: \(loaded)")
//    }
//}

//@_functionBuilder
//struct ColumnBuilder<S: Schema> {
//    static func buildBlock(_ paths: KeyPath<S, ColumnBase>...) {
//
//    }
//}
//
//extension Schema {
//    static func prepare(on db: Database, @PreparationBuilder<Self> _ builder: () -> Void) {
//
//    }
//}

func testDatabaseStuff() {
    let huprops = _unsafe_getProperties(template: Human.template)
    print(huprops)
//    Human.prepare(on: db) {
//        \.age
//        \.friends
//        \.name
//        \.pets
//    }
//    Human.prepare(on: db) {
//        \Human.age
//        \Human.friends
//        \Human.name
////        \.age
////        \.friends
////        \.name
////        \.pets
//    }
//
//    Human.prepare(in: db, paths: [\Human.age, \Human.friends, \Human.name, \Human.pets])
//
//    let joe = Ref<Human>(database: db)
//    joe.id = "0"
//    joe.name = "joe"
//    joe.age = 13
//
//    let jan = Ref<Human>(database: db)
//    jan.id = "1"
//    jan.name = "jane"
//    jan.age = 14
//    let frand = jan.nemesis
//    print(frand)
//
//    joe.nemesis = jan
//    jan.nemesis = joe
//
//    joe.friends = [joe, jan]

//    let bobo = Ref<Pet>(db)
//    bobo.name = "bobo"
//    try! bobo.save()
//    let spike = Ref<Pet>(db)
//    spike.name = "spike"
//    try! spike.save()
//    let dolly = Ref<Pet>(db)
//    dolly.name = "dolly"
//    try! dolly.save()
//
////    joe.pets = [bobo, spike, dolly]
////    jan.pets = [bobo]
//
//    print(db.tables[Human.table])
//    try! joe.save()
//    try! jan.save()
//    print(db.tables[Human.table]!)
//    try! joe.save()
//    jan.friend = joe
//    try! jan.save()
//    joe.friend()
//    joe.save()

//    print("Hi: \(joe.friends)")
}

func orig_testDatabaseStuff() {
//    Database.shared.prepare {
//        Pet.self
//        Human.self
//    }

//    Human.prepare {
//        \Human.id
//        \Human._dad
//    }

//    Pet.fetch(where: \.friend, .equals, "joe")
//    newhh.id = ""

//    let new = Ref<Human>()
//    new.id = "asdf"
//    new.age = 13
//    print("Hi: \(new.friend)")
//    let pets = new.pets
//    let a = new.pets
//    let pets = new.relations(matching: \Pet.friend)
//    let parent = new.parent(matching: \._dad) as Ref<Human>
//    new.child(matching: <#T##KeyPath<Schema, Column<Decodable & Encodable>>#>)

//    let a = new.age
//    let asd = unsafe_getProperties(template: new)
//    print(asd)
//    let props = unsafe_getProperties(template: Human.self)
//    print(props)
//    \Human.id
//    let all = Human.template.allKeyPaths
    print()
//    new.name = "blorgop"

//    new.age.
    let ref: Ref<Human>! = nil

//    let a = ref.age
}

import Foundation

//extension Human: KeyPathListable {}
//private func unsafe_getProperties<S: Schema>(template: S.Type) -> [(label: String, type: String)] {
//    Mirror(reflecting: S.template).children.compactMap { child in
//        assert(child.label != nil, "expected a label for template property")
//        guard let label = child.label else { return nil }
//        return (label, "\(type(of: child.value))")
//    }
//}
//
//protocol KeyPathListable: Schema {
//    var allKeyPaths: [String: PartialKeyPath<Self>] { get }
//}
//
//extension KeyPathListable {
//    private subscript(checkedMirrorDescendant key: String) -> Any {
//        return Mirror(reflecting: self).descendant(key)!
//    }
//
//    var allKeyPaths: [String: PartialKeyPath<Self>] {
//        var membersTokeyPaths = [String: PartialKeyPath<Self>]()
//        let mirror = Mirror(reflecting: self)
//        for case (let key?, _) in mirror.children {
//            membersTokeyPaths[key] = \Self.[checkedMirrorDescendant: key] as PartialKeyPath
//        }
//        return membersTokeyPaths
//    }
//}

