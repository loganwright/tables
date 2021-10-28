// MARK: Template


extension Schema {
    /// load the template for a given schema type
    /// loading this way also ensures that labels are set
    /// according to swift properties
    public static var template: Self {
        if let existing = _templates[table] as? Self { return existing }
        let new = Self.init()
        /// populates the names of the columns with introspected values
        /// maybe a better way, but for now is helpful
        let _ = _unsafe_force_hydrate_columns_on(new)
        _templates[table] = new
        return new
    }
}

/// templates help us to use instances of a schema as opposed to trying
/// to infer information from it's more opaque type metadata
/// this caches nicely
private var _templates: [String: Schema] = [:]


extension Schema {
    /// these discourage bad things and are confusing, organize when time
    // TODO: Only temporarily public
    public var columns: [BaseColumn] {
        _unsafe_force_hydrate_columns_on(self)
    }

    /// these relate to other objects, but they are the parent and thus do not store a ref
    var _relations: [Relation] {
        _unsafe_force_Load_properties_on(self)
            .compactMap { $0.val as? Relation }
    }
}

// MARK: Introspection

/// a model of mirror reflected properties
public struct Property {
    public let label: String
    public let columntype: Any.Type
    public let val: Any

    init(_ label: String, _ val: Any) {
        self.label = label
        let t = Swift.type(of: val)
        self.columntype = t
        self.val = val
    }
}

/// storing this in any way kills everything, I can't explain why, everything is identical, but it's subtle
/// load all introspectable properties from an instance
///
/// ok, I was thinking about it.. when the nested key declares a key path of it's container
/// `let friend = ForeignKey<Self>(\.id)`
/// and if there's anything in the column creators, it seems to choke, idk, in that case, declare a key
///
/// that was when it was nested tho
///
public func _unsafe_force_Load_properties_on(_ subject: Any) -> [Property] {
    Mirror(reflecting: subject).children.compactMap { child in
        assert(child.label != nil, "expected a label for template property")
        return Property(child.label!, child.value)
    }
}

/// should this use a base 'Column' protocol? it's nice having them separate at the moment
func _unsafe_force_hydrate_columns_on(_ subject: Any) -> [BaseColumn] {
    let properties = _unsafe_force_Load_properties_on(subject)
    return properties.compactMap { prop in
        switch prop.val {
        /// standard persisted column
        case let column as BaseColumn:
            if column.name.isEmpty { column.name = prop.label }
            return column
        /// standard reulation, not a column, but ok
        case _ as Relation:
            return nil
        case _ as TableConstraints:
            return nil
        default:
            Log.warn("incompatible schema property: \(type(of: subject)).\(prop.label): \(prop.columntype)")
            Log.info("expected \(BaseColumn.self), ie: \(Column<String>.self)")
            return nil
        }
    }
}
