// MARK: Schema

protocol Schema {
    init()
    static var table: String { get }
    var tableConstraints: TableConstraints { get }
}

extension Schema {
    static var table: String { "\(Self.self)".lowercased()}
    var tableConstraints: TableConstraints { TableConstraints { } }
}

import SQLKit

protocol DatabaseValue {
    static var sqltype: SQLDataType { get }
}

extension String: DatabaseValue {
    static var sqltype: SQLDataType { return .text }
}

extension Int: DatabaseValue {
    static var sqltype: SQLDataType { .int }
}

import Foundation

extension Data: DatabaseValue {
    static var sqltype: SQLDataType { .blob }
}

protocol OptionalProtocol {
    associatedtype Wrapped
}
extension Optional: OptionalProtocol {}

func replacedDynamically() -> Never { fatalError() }
