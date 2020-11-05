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
