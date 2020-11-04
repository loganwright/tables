@propertyWrapper
@dynamicMemberLookup
class ConstraintGroup<T: SQLColumn> {
    /// if there's multiple groups that need to
    /// be disambiguated (only within a single schema)
    let tag: Int?
    var wrappedValue: T
    var projectedValue: ConstraintGroup<T> { self }

    init(wrappedValue: T, _ tag: Int? = nil) {
        self.tag = tag
        self.wrappedValue = wrappedValue
    }

    init(wrappedValue: T) where T == PrimaryKey<String> {
        self.wrappedValue = wrappedValue
        self.tag = nil
    }

    init(wrappedValue: T) where T == PrimaryKey<Int> {
        self.wrappedValue = wrappedValue
        self.tag = nil
    }

    subscript<U>(dynamicMember key: WritableKeyPath<T, U>) -> U {
        get { wrappedValue[keyPath: key] }
        set { wrappedValue[keyPath: key] = newValue }
    }
}

extension SQLColumn {
    func constraintGroup(_ goup: Int? = nil) -> Self {
        fatalError()
    }
}

struct SoccerPlayer: Schema {
    let id = PrimaryKey<Int>()

    @ConstraintGroup(1)
    var team = Column<String>()
    @ConstraintGroup(1)
    var jersey = Column<Int>()
}

struct CricketPlayer: Schema {
    let id = PrimaryKey<Int>()

    var team = Column<String>()
//        .composite()
    var jersey = Column<Int>()

//    var group: { (team, jersey) }
//        .composite()
}
