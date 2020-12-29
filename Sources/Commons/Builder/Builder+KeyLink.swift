extension Builder {
    /// an assigner is returned from keypaths by the builder with
    /// the metadata required to set corresponding attribute
    @dynamicMemberLookup
    public final class Link<Value> {

        internal fileprivate(set) var ref: Builder<Model>
        internal let kp: KeyPath<Model, Value>

        public init(ref: Builder<Model>, kp: KeyPath<Model, Value>) {
            self.ref = ref
            self.kp = kp
        }

        /// nested key paths

        public subscript<T>(dynamicMember kp: KeyPath<Value, T>) -> Builder<Model>.Link<T> {
            let extended = self.kp.appending(path: kp)
            return Builder<Model>.Link<T>(ref: ref, kp: extended)
        }

        public subscript<T>(dynamicMember kp: ReferenceWritableKeyPath<Value, T>) -> Builder<Model>.Assigner<T> {
            let extended = self.kp.appending(path: kp)
            return Builder<Model>.Assigner<T>(ref: ref, kp: extended)
        }

    }
}
