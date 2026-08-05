use std::process::Command;

/// True when a Cursor IDE process appears to be running.
///
/// Omarchy/Linux packages typically expose `cursor` / `Cursor`; we also match
/// common Electron helper names without treating this Waybar helper as Cursor.
pub fn is_cursor_running() -> bool {
    if std::env::var_os("CURSOR_USAGE_FORCE_VISIBLE").is_some() {
        return true;
    }

    let Ok(output) = Command::new("ps").args(["-eo", "comm="]).output() else {
        // If we can't inspect processes, stay visible.
        return true;
    };
    if !output.status.success() {
        return true;
    }

    let text = String::from_utf8_lossy(&output.stdout);
    text.lines().any(|line| {
        let name = line.trim();
        matches!(
            name,
            "cursor" | "Cursor" | "cursor-bin" | "cursor-app"
        ) || name.eq_ignore_ascii_case("cursor")
    })
}

#[cfg(test)]
mod tests {
    #[test]
    fn force_visible_env_works() {
        std::env::set_var("CURSOR_USAGE_FORCE_VISIBLE", "1");
        assert!(super::is_cursor_running());
        std::env::remove_var("CURSOR_USAGE_FORCE_VISIBLE");
    }
}
