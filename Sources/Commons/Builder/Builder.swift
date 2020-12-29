/// use to turn any arbitrary struct into builder syntax
@dynamicMemberLookup
public struct Builder<Model> {
    /// create, initialize
    public private(set) var constructor: () -> Model

    /// is this better or `(Model) -> Model)` hmm
    /// also probbaly nicer if these were encapsulated
    /// w some meta for debugging
    public private(set) var buildSteps: [BuildStep<Model>]

    public init(_ constructor: @escaping () -> Model) {
        self.constructor = constructor
        self.buildSteps = []
    }

    public subscript<T>(dynamicMember kp: KeyPath<Model, T>) -> Builder<Model>.Link<T> {
        Builder<Model>.Link<T>(ref: self, kp: kp)
    }

    public subscript<T>(dynamicMember kp: WritableKeyPath<Model, T>) -> Builder<Model>.Assigner<T> {
        Builder<Model>.Assigner<T>(ref: self, kp: kp)
    }

    public func add(step: @escaping (inout Model) -> Void) -> Builder<Model> {
        add(step: .init(step))
    }

    public func add(step: BuildStep<Model>) -> Builder<Model> {
        var mutable = self
        mutable.buildSteps.append(step)
        return mutable
    }

    public func passthrough(_ passthrough: (Builder<Model>) -> Builder<Model>) -> Builder<Model> {
        passthrough(self)
    }

    // zucker
    public var make: Self { self }

    /// creates a new model with the current build instructions
    public func callAsFunction() -> Model {
        var new = constructor()
        buildSteps.forEach { setter in
            setter(&new)
        }
        return new
    }
}


extension Builder where Model: AnyObject {
    public func apply() {
        _ = self()
    }
}

open class BuildStep<Model> {
    private let backing: (inout Model) -> Void

    public init(_ backing: @escaping (inout Model) -> Void) {
        self.backing = backing
    }


    public init(step: @escaping (inout Model) -> Void) {
        self.backing = step
    }

    internal func callAsFunction(_ model: inout Model) {
        backing(&model)
    }
}

extension BuildStep {
    public func _unsafe_testForceCall(_ model: inout Model) {
        self(&model)
    }
}
