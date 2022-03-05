import SQLKit

extension Ref {
    public func add<R>(to pivot: KeyPath<S, Pivot<S, R>>, _ new: [Ref<R>]) throws {
        /// not efficient, and not handling cascades and stuff
        try new.forEach { incoming in
            let pivot = PivotSchema<S, R>.new(referencing: db)
            pivot.left = self
            pivot.right = incoming
            try pivot.save()
        }
    }

    public func remove<R>(from pivot: KeyPath<S, Pivot<S, R>>, _ remove: [Ref<R>]) throws {
        let pivot = S.template[keyPath: pivot]
        let schema = pivot.schema

        let pivotIdKey = R.template._pivotIdKey
        let ids = remove.map(\._id)
        try self.db.delete(from: schema.table)
            .where(pivotIdKey._sqlid, .in, ids)
            .run()
            .commit()
    }
}

extension Ref {
//    public subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> AsyncReadWritable<[Ref<R>]> {
//        AsyncReadWritable(
//            get: {
//                // we're not using the pivot object, could contain some meta info
//                // for now, this works
//                let pivotColumn = S.template._pivotIdKey
//                let myPrimary = S.template._primaryKey
//                let id = self.backing[myPrimary.name]
//
//                /// not very optimized fetching one at a time
//                let pivots: [Ref<PivotSchema<S, R>>] = try self.db.loadAll(where: pivotColumn, matches: id)
//                return pivots.map(\.right).compactMap { r in
//                    guard let r = r else {
//                        Log.warn("unexpected nil on pivot, set cascade?")
//                        return nil
//                    }
//                    return r
//                }
//            },
//            set: { newValue in
//                try newValue.forEach { incoming in
//                    let pivot = PivotSchema<S, R>.new(referencing: self.db)
//                    pivot.left = self
//                    pivot.right = incoming
//                    try pivot.save()
//                }
//            }
//        )
//    }
    public subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> [Ref<R>] {
        get {
            // we're not using the pivot object, could contain some meta info
            // for now, this works
            let pivotColumn = S.template._pivotIdKey
            let myPrimary = S.template._primaryKey
            let id = self.backing[myPrimary.name]
            
            /// not very optimized fetching one at a time
            do {
                let pivots: [Ref<PivotSchema<S, R>>] = try self.db.loadAll(where: pivotColumn, matches: id)
                return pivots.map(\.right).compactMap { r in
                    guard let r = r else {
                        Log.warn("unexpected nil on pivot, set cascade?")
                        return nil
                    }
                    return r
                }
                
            } catch {
                Log.error("failed to get pivot: \(error)")
                return []
            }
        }
        set {
            do {
                try newValue.forEach { incoming in
                    let pivot = PivotSchema<S, R>.new(referencing: self.db)
                    pivot.left = self
                    pivot.right = incoming
                    try pivot.save()
                }
            } catch {
                Log.error("failed to save pivot: \(error)")
            }
        }
    }
}
