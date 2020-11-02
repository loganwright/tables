import Combine

@dynamicMemberLookup
class FutureRef<S: Schema> {
    private var inner: Ref<S>

    init(_ raw: [String: JSON] = [:], _ database: Database) {
        self.inner = Ref(raw, database)
    }

    subscript<T>(dynamicMember key: KeyPath<Ref<S>, T>) -> Future<T, Never> {
        get {
            return Future { promise in
                promise(.success(self.inner[keyPath: key]))
            }
        }
    }

    subscript<T>(dynamicMember key: WritableKeyPath<Ref<S>, T>) -> Future<T, Never> {
        get {
            return Future { promise in
                promise(.success(self.inner[keyPath: key]))
            }
        }
        set {
            newValue.sink { (comp) in
                print("done")
            } receiveValue: { (val) in
                self.inner[keyPath: key] = val
            }

        }
//        set {
////            let column = S.template[keyPath: key]
////            backing[column.key] = newValue.json
//        }
    }
}

@dynamicMemberLookup
final class Bridge<A: Schema, B: Schema> {
    private(set) var a: Ref<A>
    private(set) var b: Ref<B>

    init(_ db: Database) {
        a = Ref<A>(db)
        b = Ref<B>(db)
    }

    subscript<T>(dynamicMember key: KeyPath<Ref<A>, T>) -> T {
        get {
            a[keyPath: key]
        }
    }

    subscript<T>(dynamicMember key: KeyPath<Ref<B>, T>) -> T {
        get {
            b[keyPath: key]
        }
    }
    subscript<T>(dynamicMember key: WritableKeyPath<Ref<A>, T>) -> T {
        get {
            a[keyPath: key]
        }
        set {
            a[keyPath: key] = newValue
        }
    }

    subscript<T>(dynamicMember key: WritableKeyPath<Ref<B>, T>) -> T {
        get {
            b[keyPath: key]
        }
        set {
            b[keyPath: key] = newValue
        }
    }
}

func testBridging() {
    let bridge = Bridge<Team, Player>(SeeQuel.shared)

    bridge.mascot = "sadf"
    bridge.rating = 4
}
