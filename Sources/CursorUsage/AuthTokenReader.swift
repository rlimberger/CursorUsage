import Foundation
import SQLite3

enum AuthTokenReader {
    struct Credentials {
        let accessToken: String
        let membershipType: String?
        let email: String?
    }

    private static var stateDBPath: String {
        NSHomeDirectory() + "/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    }

    static func load() throws -> Credentials {
        let path = stateDBPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw UsageError.missingCursorDB
        }

        var db: OpaquePointer?
        defer { sqlite3_close(db) }

        // Read-only + immutable so we don't fight Cursor's WAL writers.
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK else {
            throw UsageError.databaseOpenFailed
        }

        // Prefer a fresh snapshot if WAL is mid-write.
        _ = sqlite3_exec(db, "PRAGMA query_only = ON;", nil, nil, nil)

        guard let accessToken = stringValue(db: db, key: "cursorAuth/accessToken"),
              !accessToken.isEmpty
        else {
            throw UsageError.missingAccessToken
        }

        let membership = stringValue(db: db, key: "cursorAuth/stripeMembershipType")
        let email = stringValue(db: db, key: "cursorAuth/cachedEmail")
        return Credentials(accessToken: accessToken, membershipType: membership, email: email)
    }

    private static func stringValue(db: OpaquePointer?, key: String) -> String? {
        let sql = "SELECT value FROM ItemTable WHERE key = ? LIMIT 1;"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cString = sqlite3_column_text(stmt, 0)
        else { return nil }

        return String(cString: cString)
    }
}
