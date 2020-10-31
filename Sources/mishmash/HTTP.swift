import Foundation

func setter<Object: AnyObject, Value>(
    for object: Object,
    keyPath: ReferenceWritableKeyPath<Object, Value>
) -> (Value) -> Void {
    return { [weak object] value in
        object?[keyPath: keyPath] = value
    }
}

func test_setter<Object, Value>(
    for object: inout Object,
    keyPath: WritableKeyPath<Object, Value>
) -> (Value) -> Void {
    return { [object] value in
        var object = object
        object[keyPath: keyPath] = value
    }
}


struct Valued {
    var id: String
}

final class Reffed {
    var id: String
    init(id: String) {
        self.id = id
    }
}

@dynamicMemberLookup
struct Dynamic {
    subscript(dynamicMember key: String) -> Int? {
        get {
            0
        }
        set {
            fatalError()
        }
    }
}

@dynamicMemberLookup
struct Group<A, B> {
    let a: A
    let b: B

    subscript<T>(dynamicMember keyPath: KeyPath<A, T>) -> T {
        return a[keyPath: keyPath]
    }
    subscript<T>(dynamicMember keyPath: KeyPath<B, T>) -> T {
        return b[keyPath: keyPath]
    }
}

@dynamicMemberLookup
struct Aggregate<A, B> {
    let a: A
    let b: B

    subscript<T>(dynamicMember keyPath: KeyPath<A, T>) -> T {
        return a[keyPath: keyPath]
    }
    subscript<T>(dynamicMember keyPath: KeyPath<B, T>) -> T {
        return b[keyPath: keyPath]
    }
}

struct GroupA {
    let a: Int
}
struct GroupC {
    let c: Int
}
struct GroupB {
    let b: Int
}

func groooups() {
    let ab: Group<GroupA, GroupB>! = nil
    let abc: Group<Group<GroupA, GroupB>, GroupC>! = nil
//    abc.
}

struct Blog {
    let title: String
    let url: URL
}

@dynamicMemberLookup
struct Blogger {
    let name: String
    let blog: Blog

    subscript<T>(dynamicMember keyPath: KeyPath<Blog, T>) -> T {
        return blog[keyPath: keyPath]
    }
}

extension Encodable {
    var js: Data {
        try! JSONEncoder().encode(self)
    }
}

@_functionBuilder
struct SerializerBuilder<Root> {
//    static func buildBlock<B: Encodable>(_ paths: KeyPath<Root, B>) -> Serializer<Root> {
//        fatalError()
////        return .init(paths: paths)
//    }

    static func buildBlock(_ paths: KeyPath<Root, Data>...) -> Serializer<Root> {
        fatalError()
//        return .init(paths: paths)
    }
//    static func buildBlock(_ paths: CanEncode...) -> Serializer<Root> {
//        fatalError()
////        return .init(paths: paths)
//    }
}

struct Serializer<T> {
    private let operations: [(T) -> Data]
    init(@SerializerBuilder<T> _ make: () -> Serializer<T>) {
        self = make()
    }
}


@_functionBuilder
struct alt_SerializerBuilder<Root> {
    static func buildBlock(_ path: PartialKeyPath<Root>) -> alt_serializer<Root> {
        fatalError()
//        return .init(paths: paths)
    }
}

struct alt_serializer<T> {
//    private let operations: [(T) -> Data]
    init(_ ob: T, @alt_SerializerBuilder<T> _ make: () -> alt_serializer<T>) {
        fatalError()
    }
}

struct Instruction<Root, T> {
    let key: String
    let path: KeyPath<Root, T>
}

//extension KeyPath {
//    var extractor: (Root) -> Value {
//
//    }
//}

struct Reader<T> {
    let paths: [(T) -> Data]

    func read(_ ob: T) -> String {
//        let values = paths.map { ob[keyPath: $0] }
//        let encoder = JSONEncoder()
//        let encoded = values.map(encoder.encode)
        fatalError()
//        try! JSONEncoder().encode(values)
    }
}

struct Alien: Codable {
    let name: String
    let age: Int
}

extension Alien {
    func withJustPath<T>(_ asdf: () -> KeyPath<Alien, T>) {

    }
    func serialize(@alt_SerializerBuilder<Self> _ foo: () -> alt_serializer<Self>) {
        fatalError()
    }
}

protocol CanEncode {
    associatedtype Root
//    func encoded(with obj)
}

extension KeyPath: CanEncode where Root == Alien, Value: Encodable {

}

extension Alien {
    func iuiii(_ adf: AnyKeyPath...) {

    }
    func foo(_ asdf: KeyPath<Alien, Encodable>...) {
//        let a: [Encodable] = []
    }

    func asdf<C: CanEncode>(_ asdf: C...) where C.Root == Self {

    }


