mod auth;
mod cursor_running;
mod usage;
mod waybar;

use std::process::Command;

use anyhow::Result;
use clap::{Parser, Subcommand};

use waybar::{error_output, from_snapshot, hidden_output, to_json};

const DASHBOARD_URL: &str = "https://cursor.com/dashboard/usage";

#[derive(Debug, Parser)]
#[command(
    name = "cursor-usage-waybar",
    about = "Cursor plan usage for Omarchy Waybar",
    version
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Print plain text instead of Waybar JSON.
    #[arg(long, global = true)]
    text: bool,

    /// Show the module even when Cursor is not running.
    #[arg(long, global = true)]
    always: bool,
}

#[derive(Debug, Subcommand)]
enum Commands {
    /// Default: emit Waybar JSON for the custom module.
    Status,
    /// Open the Cursor usage dashboard in a browser.
    Open,
    /// Send a desktop notification with the current usage breakdown.
    Notify,
}

fn main() {
    let cli = Cli::parse();
    let result = match cli.command.unwrap_or(Commands::Status) {
        Commands::Status => print_status(cli.text, cli.always),
        Commands::Open => open_dashboard(),
        Commands::Notify => notify_usage(),
    };

    if let Err(err) = result {
        eprintln!("{err:#}");
        std::process::exit(1);
    }
}

fn print_status(plain_text: bool, always: bool) -> Result<()> {
    if !always && !cursor_running::is_cursor_running() {
        if plain_text {
            // Empty line keeps Waybar quiet in text mode too.
            println!();
        } else {
            println!("{}", to_json(&hidden_output()));
        }
        return Ok(());
    }

    match fetch_status() {
        Ok(out) => {
            if plain_text {
                println!("{}", out.text);
            } else {
                println!("{}", to_json(&out));
            }
        }
        Err(err) => {
            let out = error_output(&err.to_string());
            if plain_text {
                eprintln!("{err}");
                println!("{}", out.text);
            } else {
                println!("{}", to_json(&out));
            }
        }
    }
    Ok(())
}

fn fetch_status() -> Result<waybar::WaybarOutput, usage::UsageError> {
    let credentials = auth::load_credentials()?;
    let snapshot = usage::fetch_usage_with(&credentials)?;
    let mut out = from_snapshot(&snapshot);
    out.tooltip = waybar::format_tooltip_with_email(&snapshot, credentials.email.as_deref());
    Ok(out)
}

fn open_dashboard() -> Result<()> {
    // Prefer Omarchy/xdg helpers; fall back quietly.
    if Command::new("xdg-open").arg(DASHBOARD_URL).status().is_ok() {
        return Ok(());
    }
    let _ = Command::new("omarchy-launch-browser")
        .arg(DASHBOARD_URL)
        .status();
    Ok(())
}

fn notify_usage() -> Result<()> {
    match fetch_status() {
        Ok(out) => {
            let _ = Command::new("notify-send")
                .args(["-u", "low", "Cursor Usage", &out.tooltip])
                .status();
        }
        Err(err) => {
            let _ = Command::new("notify-send")
                .args(["-u", "normal", "Cursor Usage", &err.to_string()])
                .status();
        }
    }
    Ok(())
}
