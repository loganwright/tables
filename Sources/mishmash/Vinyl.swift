protocol Schema {
    init()
    static var table: String { get }
}

extension Schema {
    // special case, handled by database?
    // will crash if accessed outside of Ref
    var id: Column<String?> { Column("id") }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased() }
}

private var templates: [String: Schema] = [:]
extension Schema {
    static var template: Self {
        if let existing = templates[table] as? Self { return existing }
        let new = Self.init()
        templates[table] = new
        return new
    }
}


// MARK: Reference {
@dynamicMemberLookup
final class Ref<S: Schema> {
    /// leaving this note, don't use the backing, for schema, they should never really be instantiated outside
    /// of the template
    ///
    /// this ensures that schema are only accessed through a Ref<> object, which can then
    /// control access, retain database/connections, mark dirty, etc.
    ///    private var backing: S = .template
    ///
    ///
    /// *****************************



    /// there's maybe a better way to do this that avoids all the json conversions?
    /// maybe a protocol String -> Thing
    private(set) var backing: [String: JSON] {
        didSet { isDirty = true }
    }

    /// whether or not the reference has changed since it came from the database
    fileprivate(set) var isDirty: Bool = false

//    var exists: Bool {
//        /// TODO: we want to more or less set ids automatically?
//        raw["id"] != nil
//    }
    let database: Database

    init(_ raw: [String: JSON] = [:], database: Database) {
        self.backing = raw
        self.database = database
    }

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

    subscript<C: Schema>(dynamicMember key: KeyPath<S, Column<C?>>) -> Ref<C>? {
        get {
            let column = S.template[keyPath: key]
            let id = backing[column.key]?.string ?? ""
            return database.load(id: id)
        }
        set {
            /// maybe just check that it exists?
//            if let new = newValue, new.isDirty { fatalError("must save before associating") }
            let column = S.template[keyPath: key]
            backing[column.key] = newValue?.id.json
        }
    }

//    subscript<Many: Schema>(dynamicMember key: KeyPath<S, OneToMany<Many>>) -> [Ref<Many>] {
//        get {
//            // generalized
//            let oneToMany = S.template[keyPath: key]
////
////            let ids = raw[oneToMany.key] ?? .null
////            return try! C(json: ids)
//        }
//        set {
//            let column = S.template[keyPath: key]
//            newValue
//            raw[column.key] = newValue.json
//
//            // not saved
//            isDirty = true
//        }
//    }

//    subscript<C: ColumnProtocol>(dynamicMember key: KeyPath<S, C>) -> C.Wrapped where C.Wrapped: Schema {
//        get {
//            let column = S.template[keyPath: key]
//            let json = raw[column.key] ?? .null
//            Ref<C.Wrapped>(raw: json.obj!)
//            return try! C.Wrapped(json: json)
//        }
//        set {
//            let column = S.template[keyPath: key]
//            raw[column.key] = newValue.json
//
//            // not saved
//            dirty = true
//        }
//    }
}

@dynamicMemberLookup
final class Ref2<S: Schema> {
//    private(set)
    var raw: [String: JSON]
    private(set) var dirty: Bool = false

    /// todo: pass db stuff, or protocol, or connection?
    init(raw: [String: JSON]) {
        self.raw = raw
    }

    init(new: S) {
        fatalError()
    }

    subscript<C: Codable>(dynamicMember key: KeyPath<S, Column<C>>) -> C {
        get {
            let column = S.template[keyPath: key]
            let json = raw[column.key] ?? .null
            return try! C(json: json)
        }
        set {
            let column = S.template[keyPath: key]
            raw[column.key] = newValue.json

            // not saved
            dirty = true
        }
    }
}

// MARK: Column

@propertyWrapper
struct _Column<C: Codable> {
    let name: String

    var isReady: Bool { return _wrappedValue != nil }

    private var _wrappedValue: C? = nil
    var wrappedValue: C {
        get {
            guard let existing = _wrappedValue else {
                fatalError("value not yet set on column")
            }
            return existing
        }
        set {
            _wrappedValue = newValue
        }
    }

    var projectedValue: Self { self }

    init(_ name: String) {
        self.name = name
        self._wrappedValue = nil
    }

//    init(_ name: String, `default`: C) {
//        self.name = name
//        self._wrappedValue = `default`
//    }

    /// required initializer
    init(wrappedValue: C?, _ name: String) {
        self.name = name
        self._wrappedValue = wrappedValue
    }
}

@propertyWrapper
open class Column<C> {
    let key: String

