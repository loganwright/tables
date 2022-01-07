import SQLKit

extension Ref {
    public func add<R>(to pivot: KeyPath<S, Pivot<S, R>>, _ new: [Ref<R>]) async throws {
        /// not efficient, and not handling cascades and stuff
        try await new.asyncForEach { incoming in
            let pivot = PivotSchema<S, R>.new(referencing: db)
            try pivot.left.set(self)
            try pivot.right.set(incoming)
            try await pivot.save()
        }
    }

    public func remove<R>(from pivot: KeyPath<S, Pivot<S, R>>, _ remove: [Ref<R>]) async throws {
        let pivot = S.template[keyPath: pivot]
        let schema = pivot.schema

        let pivotIdKey = R.template._pivotIdKey
        let ids = remove.map(\._id)
        try await self.db.delete(from: schema.table)
            .where(pivotIdKey._sqlid, .in, ids)
            .run()
            .commit()
    }
}

extension Ref {
    public subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> AsyncReadWritable<[Ref<R>]> {
        AsyncReadWritable(
            get: {
                // we're not using the pivot object, could contain some meta info
                // for now, this works
                let pivotColumn = S.template._pivotIdKey
                let myPrimary = S.template._primaryKey
                let id = self.backing[myPrimary.name]

                /// not very optimized fetching one at a time
                let pivots: [Ref<PivotSchema<S, R>>] = try await self.db.loadAll(where: pivotColumn, matches: id)
                return try await pivots.asyncMap { try await $0.right.get }.compactMap { r in
                    guard let r = r else {
                        Log.warn("unexpected nil on pivot, set cascade?")
                        return nil
                    }
                    return r
                }
            },
            set: { newValue in
                try await newValue.asyncForEach { incoming in
                    let pivot = PivotSchema<S, R>.new(referencing: self.db)
                    try pivot.left.set(self)
                    try pivot.right.set(incoming)
                    try await pivot.save()
                }
            }
        )
    }
}
