// MARK: Schema

public protocol Schema {
    init()
    static var table: String { get }
//    static var db: 
    var tableConstraints: TableConstraints { get }
}

extension Schema {
    public static var table: String { "\(Self.self)".lowercased()}
    public var tableConstraints: TableConstraints { TableConstraints { } }
}

import SQLKit

public protocol DatabaseValue {
    static var sqltype: SQLDataType { get }
}

extension String: DatabaseValue {
    public static var sqltype: SQLDataType { return .text }
}

extension Int: DatabaseValue {
    public static var sqltype: SQLDataType { .int }
}

import Foundation

extension Data: DatabaseValue {
    public static var sqltype: SQLDataType { .blob }
}

public protocol OptionalProtocol {
    associatedtype Wrapped
}
extension Optional: OptionalProtocol {}

internal func replacedDynamically() -> Never { fatalError() }
