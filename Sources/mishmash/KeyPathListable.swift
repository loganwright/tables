//protocol KeyPathListable {
//  // require empty init as the implementation use the mirroring API, which require
//  // to be used on an instance. So we need to be able to create a new instance of the
//  // type.
//  init()
//
//  var _keyPathReadableFormat: [String: Any] { get }
//  static var allKeyPaths: [KeyPath<Foob, Any?>] { get }
//}
//
//extension KeyPathListable {
//  var _keyPathReadableFormat: [String: Any] {
//    let mirror = Mirror(reflecting: self)
//    var description: [String: Any] = [:]
//    for case let (label?, value) in mirror.children {
//      description[label] = value
//    }
//    return description
//  }
//
//  static var allKeyPaths: [KeyPath<Self, Any?>] {
//    var keyPaths: [KeyPath<Self, Any?>] = []
//    let instance = Self()
//    for (key, _) in instance._keyPathReadableFormat {
//        let a = \Self._keyPathReadableFormat[key]
//        keyPaths.append(a)
////      keyPaths.append(\Self._keyPathReadableFormat[key])
//    }
//    return keyPaths
//  }
//}
//
//struct Foob: KeyPathListable {
//  var x: Int
//  var y: Int
//}
//
//extension Foob {
//  // Custom init inside an extension to keep auto generated `init(x:, y:)`
//  init() {
//    x = 0
//    y = 0
//  }
//}
//
//func keypathlistable() {
//    let xKey = Foob.allKeyPaths[0]
//    let yKey = Foob.allKeyPaths[1]
//
//    var foo = Foob(x: 10, y: 20)
//    let x = foo[keyPath: xKey]!
//    let y = foo[keyPath: yKey]!
//
//    print(x)
//    print(y)
//}
