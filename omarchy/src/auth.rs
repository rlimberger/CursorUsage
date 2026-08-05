use std::path::{Path, PathBuf};

use rusqlite::{Connection, OpenFlags};
use thiserror::Error;

#[derive(Debug, Clone)]
pub struct Credentials {
    pub access_token: String,
    pub membership_type: Option<String>,
    pub email: Option<String>,
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("Cursor state database not found. Is Cursor installed and signed in?")]
    MissingCursorDb,
    #[error("Could not open Cursor’s local database: {0}")]
    DatabaseOpenFailed(#[from] rusqlite::Error),
    #[error("No Cursor access token found. Sign in to Cursor, then try again.")]
    MissingAccessToken,
}

/// Candidate paths for Cursor’s `state.vscdb` on Linux (and macOS for local testing).
pub fn state_db_candidates() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    if let Some(home) = dirs_home() {
        // Linux / Omarchy
        paths.push(
            home.join(".config/Cursor/User/globalStorage/state.vscdb"),
        );
        paths.push(
            home.join(".config/cursor/User/globalStorage/state.vscdb"),
        );
        paths.push(
            home.join(".config/Cursor Nightly/User/globalStorage/state.vscdb"),
        );
        // macOS (handy when developing the port on a Mac)
        paths.push(
            home.join("Library/Application Support/Cursor/User/globalStorage/state.vscdb"),
        );
        paths.push(
            home.join(
                "Library/Application Support/Cursor - Insiders/User/globalStorage/state.vscdb",
            ),
        );
    }

    if let Ok(override_path) = std::env::var("CURSOR_USAGE_STATE_DB") {
        paths.insert(0, PathBuf::from(override_path));
    }

    paths
}

pub fn load_credentials() -> Result<Credentials, AuthError> {
    let path = state_db_candidates()
        .into_iter()
        .find(|p| p.is_file())
        .ok_or(AuthError::MissingCursorDb)?;
    load_credentials_from(&path)
}

pub fn load_credentials_from(path: &Path) -> Result<Credentials, AuthError> {
    // Read-only so we don't fight Cursor's WAL writers.
    let flags = OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX;
    let conn = Connection::open_with_flags(path, flags)?;
    let _ = conn.execute_batch("PRAGMA query_only = ON;");

    let access_token = string_value(&conn, "cursorAuth/accessToken")?
        .filter(|t| !t.is_empty())
        .ok_or(AuthError::MissingAccessToken)?;

    Ok(Credentials {
        access_token,
        membership_type: string_value(&conn, "cursorAuth/stripeMembershipType")?,
        email: string_value(&conn, "cursorAuth/cachedEmail")?,
    })
}

fn string_value(conn: &Connection, key: &str) -> Result<Option<String>, AuthError> {
    let mut stmt = conn.prepare("SELECT value FROM ItemTable WHERE key = ?1 LIMIT 1;")?;
    let mut rows = stmt.query(rusqlite::params![key])?;
    if let Some(row) = rows.next()? {
        let value: String = row.get(0)?;
        Ok(Some(value))
    } else {
        Ok(None)
    }
}

fn dirs_home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

#[cfg(test)]
mod tests {
    use super::*;
    use rusqlite::Connection;

    #[test]
    fn reads_token_from_sqlite() {
        let dir = tempfile::tempdir().unwrap();
        let db_path = dir.path().join("state.vscdb");
        {
            let conn = Connection::open(&db_path).unwrap();
            conn.execute_batch(
                "CREATE TABLE ItemTable (key TEXT PRIMARY KEY, value TEXT);
                 INSERT INTO ItemTable VALUES ('cursorAuth/accessToken', 'test-token');
                 INSERT INTO ItemTable VALUES ('cursorAuth/stripeMembershipType', 'pro');
                 INSERT INTO ItemTable VALUES ('cursorAuth/cachedEmail', 'a@b.c');",
            )
            .unwrap();
        }

        let creds = load_credentials_from(&db_path).unwrap();
        assert_eq!(creds.access_token, "test-token");
        assert_eq!(creds.membership_type.as_deref(), Some("pro"));
        assert_eq!(creds.email.as_deref(), Some("a@b.c"));
    }
}
