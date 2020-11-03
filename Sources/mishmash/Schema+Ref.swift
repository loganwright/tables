
/// maybe use some sort of private flag or way to try to enforce early to users
/// that we should control how 'Ref' types are delivered to try to buffer most of the heavy stuff
///
/// This class is used to project schema as real objects and interact with them in a way that
/// is typesafe, and allows more flexibility in terms of database behavior
///
@dynamicMemberLookup
final class Ref<S: Schema> {
    /// a simple backing for now, could maybe be a protocol or sth faster than json
    fileprivate(set) var backing: [String: JSON] {
        didSet { isDirty = true }
    }

    /// whether or not the reference has changed since it came from the database
    fileprivate(set) var isDirty: Bool = false
    /// whether or not the reference has been stored at some point in the database
    /// ~ not fully tested or clean/secure ~
    fileprivate(set) var exists: Bool = false

    /// the database that contains the table for a given schema
    let db: Database

    /// init with the raw backing materials, and a database connection
    init(_ raw: [String: JSON], _ database: Database) {
        self.backing = raw
        self.db = database
    }

    /// this is a new object, restrict this creation
    convenience init(_ database: Database) {
        self.init([:], database)
    }

    // MARK: SubscriptOverloads

    subscript<C: Codable>(dynamicMember key: KeyPath<S, Column<C>>) -> C {
        get {
            let column = S.template[keyPath: key]
            let json = backing[column.key] ?? .null
            return try! C(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            backing[column.key] = newValue.json
        }
    }

    subscript<PK: Codable>(dynamicMember key: KeyPath<S, PrimaryKey<PK>>) -> PK? {
        get {
            let pk = S.template[keyPath: key]
            guard let value = backing[pk.name] else { return nil }
            return try! PK(json: value)
        }
        set {
            let pk = S.template[keyPath: key]
            backing[pk.key] = newValue.json
        }
    }

    // MARK: Relations

    ///
    /// for now, the only relations supported are one-to-one where the link MUST be optional
    /// for one to many relations, it MUST not be optional, and will instead return empty arrays
    ///
    subscript<ForeignTable: Schema>(dynamicMember key: KeyPath<S, ForeignKey<ForeignTable>>) -> Ref<ForeignTable>? {
        get {
            let referencingKey = S.template[keyPath: key]
            guard let referencingValue = backing[referencingKey.name]?.string else { return nil }
            return db.load(id: referencingValue)
        }
        set {
            let relation = S.template[keyPath: key]
            let pointingTo = relation.pointingTo

            guard let foreigner = newValue else {
                self.backing[relation.name] = nil
                return
            }

            guard let foreignIdValue = foreigner.backing[pointingTo.name] else {
                /// would be great if we could attach to the 'Ref' object and somehow trigger an update later after saving
                /// maybe queue things into the database
                fatalError("object: \(foreigner) not ready to be linked.. missing: \(pointingTo.name)")
            }

            // the caller is the referencing body
            // the foreignColumn may or may not be also
            // referencing back in some way
            self.backing[relation.name] = foreignIdValue
        }
    }

    /// a one to many situation, read only
    /// if multiple tables declare a foreign key for our current caller
    /// then the caller can aggregate those values
    ///
    /// the relations tests help with the confusion
    ///
    subscript<Many: Schema>(dynamicMember key: KeyPath<S, ToMany<Many>>) -> [Ref<Many>] {
        let relation = S.template[keyPath: key]
        let pointingTo = relation.pointingTo
        let pointingFrom = relation.pointingFrom
        let id = self.backing[pointingTo.name]
        return db.getAll(where: pointingFrom.name, matches: id)
    }

    /// a one to one relationship where a single object from another table
    /// is referencing to this one
    subscript<One: Schema>(dynamicMember key: KeyPath<S, ToOne<One>>) -> Ref<One>? {
        // we are parent, seeking detached children
        let relation = S.template[keyPath: key]
        let pointingTo = relation.pointingTo
        let pointingFrom = relation.pointingFrom


        guard let id = self.backing[pointingTo.name] else {
            /// we don't have the value that's being pointed to, can't have a child pointing back
            return nil
        }
//        let id = self.backing[pointingTo.name]
        return db.getOne(where: pointingFrom.name, matches: id)
    }

    // MARK: Pivots
    subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> [Ref<R>] {
        get {
            // we're not using the pivot object, could contain some meta info
            let pivot = S.template[keyPath: key]
            let pivotColumn = S.template._pivotIdKey
            let myPrimary = S.template._primaryKeyColumn
            let id = backing[myPrimary.name]

            /// not very optimized fetching one at a time
            let pivots: [Ref<PivotSchema<S, R>>] = db.getAll(where: pivotColumn, matches: id)
            return pivots.map(\.right).compactMap { r in
                guard let r = r else {
                    Log.warn("unexpected nil on pivot, set cascade?")
                    return nil
                }
                return r
            }
        }
        set {
            /// not efficient, and not handling cascades and stuff
            newValue.forEach { incoming in
                let pivot = PivotSchema<S, R>.on(db)
                pivot.left = self
                pivot.right = incoming
                try! pivot.save()
            }
        }
    }
}


/// should this be here?
extension Ref {
    @discardableResult
    func save() throws -> Self {
        db.save(self)
        isDirty = false
        exists = true
        return self
    }
}


///
///
// MARK: Cleanup And move Out

extension SeeQuel: Database {
    func getAll<S: Schema, T: Encodable>(where key: String, matches: T) -> [Ref<S>] {
        let all = try! self.db.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .all(decoding: [String: JSON].self)
            .wait()
        return all.map { Ref($0, self) }
    }

