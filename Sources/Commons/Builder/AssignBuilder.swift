/// for a nested property builder
/// if it is a validating object, is expected to be complete
@dynamicMemberLookup
public final class AssignBuilder<Outer, Inner> {
    public private(set) var assigner: Builder<Outer>.Assigner<Inner>
    public private(set) var builder: Builder<Inner>

    public init(
        outer: Builder<Outer>.Assigner<Inner>,
        inner: Builder<Inner>
    ) {
        self.assigner = outer
        self.builder = inner
    }

    public subscript<T>(dynamicMember kp: KeyPath<Builder<Inner>, T>) -> T {
        builder[keyPath: kp]
    }

    public subscript<T>(dynamicMember kp: WritableKeyPath<Builder<Inner>, T>) -> T {
        get { builder[keyPath: kp] }
        set { builder[keyPath: kp] = newValue }
    }

    public func callAsFunction(
        _ subbuilder: @escaping (Builder<Inner>) -> Builder<Inner>
    ) -> Builder<Outer> {
        let new = subbuilder(builder).make()
        return assigner(new)
    }
}

extension Builder.Assigner {
    public var build: AssignBuilder<Model, Value> {
        let inner = Builder<Value> {
            return self.ref.make()[keyPath: self.kp]
        }
        return AssignBuilder<Model, Value>(outer:self, inner: inner)
    }
}
