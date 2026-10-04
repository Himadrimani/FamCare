import Foundation
import SQLite3

let fileManager = FileManager.default
let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
if let documentDirectory = urls.first {
    let dbURL = documentDirectory.appendingPathComponent("FamCare.sqlite")
    print("DB Path: \(dbURL.path)")
    
    var db: OpaquePointer?
    if sqlite3_open(dbURL.path, &db) == SQLITE_OK {
        let query = "SELECT firstName, profilePic FROM Profiles"
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(statement, 0))
                let pic = sqlite3_column_text(statement, 1) != nil ? String(cString: sqlite3_column_text(statement, 1)) : "NULL"
                print("Profile: \(name), Pic: \(pic)")
            }
            sqlite3_finalize(statement)
        }
        sqlite3_close(db)
    }
}
