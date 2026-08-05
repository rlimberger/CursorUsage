<p align="center">
  <h1 align="center">cursor-usage-omarchy</h1>
</p>

<p align="center">
  Cursor plan usage in your Omarchy Waybar
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="https://www.rust-lang.org"><img src="https://img.shields.io/badge/Rust-1.75%2B-orange.svg" alt="Rust"></a>
  <a href="https://omarchy.org"><img src="https://img.shields.io/badge/Omarchy-Waybar-black.svg" alt="Omarchy"></a>
  <a href="https://cursor.com"><img src="https://img.shields.io/badge/Cursor-Ultra%20%2F%20Pro-6B7280.svg" alt="Cursor"></a>
</p>

Linux / Omarchy port of [CursorUsage](https://github.com/rlimberger/CursorUsage) (macOS menu bar).

Shows **Cursor Models** %, **Other Models** %, and days until reset in Waybar’s right modules — same two usage pools as Cursor Settings → Usage.

```
◆  14%  85%  13d
│   │    │    └─ days until billing cycle resets
│   │    └─ Other Models (API / named models)
│   └─ Cursor Models (e.g. Grok / Composer)
└─ marker (text stand-in for the macOS icon)
```

## Why Rust (not Quickshell / C++)

Omarchy’s bar is **Waybar**. Custom items are `custom/*` modules that `exec` a command and read JSON — the same pattern DHH’s Omarchy ships for weather, update, recording, idle, etc. There is no separate C++/Quickshell plugin API for those modules.

This repo follows that model: a small **Rust binary** Waybar runs every few minutes. Rust is used for the fetch/parse logic; Waybar owns the UI chrome.

## Quick start (Omarchy)

```bash
git clone https://github.com/rlimberger/cursor-usage-omarchy.git
cd cursor-usage-omarchy
./scripts/install.sh
```

Then add `"custom/cursor-usage"` to `modules-right` in `~/.config/waybar/config.jsonc` (install script prints the exact snippet) and reload Waybar.

> Requires Rust (`rustup`), and Cursor signed in on this machine.

## Features

| | |
| --- | --- |
| **Live Waybar module** | `◆  Cursor%  API%  days` |
| **Tooltip** | Plan name, both pools, reset detail |
| **No extra login** | Reuses the session from the Cursor IDE |
| **Click** | Left → usage dashboard; right → `notify-send` breakdown |
| **Cursor-aware** | Hidden while Cursor is not running |

## How it works

1. Reads your access token (read-only) from  
   `~/.config/Cursor/User/globalStorage/state.vscdb`
2. Calls Cursor’s `GetCurrentPeriodUsage` API with that token
3. Maps `autoPercentUsed` → Cursor Models, `apiPercentUsed` → Other Models
4. Prints Waybar JSON; Waybar refreshes every 5 minutes (or on click actions)

Uses an **undocumented** Cursor API. It may change without notice. Not affiliated with Anysphere / Cursor.

## Manual Waybar snippet

If you prefer not to use the install script’s module file:

```jsonc
"custom/cursor-usage": {
  "exec": "cursor-usage-waybar",
  "return-type": "json",
  "interval": 300,
  "format": "{}",
  "tooltip": true,
  "on-click": "cursor-usage-waybar open",
  "on-click-right": "cursor-usage-waybar notify"
}
```

Add `"custom/cursor-usage"` to `modules-right`.

## CLI

```bash
cursor-usage-waybar              # Waybar JSON (default)
cursor-usage-waybar --text       # plain text
cursor-usage-waybar --always     # show even if Cursor is not running
cursor-usage-waybar open         # open https://cursor.com/dashboard/usage
cursor-usage-waybar notify       # desktop notification with details
```

Overrides:

| Env | Purpose |
| --- | --- |
| `CURSOR_USAGE_STATE_DB` | Force path to `state.vscdb` |
| `CURSOR_USAGE_FORCE_VISIBLE` | Skip the “Cursor running?” check |

## Development

```bash
cargo test
cargo build --release
CURSOR_USAGE_FORCE_VISIBLE=1 ./target/release/cursor-usage-waybar --text
```

Sibling project: [CursorUsage](https://github.com/rlimberger/CursorUsage) (Swift / macOS menu bar).

## Privacy

- Token is only sent to Cursor’s own API as a Bearer credential
- No third-party analytics or servers
- Local database access is read-only

## License

[MIT](LICENSE) © Rene Limberger