    func gen<A: Encodable>(_ asdf: KeyPath<Alien, A>) {

    }
    func gen<A: Encodable, B: Encodable>(_ a: KeyPath<Alien, A>, _ b: KeyPath<Alien, B>) {

    }
}

//let global_json_encoder = JSONEncoder
extension Encodable {
    func encoded() -> Data {
        let encoder = JSONEncoder()
        do {
            return try encoder.encode(self)
        } catch { fatalError() }
    }
}

struct Key<A> {
    let key: String
    fileprivate let getter: (A) -> Data
    init<B: Encodable>(_ key: String, _ path: KeyPath<A, B>) {
        self.key = key
        self.getter = { obj in
            obj[keyPath: path].encoded()
        }
    }
}


/// just testing around to make a basic container
/// but we can pass all the variables to access it directly
/// in a typesafe way
@dynamicMemberLookup
struct Wrapper<T> {
    let wrappedValue: T
    init(_ wrapped: T) {
        self.wrappedValue = wrapped
    }

    subscript<U>(dynamicMember keyPath: KeyPath<T, U>) -> U {
        return wrappedValue[keyPath: keyPath]
    }
}

@dynamicMemberLookup
struct DynamicFuncs {
    subscript(dynamicMember key: String) -> (String) -> () {
        get { return { print("hi \($0)") } }
    }
}

@_functionBuilder
struct KeyBuilder<Root> {
    static func buildBlock(_ keys: Key<Root>...) -> [Key<Root>] {
        return keys
    }
}

struct EncodingStrategy<Root> {
    private let schema: [Key<Root>]
    init(@KeyBuilder<Root> _ build: () -> [Key<Root>]) {
        self.schema = build()
    }

    func encode(_ obj: Root) -> [String: Data] {
        var data = [String: Data]()
        schema.forEach { item in
            data[item.key] = item.getter(obj)
        }
        return data
    }
}

extension Alien {

}

struct Tester {
    let name: Wrapper<String>
}

@dynamicMemberLookup
final class Fuzzy {
    private var backing: [String: String] = [:]
    subscript(dynamicMember key: String) -> String? {
        get {
            return backing[key]
        }
        set {
            backing[key] = newValue
        }
    }
}

protocol BlobTemplate {}

open class BlobBase {
    let backing: [String: Any]
    init(_ raw: [String: Any]) {
        self.backing = raw
    }
}

extension Encodable {
    func seePaths(_ paths: [PartialKeyPath<Self>]) {

    }
}

//@dynamicMemberLookup
//struct Blob {
//    subscript<T>(dynamicMember keyPath: KeyPath<BlobBinding, T>) -> T {
////        return b[keyPath: keyPath]
//        fatalError()
//    }
//}

extension Fuzzy {
    func canThisWork(with arg: WritableKeyPath<Fuzzy, String?>) {
        print(self[keyPath: arg])
    }
}

struct Baa: Codable {
    let id: String

    func asdf() {
//        CodingKeys(stringValue:
    }
}


extension Baa {
    func paaarths<A>(_ a: KeyPath<Self, A>) {

    }
}

@_functionBuilder
struct _KeyBuilder<Root> {
    static func buildBlock<A>(_ a: KeyPath<Root, A>) -> [String] {
        fatalError()
    }
    static func buildBlock<A, B>(_ a: KeyPath<Root, A>, _ b: KeyPath<Root, B>) -> [String] {
        fatalError()
    }
}

extension Alien {
    func go(@_KeyBuilder<Alien> _ build: () -> [String]) {

    }
}

struct _EncodingStrategy<Root> {
    private let schema: [Key<Root>]
    init(@KeyBuilder<Root> _ build: () -> [Key<Root>]) {
        self.schema = build()
    }

    func encode(_ obj: Root) -> [String: Data] {
        var data = [String: Data]()
        schema.forEach { item in
            data[item.key] = item.getter(obj)
        }
        return data
    }
}

struct PairLeft {
    let id: String
}

@propertyWrapper
struct Clamp<N: Comparable> {
    var wrappedValue: N
    init(low: Int, high: Int, _ wrappedValue: N) {
        print("not actually clamping")
//        self.wrappedValue = wrappedValue
        fatalError()
    }
}


@propertyWrapper
struct TestProp<T> {
    let key: String
    var backing: T? = nil
    var wrappedValue: T {
        get { return backing! }
        set { backing = newValue }
    }

    var projectedValue: String { return "hi, I don't get it" }
}

struct Oaavnw {
    @TestProp(key: "hiya") private(set) var count: Int

    init(count: Int) {
        self.count = count
    }

    func ooo() {
        self._count
    }
}

struct A<Root> {
    let key: String
    let path: PartialKeyPath<Root>
}

@_functionBuilder
struct SchemaBuilder<Root> {
//    static func buildBlock(_ paths: PartialKeyPath<Root>) -> [Int] {
//        fatalError()
//    }

    static func buildBlock(_ paths: KeyPath<Root, Data>) -> [Int] {
        fatalError()
    }

