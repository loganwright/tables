import SQLKit

//extension SQLDatabase {
//
//    // MARK: DELETE
//
//    /// remove all objects in a table, maintain schema
//    func _deleteAll(from table: String) throws {
//        try self.delete(from: table)
//            .run()
//            .wait()
//    }
//
//    // MARK:
//
//    func unsafe_dropTable(_ table: String) throws {
//        try self.drop(table: table).run().wait()
//    }
//
//    // MARK: FATAL
//
//    func unsafe_fatal_deleteAllEntries() throws {
//        Log.warn("fatal process deleting all entries")
//        try unsafe_getAllTables().forEach(_deleteAll)
//    }
//
//    func unsafe_fatal_dropAllTables() throws {
//        Log.warn("fatal process deleting tables")
//        /// idk how to just delete all at once
//        try unsafe_getAllTables().forEach(unsafe_dropTable)
//    }
//
//    
//}
