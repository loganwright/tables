import SQLiteKit

public protocol PrimaryKeyValue: DatabaseValue {}
extension String: PrimaryKeyValue {}
extension Int: PrimaryKeyValue {}

// MARK: PrimaryKey

@propertyWrapper
public class PrimaryKey<RawType: PrimaryKeyValue>: PrimaryKeyBase {
    public var wrappedValue: RawType? { replacedDynamically() }

    public init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == String {
        super.init(key, .uuid)
    }

    public init(_ key: String = "", type: RawType.Type = RawType.self) where RawType == Int {
        super.init(key, .int)
    }
}


// MARK: PrimaryKey Base

public class PrimaryKeyBase: BaseColumn {
    public enum Kind: Equatable {
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
    public let kind: Kind

    public init(_ key: String = "", _ kind: Kind) {
        self.kind = kind
        super.init(key, kind.sqltype, Later([kind.constraint]))
    }
}

// MARK: Helpers

extension Schema {
    /// whether the schema contains a primary key
    /// one can name their primary key as they'd like, this is
    /// a generic name that will extract
    ///
    /// currently composite primary keys will need to be worked around
    public var primaryKey: PrimaryKeyBase? {
        let all = columns.compactMap { $0 as? PrimaryKeyBase }
        assert(0...1 ~= all.count,
               "multiple primary keys not currently supported as property")
        return all.first
    }

    /// whether a schema is primary keyed
    /// all relations require a schema to be primary keyed
    public var isPrimaryKeyed: Bool {
        primaryKey != nil
    }

    /// this is a forced key that will assert that will fail if a schema has not declared
    /// a primary key
    /// currently only one primary key is supported
    var _primaryKey: PrimaryKeyBase {
        let pk = primaryKey
        assert(pk != nil, "no primary key found: \(Schema.self)")
        return pk!
    }

    var primaryKeyGroup: Any? {
        fatalError()
    }
}