    func getOne<S: Schema, T: Encodable>(where key: String, matches: T) -> Ref<S>? {
        let backing = try! self.db.select()
            .columns(["*"])
            .where(SQLIdentifier(key), .equal, matches)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        return Ref<S>(unwrap, self)
    }

    func orig_getOne<S: Schema, T: Encodable>(where keyPath: KeyPath<S, Column<T>>, matches: T) -> Ref<S>? {
        // let columns = S.template.unsafe_getColumns().map(\.name)
        let column = S.template[keyPath: keyPath]
        let backing = try! self.db.select()
            .columns(["*"])
            .where(SQLIdentifier(column.name), .equal, matches)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        return Ref<S>(unwrap, self)
    }

    func prepare(_ table: Table) throws {
        Log.info("preparing: \(table.name)")

        /// all objects have an id column
        var prepare = self.db.create(table: table.name)

        var constraints: [PostCreateConstraints] = []
        table.columns.forEach { column in
            prepare = prepare.column(column.key, type: column.type, column.constraints)
            if let column = column as? PostCreateConstraints {
                constraints.append(column)
            }
        }

        /// a bit hacky, but need to put foreign keys should be at end of declaration
        constraints.forEach { column in
            prepare = column.add(to: prepare)
        }


        try prepare.run().wait()
    }

    func save(to table: String, _ body: [String : JSON]) {
        try! self.db.insert(into: table)
            .model(body)
            .run()
            .wait()
    }

    func save<S>(_ ref: Ref<S>) where S : Schema {
        guard !ref.exists else {
            update(ref)
            return
        }

        /// if object doesn't exist
        let idKey = S.template.primaryKey
        let needsId = idKey != nil && ref.backing[idKey!.name] == nil
        if needsId, let id = idKey {
            switch id.kind {
            case .uuid:
                /// uuid not auto generated, needs to be made
                ref.backing[id.name] = UUID().json
            case .int:
                // set automatically after save by sql
                break
            }
        }

        guard !ref.backing.isEmpty else { return }
        try! self.db.insert(into: S.table)
            .model(ref.backing)
            .run()
            .wait()

        guard
            needsId,
            let pk = idKey,
            pk.kind == .int
            else { return }
        let id = unsafe_lastInsertedRowId()
        ref.backing[pk.key] = id.json
    }

    func update<S>(_ ref: Ref<S>) where S: Schema {
        guard let primary = ref.primaryKey else { fatalError("can only update with primary keyed objects currently") }
        try! self.db
            .update(S.table)
            .where(primary.name.sqlid, .equal, ref.backing[primary.name])
            .set(model: ref.backing)
            .run()
            .wait()
    }

    private func unsafe_lastInsertedRowId() -> Int {
        let raw = SQLRawExecute("select last_insert_rowid();")
        var id: Int = -1
        try! db.execute(sql: raw) { (row) in
            let raw = try! row.decode(model: [String: Int].self)
            assert(raw.values.count == 1, "unexpected sql rowid response")
            let _id = raw.values.first
            assert(_id != nil, "sql failed to make rowid")
            id = _id!
        } .wait()
        return id
    }

    func load<S>(id: String) -> Ref<S>? where S : Schema {
//        let columns = S.template.unsafe_getColumns().map(\.name)
        guard let pk = S.template.primaryKey?.name else { fatalError("missing primary key") }
        let backing = try! self.db.select()
            .columns(["*"])
            .where(SQLIdentifier(pk), .equal, id)
            .from(S.table)
            .first(decoding: [String: JSON].self)
            .wait()
        guard let unwrap = backing else { return nil }
        // move to higher layer
        let ref = Ref<S>(unwrap, self)
        ref.exists = true
        return ref
    }

    func load<S>(ids: [String]) -> [Ref<S>] where S : Schema {
        replacedDynamically()
    }
}

extension SQLColumn {
    var hasForeignKeyConstraints: Bool {
        return constraints.lazy.compactMap { c in
            if case .foreignKey = c {
                return true
            } else { return nil }
        } .first ?? false
    }
}

import SQLKit
extension String {
    fileprivate var sqlid: SQLIdentifier { .init(self) }
}
extension SeeQuel {
    func unsafe_getAllTables() throws -> [String] {
        struct Table: Decodable {
            let name: String
        }
        let results = try db.select().column("name")
            .from("sqlite_master")
            .where("type", .equal, "table")
            .all(decoding: Table.self)
            .wait()
        return results.map(\.name)
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

    func unsafe_table_meta(_ table: String) throws -> [TableColumnMeta] {
        var meta = [TableColumnMeta]()
        try db.execute(sql: SQLTableSchema(table)) { (row) in
            print("metadata: \(row)")
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

@_functionBuilder
struct Preparer {
    static func buildBlock(_ schema: Schema.Type...) {

    }
}


//let db = TestDB()

struct Human: Schema {
    var id = PrimaryKey<String>()
    var name = Column<String>("name")
    var nickname = Column<String?>("nickname")
    var age = Column<Int>("age")

    // MARK: RELATIONS
    /// one to one
    /// should be able to infer a single id column from type, as well as label,
    /// and have just
    /// `var nemesis = Column<Human?>()`
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

