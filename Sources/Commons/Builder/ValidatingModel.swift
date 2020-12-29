public protocol ValidatingModel {
    /// this would be help for end user,
    /// usually for fellow dev, but could propagate up to user
    var isReady: (ready: Bool, help: String) { get }
}

extension Builder where Model: ValidatingModel {
    public func callAsFunction() throws -> Model {
        var new = constructor()
        buildSteps.forEach { setter in
            setter(&new)
        }
        let answer = new.isReady
        guard answer.ready else { throw answer.help }
        return new
    }
}
