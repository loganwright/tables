import SQLiteKit

protocol PrimaryKeyValue: DatabaseValue {}
extension String: PrimaryKeyValue {}
extension Int: PrimaryKeyValue {}

// MARK: PrimaryKey

@propertyWrapper
class PrimaryKey<RawType: PrimaryKeyValue>: PrimaryKeyBase {
    var wrappedValue: RawType? { replacedDynamically() }

    init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == String {
        super.init(key, .uuid)
    }

    init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == Int {
        super.init(key, .int)
    }
}


// MARK: PrimaryKey Base

class PrimaryKeyBase: BaseColumn {
    enum Kind: Equatable {
        /// combining multiple keys not supported
        case uuid, int

        var sqltype: SQLDataType {
            switch self {
            case .uuid: return .text
            case .int: return .int
            }
        }

        fileprivate var constraint: SQLColumnConstraintAlgorithm {
            let auto: Bool
            switch self {
            case .uuid:
                auto = false
            case .int:
                auto = true
            }
            return .primaryKey(autoIncrement: auto)
        }
    }

    // MARK: Attributes
    let kind: Kind

    init(_ key: String = "", _ kind: Kind) {
        self.kind = kind
        super.init(key, kind.sqltype, Later([kind.constraint]))
    }
}
