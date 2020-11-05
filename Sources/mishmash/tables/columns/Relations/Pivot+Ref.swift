import SQLKit

extension Ref {
    func add<R>(to pivot: KeyPath<S, Pivot<S, R>>, _ new: [Ref<R>]) throws {
        /// not efficient, and not handling cascades and stuff
        try new.forEach { incoming in
            let pivot = PivotSchema<S, R>.on(db)
            pivot.left = self
            pivot.right = incoming
            try pivot.save()
        }
    }

    func remove<R>(from pivot: KeyPath<S, Pivot<S, R>>, _ remove: [Ref<R>]) throws {
        let pivot = S.template[keyPath: pivot]
        let schema = pivot.schema

        let pivotIdKey = R.template._pivotIdKey
        let ids = remove.map(\._id)
        try self.db.delete(from: schema.table)
            .where(pivotIdKey._sqlid, .in, ids)
            .run()
            .wait()
    }
}

extension Ref {
    subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> [Ref<R>] {
        get {
            // we're not using the pivot object, could contain some meta info
            // for now, this works
            let pivotColumn = S.template._pivotIdKey
            let myPrimary = S.template._primaryKey
            let id = backing[myPrimary.name]

            /// not very optimized fetching one at a time
            let pivots: [Ref<PivotSchema<S, R>>] = db.getAll(where: pivotColumn, matches: id)
            return pivots.map(\.right).compactMap { r in
                guard let r = r else {
                    Log.warn("unexpected nil on pivot, set cascade?")
                    return nil
                }
                return r
            }
        }
        set {
            /// not efficient, and not handling cascades and stuff
            newValue.forEach { incoming in
                let pivot = PivotSchema<S, R>.on(db)
                pivot.left = self
                pivot.right = incoming
                try! pivot.save()
            }
        }
    }
}
