extension Builder {
    /// an assigner is returned from keypaths by the builder with
    /// the metadata required to set corresponding attribute
    @dynamicMemberLookup
    public final class Assigner<Value> {

        public fileprivate(set) var ref: Builder<Model>
        public let kp: WritableKeyPath<Model, Value>

        public init(ref: Builder<Model>, kp: WritableKeyPath<Model, Value>) {
            self.ref = ref
            self.kp = kp
        }

        // MARK: Set/Assign

        public func callAsFunction(_ val: Value) -> Builder<Model> {
            let kp = self.kp
            return ref.add(step: { ob in
                ob[keyPath: kp] = val
            })
        }

        public func callAsFunction(_ from: @escaping (Model) -> Value) -> Builder<Model> {
            let kp = self.kp
            return self.ref.add(step: { model in
                model[keyPath: kp] = from(model)
            })
        }

        public func callAsFunction(_ from: @escaping () -> Builder<Value>) -> Builder<Model> {
            let kp = self.kp
            return self.ref.add(step: { model in
                model[keyPath: kp] = from().make()
            })
        }


        /// todo:
        ///         pass.if(credentials.contain(.admin)).then(.admin).else(.public)
        ///
        public func callAsFunction(if condition: Bool, _ val: Value) -> Builder<Model> {
            guard condition else { return ref }
            return self(val)
        }

        public func callAsFunction(ifExists val: Value?) -> Builder<Model> {
            guard let val = val else { return ref }
            return self(val)
        }

        /// nested key paths

        public subscript<T>(dynamicMember kp: KeyPath<Value, T>) -> Builder<Model>.Link<T> {
            let extended = self.kp.appending(path: kp)
            return Builder<Model>.Link<T>(ref: ref, kp: extended)
        }

        public subscript<T>(dynamicMember kp: WritableKeyPath<Value, T>) -> Builder<Model>.Assigner<T> {
            let extended = self.kp.appending(path: kp)
            return Builder<Model>.Assigner<T>(ref: ref, kp: extended)
        }
    }
}