    var isReady: Bool { return _wrappedValue != nil }

    private var _wrappedValue: C? = nil
    public var wrappedValue: C {
        get {
            print("DOES THIS EVEN RUN, SHOULD IT FATAL ERROR?")
            guard let existing = _wrappedValue else {
                fatalError("value not yet set on column")
            }
            return existing
        }
        set {
            print("DOES THIS EVEN RUN, SHOULD IT FATAL ERROR?")
            _wrappedValue = newValue
        }
    }

    public var projectedValue: Column<C> { self }

    init(_ name: String) {
        self.key = name
        self._wrappedValue = nil
    }

//    init(_ name: String, `default`: C) {
//        self.name = name
//        self._wrappedValue = `default`
//    }

    /// required initializer
    init(wrappedValue: C?, _ name: String) {
        self.key = name
        self._wrappedValue = wrappedValue
    }
}


enum DBOperator {
    case equals
}

extension Schema {
//    static func fetch<T>(where: KeyPath<Self, T>)
//    static func fetch(id: String) -> Ref<Self> {
//        fatalError()
//    }

    static func fetch<T>(where: KeyPath<Self, Column<T>>, _ op: DBOperator, _ expectation: T) -> Ref<Self> {
        fatalError()
    }
}

@propertyWrapper
struct _Link<Base: Schema, Node: Schema> {
//    let key: PartialKeyPath<To>
//    let asdf: KeyPath<
    var wrappedValue: Ref<Node> {
        get {
            fatalError()
        }
    }

    init<A, B>(where parent: KeyPath<Base, Column<A>>, equals child: KeyPath<Node, Column<B>>) {
//        self.key = key
//        fatalError()
    }
}

//@propertyWrapper
//struct Relation<Base: Schema, Node: Schema> {
////    let key: PartialKeyPath<To>
////    let asdf: KeyPath<
//    var wrappedValue: Ref<Node> {
//        get {
//            fatalError()
//        }
//    }
//
//    init<A, B>(where parent: KeyPath<Base, Column<A>>, equals child: KeyPath<Node, Column<B>>) {
////        self.key = key
////        fatalError()
//    }
//}


//@propertyWrapper
//struct Link<Left: Schema, Right: Schema> {
////    let left: Column
////    let key: PartialKeyPath<To>
////    let asdf: KeyPath<
//    var wrappedValue: Ref<Right> {
//        get {
//            fatalError()
////            Right.fetch(where: T##KeyPath<Schema, Column<Decodable & Encodable>>, T##op: DBOperator##DBOperator, T##expectation: Decodable & Encodable##Decodable & Encodable)
//        }
//    }
//
//    init<A, B>(where left: KeyPath<Left, Column<A>>, equals right: KeyPath<Right, Column<B>>) {
//
//        let l = Left.template[keyPath: left]
//        let r = Right.template[keyPath: right]
////        Right.fetch(where: left, .equals, right)
////        self.key = key
////        fatalError()
//    }
//}

extension Ref {
    func loadRelation<R: Schema>(where l: KeyPath<S, Column<String>>, equals r: KeyPath<R, Column<String>>) -> Ref<R> {
        fatalError()
    }
}

@propertyWrapper
struct Nested<S: Schema> {
    var wrappedValue: S { fatalError() }
}

protocol ColumnProtocol {
    associatedtype Wrapped
    var key: String { get }
}

//extension Column: ColumnProtocol {
//    typealias Wrapped = C
//}


extension OneToMany: ColumnProtocol {
    typealias Wrapped = S
}

final class Box<T> {
    var boxed: T

    init(_ boxed: T) {
        self.boxed = boxed
    }
}


//struct OneToMany<S: Schema> {
//
//    var wrappedValue: [Ref<S>] {
//        fatalError()
//    }
//
//    init(_ key: String) {
//
//    }
//}
var sneaky: [String: Any] = [:]


extension Ref {
    func save() throws {
        database.save(self)
    }
}

extension Database {

}

protocol Database {
    func save<S>(_ ref: Ref<S>)
    func load<S>(id: String) -> Ref<S>?
}

import Foundation
final class TestDB: Database {
    var tables: [String: [String: [String: JSON]]] = [:]

    func save<S>(_ ref: Ref<S>) {
        var table = tables[S.table] ?? [:]
        let id = ref.id ?? UUID().uuidString
        table[id] = ref.backing
        tables[S.table] = table
    }

    func load<S>(id: String) -> Ref<S>? where S : Schema {
        guard let table = tables[S.table] else { return nil }
        guard let backing = table[id] else { return nil }
        return Ref(backing, database: self)
    }
}

