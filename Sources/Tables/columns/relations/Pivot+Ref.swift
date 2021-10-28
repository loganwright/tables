import SQLKit

extension Ref {
    func add<R>(to pivot: KeyPath<S, Pivot<S, R>>, _ new: [Ref<R>]) async throws {
        /// not efficient, and not handling cascades and stuff
        try await new.asyncForEach { incoming in
//        for incoming in new {
            let pivot = PivotSchema<S, R>.new(referencing: db!)
            pivot.set(\.left, to: self)
            pivot.set(\.right, to: incoming)
//            pivot.left = self
//            pivot.right = incoming
            try await pivot.save()
        }
    }

    func remove<R>(from pivot: KeyPath<S, Pivot<S, R>>, _ remove: [Ref<R>]) async throws {
        let pivot = S.template[keyPath: pivot]
        let schema = pivot.schema

        let pivotIdKey = R.template._pivotIdKey
        let ids = remove.map(\._id)
        try await self.db!.delete(from: schema.table)
            .where(pivotIdKey._sqlid, .in, ids)
            .run()
            .commit()
    }
}

struct Future<T> {
    var get: T {
        get async throws {
            try await op()
        }
    }
    var set: T {
        get {
            fatalError()
        }
        set {
            
        }
    }
    let op: () async throws -> T
}

extension Ref {
    subscript<R>(dynamicMember key: KeyPath<S, Pivot<S, R>>) -> [Ref<R>] {
        get async throws {
            // we're not using the pivot object, could contain some meta info
            // for now, this works
            let pivotColumn = S.template._pivotIdKey
            let myPrimary = S.template._primaryKey
            let id = backing[myPrimary.name]

            /// not very optimized fetching one at a time
            
//            var pivots: [Ref<PivotSchema<S, R>>] = []
//            unsafeWaitFor {
//                pivots = try await self.db!.getAll(where: pivotColumn, matches: id)
//            }
//            return pivots.map(\.right).compactMap { r in
//                guard let r = r else {
//                    Log.warn("unexpected nil on pivot, set cascade?")
//                    return nil
//                }
//                return r
//            }
//            return pivots
            let pivots: [Ref<PivotSchema<S, R>>] = try await db!.loadAll(where: pivotColumn, matches: id)
//            var result = [Ref<R>]()
//            for pivot in pivots {
//                guard let r = try await pivot.right else {
//                    Log.warn("unexpected nil on pivot, set cascade?")
//                    continue
//                }
//                result.append(await r)
//            }
//            return result
            return try await pivots.asyncMap { try await $0.right }.compactMap { r in
                guard let r = r else {
                    Log.warn("unexpected nil on pivot, set cascade?")
                    return nil
                }
                return r
            }
        }
//        set {
//            /// not efficient, and not handling cascades and stuff
//            newValue.forEach { incoming in
//                let pivot = PivotSchema<S, R>.on(db!)
//                pivot.left = self
//                pivot.right = incoming
//                try! pivot.save()
//            }
//        }
    }
    
    // TODO: Temporary workaround
    func set<R>(_ key: KeyPath<S, Pivot<S, R>>, to newValue: [Ref<R>]) async throws {
        try await newValue.asyncForEach { incoming in
            let pivot = PivotSchema<S, R>.new(referencing: db!)
//            pivot.left = self
            pivot.set(\.left, to: self)
//            pivot.right = incoming
            pivot.set(\.right, to: incoming)
            try await pivot.save()
        }
    }
    
}
