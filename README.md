# CursorUsage

macOS menu bar app for your [Cursor](https://cursor.com) plan usage.

Shows **Cursor Models** %, **Other Models** %, and days until the billing cycle resets — the same two pools as Cursor Settings → Usage.

```
[icon]  14%  85%  13d
```

Click the item for progress bars, plan name, refresh, and a link to the dashboard.

## Features

- **Live usage** from Cursor’s usage API (no separate login — reuses your IDE session)
- **Menu bar glyph** — Cursor icon, Cursor Models %, Other Models %, reset countdown
- **Popover** — Ultra/Pro-style bars matching the in-app Usage panel
- **Open at Login** — registers automatically; toggle in the popover
- **Cursor-aware** — menu bar item appears only while Cursor is running (helper stays in the background)

## Requirements

- macOS 14+
- [Xcode](https://developer.apple.com/xcode/) or Xcode beta (full toolchain; bare Command Line Tools are not enough for SwiftUI macros)
- Cursor installed and signed in

## Install

```bash
git clone https://github.com/rlimberger/CursorUsage.git
cd CursorUsage
./scripts/build-app.sh install
```

This builds a release app, copies it to `~/Applications/CursorUsage.app`, enables Open at Login, and launches it.

Build only (no install):

```bash
./scripts/build-app.sh
open dist/CursorUsage.app
```

The build script prefers `/Applications/Xcode-beta.app`, then `/Applications/Xcode.app`. Override with:

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

## How it works

1. Reads your Cursor access token (read-only) from  
   `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`  
   (`cursorAuth/accessToken`)
2. Calls Cursor’s internal `GetCurrentPeriodUsage` endpoint
3. Maps `autoPercentUsed` → Cursor Models, `apiPercentUsed` → Other Models
4. Refreshes every 5 minutes, or when you click **Refresh**

> Uses an **undocumented** Cursor API. It may change or break without notice. This project is not affiliated with Anysphere / Cursor.

## Privacy

- Token never leaves your machine except as a Bearer credential to Cursor’s own API
- No third-party analytics or servers
- Local SQLite access is read-only

## Quit

Popover → **Quit**, or:

```bash
killall CursorUsage
```

It starts again at the next login unless you turn off **Open at Login**.

## License

MIT
