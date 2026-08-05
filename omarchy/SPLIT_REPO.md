# Splitting into `cursor-usage-omarchy`

This directory is a self-contained Rust + Waybar project. The cloud agent could not create a new GitHub repository with the available token (`createRepository` is forbidden for the integration).

To publish as its own repo:

```bash
# 1. Create an empty public repo on GitHub:
#    https://github.com/new  →  rlimberger/cursor-usage-omarchy

# 2. Push this tree as main:
cd omarchy
git init -b main
git add -A
git commit -m "Initial Omarchy Waybar port of CursorUsage."
git remote add origin https://github.com/rlimberger/cursor-usage-omarchy.git
git push -u origin main
```

A ready-to-push copy of this project (with history) also exists on the agent VM at
`/home/ubuntu/cursor-usage-omarchy` for the duration of that run.
