# Splitting into `cursor-usage-omarchy`

Target repo (empty): https://github.com/rlimberger/cursor-usage-omarchy

The cloud agent **cannot push** there yet: the Cursor GitHub App installation only
includes `rlimberger/CursorUsage` (push returns `Permission denied to cursor[bot]`).

## Option A — grant access, then ask the agent to push (preferred)

1. GitHub → **Settings** → **Applications** → **Installed GitHub Apps** → **Cursor**
2. **Configure** → Repository access → add **`cursor-usage-omarchy`** (or “All repositories”)
3. Reply in the agent chat: “access granted — push”

The agent will push the standalone history to `main`.

## Option B — push yourself from this staging folder

```bash
git clone -b cursor/omarchy-waybar-2d7a https://github.com/rlimberger/CursorUsage.git /tmp/CursorUsage
cd /tmp/CursorUsage/omarchy
rm -f SPLIT_REPO.md
git init -b main
git add -A
git commit -m "Initial Omarchy Waybar port of CursorUsage."
git remote add origin https://github.com/rlimberger/cursor-usage-omarchy.git
git push -u origin main
```

After `main` exists on the new repo, this `omarchy/` staging directory can be removed from CursorUsage.