    static func buildBlock(_ paths: Write<Root>) -> [Int] {
        fatalError()
    }

    static func buildBlock(_ paths: (String, PartialKeyPath<Root>)...) -> [Int] {
        fatalError()
    }

    static func buildBlock(_ paths: SchemaEntry<Root>...) -> [Int] {
        fatalError()
    }

}

struct Write<Root> {
    init<T>(key: String, _ path: KeyPath<Root, T>) {

    }
}

extension Encodable {
    func encodeSchema(@SchemaBuilder<Self> _ builder: () -> [Int]) {

    }

    static func encodeSchema(@SchemaBuilder<Self> _ builder: () -> [Int]) {

    }
}

struct Obbi: Codable {
    let name: String
    let ownsShirt: Bool
}

struct SchemaEntry<Root> {
    init(key: String, _ path: PartialKeyPath<Root>) {

    }
}

extension Decodable where Self: Encodable {
    static func key<Value>(_ k: String, _ path: KeyPath<Self, Value>) -> (String, PartialKeyPath<Self>) {
        return (k, path)
    }
}

protocol GeneralKeys {
    var createdAt: Date { get set }
}

@dynamicMemberLookup
struct Node<KeyedBy> {
//    var backing
    subscript<V>(dynamicMember key: KeyPath<KeyedBy, V>) -> V {
        fatalError()
    }
}

extension GeneralKeys {}

func asdfsadfsd() {

    var node = Node<GeneralKeys>()
    node.createdAt

    let ob = Obbi(name: "obbbbi", ownsShirt: true)
//    ob.encodeSchema {
//        \Obbi.name
//    }

    let aob = \Obbi.self
    aob.appending(path: \.name)
    Obbi.encodeSchema {
        \Obbi.name.js
//        Write(key: "name", \.name)

    }

    Obbi.encodeSchema {
        Obbi.key("asfd", \.ownsShirt)
    }

    Obbi.encodeSchema {
        SchemaEntry(key: "shirt", \Obbi.ownsShirt)
    }

    let a = Obbi.key("asfd", \.ownsShirt)


    let o = Oaavnw(count: 10)
    print(o.count)
    print(o.$count)
    print(\Oaavnw.$count)
    let y = \Oaavnw.count
    print(y)
    print()
//    let l = PairLeft(id: "left")
//    let r = PairRight(id: "right")
//    let l_k: AnyKeyPath = \PairLeft.id
//    let r_k: AnyKeyPath = \PairRight.id
//    let l_from_r = l[keyPath: r_k]
//    let r_from_1 = l[keyPath: r_k]
//    keypathlistable()
    let basb = Baa(id: "sadf")
    basb.paaarths(\.id)
//    JSONEncoder().keyEncodingStrategy = .custom({ input in
//        input == \Baa.id
//    })

    let idKey = \Baa.id
    let mir = Mirror(reflecting: \Baa.self)
    let found = mir.children.first {
        print("value is: \(type(of: $0.value))")
        guard let kp = $0.value as? AnyKeyPath else { return false }
        return kp == idKey
    }!.label!

    let _ = EncodingStrategy {
        Key<Alien>("name", \.age)
    }
//    basb.omitting(\.id)
    let fuzz = Fuzzy()
    fuzz.name = "lolololo"
    fuzz.canThisWork(with: \.name)
    let iadKey = \Baa.id
    let keyMirror = Mirror(reflecting: idKey)
//    keyMirror.
    let refl = Mirror(reflecting: Baa(id: "basdvb"))
    refl.children.forEach { $0.label}
    let t = Wrapper("hi")
    let funcs = DynamicFuncs()
    funcs.doWhatever("hi")


    let dyno = Dynamic()
//    print(dyno.asdf)
    let path = \Dynamic.anythingHere

//    let _ = Serializer<Alien> {
//        \.name
//        \Alien.age
//    }

//    let _ = Serializer<Alien> {
//        \.name.js
////        Key("name", \Alien.name)
//    }

    let alien = Alien(name: "roy", age: 234918)
    alien.iuiii(\Alien.age)
    alien.gen(\.age, \.name)
//    alien.asdf(\Alien.age, \Alien.name)
    alien.withJustPath {
        return \.age
    }

    alien.go {
        \Alien.age
    }

    let blog = Blog(title: "Title", url: URL(string: "https://www.google.com")!)
    let blogger = Blogger(name: "test", blog: blog)
    print(blogger.title)
    print(blogger.url)

//    var a = Valued(id: "a")
//    let rid = \Reffed.id
//    let vid = \Valued.id
//
//    let stringCount = \String.count
//    let result = a[keyPath: vid.appending(path: stringCount)]
//    print(result)
//
//    let setter = test_setter(for: &a, keyPath: \.id)
//    print(a.id)
//    setter("b")
//    print(a.id)
//    print("")
}
