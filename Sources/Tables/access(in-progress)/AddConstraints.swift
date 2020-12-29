import SQLKit
extension BaseColumn {
    @discardableResult
    func constraining(by constraints: SQLColumnConstraintAlgorithm...) -> Self {
        assert(constraints.allSatisfy(\.isValidColumnAddConstraint),
               "invalid add on constraint, these are usually supported via types")
        self.constraints.append(contentsOf: constraints)
        return self
    }
}

extension SQLColumnConstraintAlgorithm {
    /// idk what to na
    fileprivate var isValidColumnAddConstraint: Bool {
        switch self {
        /// just foreign key it seems now needs to be declared at end
        /// or if things are grouped or so
        case .unique, .foreignKey, .primaryKey:
            Log.warn("invalid additional constraint use a corresponding column type")
            Log.info("ie: .unique => Unique<Type>(), .foreignKey => ForeignKey<Type>()")
            return false
        default:
            return true
        }
    }
}