extension Schema {
//    static func `where`<T>(_ kp: KeyPath<Self, Column<T>>, equals: T) -> Ref<Self> {
//        fatalError()
//    }

    static func `where`<T>(_ kp: KeyPath<Self, Column<T>>, in: [T]) -> [Ref<Self>] {
        fatalError()
    }
}

//extension Array where Element == Bool {
//    var hasUnsavedObjects
//}

@propertyWrapper
struct OneToMany<S: Schema> {
    let key: String
    private var ids: [String] = []
    private let _cache: Box<[Ref<S>]> = .init([])

    var wrappedValue: [Ref<S>] {
        get {
            guard _cache.boxed.isEmpty else { return _cache.boxed }
//            Log.warn("should seek to make this more async somehow")
            _cache.boxed = S.where(\.id, in: ids)
            return _cache.boxed
        }
        set {
            print("*** SHOULD I SAVE HERE? ***")
            /// for now, objects should be saved first
            let hasUnsavedItems = newValue
                .map(\.isDirty)
                .reduce(false, { $0 || $1 })
            guard !hasUnsavedItems else {
                fatalError("can not set unsaved many relations")
            }
            ids = newValue.compactMap(\.id)
            _cache.boxed = newValue
        }
    }

    init(_ key: String) {
        self.key = key
    }
}


struct Human: Schema {
//    @Column("Foo") var foo: String = ""

//    var name = Column("name", default: "")
    var name = Column<String>("name")
    var age = Column<Int>("age")

    var friend = Column<Human?>("friend")
    var pets = OneToMany<Pet>("pets")
}

struct Pet: Schema {
    var friend = Column<String>("friend")
}

extension Ref {
    /// one to many
    func relations<P: Schema, C>(matching: KeyPath<P, Column<C>>) -> [Ref<P>] {
        fatalError()
    }

    /// one to one
    func parent<P: Schema, C>(matching: KeyPath<S, Column<C>>) -> Ref<P> {
        fatalError()
    }

    /// one to one
    func child<P: Schema, C>(matching: KeyPath<P, Column<C>>) -> Ref<P> {
        fatalError()
    }
}

private func unsafe_getProperties<R>(template: Ref<R>) -> [(label: String, type: String)] {
    Mirror(reflecting: template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}

@_functionBuilder
struct Preparer {
    static func buildBlock(_ schema: Schema.Type...) {

    }
}

//@dynamicMemberLookup
//struct Database {
//    static let shared = Database()
//
//    func prepare(@Preparer _ builder: () -> Void) {
//        builder()
//    }
//
////    subc
//}


let db = TestDB()

func testDatabaseStuff() {
    let joe = Ref<Human>(database: db)
    joe.id = "0"
    joe.name = "joe"
    joe.age = 13

    let jan = Ref<Human>(database: db)
    jan.id = "1"
    jan.name = "jane"
    jan.age = 14
    let frand = jan.friend
    print(frand)

    joe.friend = jan
    jan.friend = joe

    print(db.tables[Human.table])
    try! joe.save()
    try! jan.save()
    print(db.tables[Human.table]!)
//    try! joe.save()
//    jan.friend = joe
//    try! jan.save()
//    joe.friend()
//    joe.save()

    print("Hi: \(joe.friend!)")
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

    Pet.fetch(where: \.friend, .equals, "joe")
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
    let all = Human.template.allKeyPaths
    print()
//    new.name = "blorgop"

//    new.age.
    let ref: Ref<Human>! = nil

//    let a = ref.age
}

extension Human: KeyPathListable {}
private func unsafe_getProperties<S: Schema>(template: S.Type) -> [(label: String, type: String)] {
    Mirror(reflecting: S.template).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        guard let label = child.label else { return nil }
        return (label, "\(type(of: child.value))")
    }
}

protocol KeyPathListable: Schema {
    var allKeyPaths: [String: PartialKeyPath<Self>] { get }
}

extension KeyPathListable {
    private subscript(checkedMirrorDescendant key: String) -> Any {
        return Mirror(reflecting: self).descendant(key)!
    }

    var allKeyPaths: [String: PartialKeyPath<Self>] {
        var membersTokeyPaths = [String: PartialKeyPath<Self>]()
        let mirror = Mirror(reflecting: self)
        for case (let key?, _) in mirror.children {
            membersTokeyPaths[key] = \Self.[checkedMirrorDescendant: key] as PartialKeyPath
        }
        return membersTokeyPaths
    }
}
