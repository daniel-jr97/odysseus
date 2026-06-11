---
name: napzter-local-development
description: Develop and maintain Felix's Napzter fork on Windows — git worktrees, PowerShell launchers, branding, desktop shortcuts, and safe prod/dev promotion.
version: 1.0.0
category: dev
tags: [napzter, odysseus, windows, powershell, git-worktree, branding, shortcuts, local-dev]
platforms: [windows]
status: draft
confidence: 0.95
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use this skill when working on **Felix's local Napzter setup** on Windows: fixing launchers, updating branding/theme, refreshing desktop shortcuts, running prod + dev side by side, or promoting changes from staging to production.

Trigger phrases: "Napzter dev", "worktree", "desktop shortcut", "launch-windows", "rebrand", "promote to prod", "Odysseus-develop", ports 7000/7001.

## Procedure

1. **Know the layout before editing anything**
   - Production code: `E:\Odysseus` (branch `main`, port **7000**, data `E:\OdysseusData`)
   - Staging code: `E:\Odysseus-develop` (branch `develop`, port **7001**, data `E:\OdysseusData-dev`)
   - Shared Python venv: junction `E:\Odysseus-develop\venv` → `E:\Odysseus\venv`
   - Launcher scripts live in the **main** worktree (`E:\Odysseus\scripts\`), even when targeting dev
   - Desktop shortcuts: **Napzter AI** (prod) and **Napzter Dev** (staging)

2. **Daily workflow — test on dev first, then prod**
   - Edit staging code in `E:\Odysseus-develop`
   - Launch via **Napzter Dev** shortcut or `E:\Odysseus\start-odysseus-dev.ps1`
   - Verify at http://127.0.0.1:7001
   - Commit on `develop`, push when ready
   - Promote to `main` with `E:\Odysseus\scripts\git-workflow.ps1 promote` (or merge develop → main)
   - Verify prod at http://127.0.0.1:7000 via **Napzter AI**
   - Never commit secrets (`.env`, passwords, tokens)

3. **Fix PowerShell script invocation (`launch-odysseus.ps1`)**
   - **Do not** use array splatting when calling another script: `& $launch @launchArgs` fails on Windows because `$args` is a reserved automatic variable and array splatting does not bind named parameters to script files.
   - **Do** pass parameters explicitly:
     ```powershell
     if ($AccessLog) {
         & $launch -Quick -Port $Port -BindHost $BindHost -AccessLog
     } else {
         & $launch -Quick -Port $Port -BindHost $BindHost
     }
     ```
   - Symptom if broken: `Cannot convert value "-Quick" to type "System.Int32"` on parameter `Port`.

4. **Napzter branding (UI theme + copy)**
   - Default theme preset: **`napzter`** in `static/js/theme.js` — black `#000000`, accent `#7CFC00`, text `#b8ffb8`
   - Logo assets: `static/napzter-logo.png`, PWA icons `static/icon-192.png` / `static/icon-512.png`
   - Update user-visible strings to **Napzter** in: `static/index.html`, `static/login.html`, `static/manifest.json`, `static/style.css`, key JS files (`app.js`, `sessions.js`, `settings.js`, tours in `slashCommands.js`)
   - **Keep unchanged** unless explicitly migrating APIs: internal keys like `odysseus-theme` (localStorage), function names like `startOdysseusApp`, env vars `ODYSSEUS_URL` / `ODYSSEUS_API_TOKEN`, Homer **Odysseus** character preset in `presets.js`
   - If old coral/slate theme persists after rebrand, clear saved theme in browser console:
     ```js
     localStorage.removeItem('odysseus-theme'); location.reload();
     ```

5. **Desktop shortcuts (Windows)**
   - Install/refresh: `powershell -ExecutionPolicy Bypass -File E:\Odysseus\scripts\install-desktop-shortcut.ps1`
   - Profile config: `scripts/odysseus-profiles.ps1` — shortcut names **Napzter AI** / **Napzter Dev**, `IconFile` per profile
   - **Windows Shell requires `.ico`**, not `.png`, for reliable shortcut icons
   - Build icons: `scripts/build-shortcut-icon.ps1`
     - `-Variant Prod` → `static/napzter.ico` (plain logo)
     - `-Variant Dev` → `static/napzter-dev.ico` (logo + lime border + **DEV** badge)
   - Icon path in shortcuts must use `"$($ico),0"` not `"$icon,0"` (PowerShell parses `$icon,0` as an array)
   - Legacy shortcuts removed on install: `Odysseus`, `Odysseus (Prod)`, `Odysseus (Dev)`

6. **Instance settings (`.env` per worktree)**
   - Managed by `scripts/setup-worktrees.ps1`:
     - Prod: `ODYSSEUS_DATA_DIR=E:\OdysseusData`, `APP_PORT=7000`, `CHROMADB_PORT=8100`
     - Dev: `ODYSSEUS_DATA_DIR=E:\OdysseusData-dev`, `APP_PORT=7001`, `CHROMADB_PORT=8101`
   - Auth is **separate per instance** (`E:\OdysseusData\auth.json` vs `E:\OdysseusData-dev\auth.json`)
   - Session cookies are **per port** (`odysseus_session_7000` vs `odysseus_session_7001` from `APP_PORT`) so prod and dev can stay logged in at the same time in one browser

7. **Git commits on both worktrees**
   - `E:\Odysseus-develop` → branch `develop`
   - `E:\Odysseus` → branch `main`
   - Cherry-pick or promote; push both when user asks:
     ```powershell
     git -C E:\Odysseus push origin main
     git -C E:\Odysseus-develop push origin develop
     ```

8. **Self-improvement loop (using Napzter skills)**
   - After fixing a local workflow, update **this skill** (or add a new one) via Brain → Memories → Add Skill, or edit `SKILL.md` under the Skills tab
   - Publish the skill so it injects into chat and appears in `/skills list`
   - Test on **dev (7001)** before copying the same skill markdown to prod (7000)

## Pitfalls

- Calling `& script.ps1 @arrayArgs` on Windows — named params won't bind; use explicit args or hashtable splatting to functions only, not script files
- Using `$args` as a custom variable in scripts with a `param()` block — reserved automatic variable
- PNG shortcut icons — Windows shows a generic icon; build `napzter.ico` / `napzter-dev.ico` instead
- Editing prod (`E:\Odysseus`) before testing on dev — breaks the staging-first rule
- Assuming prod and dev share login credentials — they use separate `auth.json` files
- Running prod + dev in one browser without per-port session cookies — both instances used to share `odysseus_session` and log each other out; cookie name now includes `APP_PORT`
- Replacing `ODYSSEUS_*` env var names in integration docs — breaks Codex/Claude agent setup commands
- Forgetting to run `install-desktop-shortcut.ps1` after icon/name changes — desktop won't update until script runs

## Verification

- **Dev launcher**: Napzter Dev shortcut opens a PowerShell window without `-Quick`/`Port` errors; browser reaches http://127.0.0.1:7001
- **Prod launcher**: Napzter AI shortcut works at http://127.0.0.1:7000
- **Branding**: Login and chat show Napzter logo, black/green theme, "Message Napzter..." placeholder
- **Shortcut icons**: Napzter AI uses plain logo ICO; Napzter Dev shows DEV badge variant (not generic PowerShell icon)
- **Git**: `git -C E:\Odysseus-develop status` clean on develop; prod changes on `main` only after promote/cherry-pick

## Reference — key files

| Area | Path |
|------|------|
| Worktree profiles | `scripts/odysseus-profiles.ps1` |
| Quick launch | `launch-odysseus.ps1` → `launch-windows.ps1 -Quick` |
| Desktop shortcuts | `scripts/install-desktop-shortcut.ps1` |
| Icon builder | `scripts/build-shortcut-icon.ps1` |
| Theme presets | `static/js/theme.js` (`napzter` preset, `DEFAULT_THEME`) |
| UI shell | `static/index.html`, `static/login.html`, `static/style.css` |
| Local workflow doc | `docs/local-workflow.md` |
| Skills on disk | `<ODYSSEUS_DATA_DIR>/skills/<category>/<name>/SKILL.md` |
| This skill (repo copy) | `docs/skills/napzter-local-development/SKILL.md` |

## Reference — remotes and branches

| Remote | Purpose |
|--------|---------|
| `origin` | Felix fork (`daniel-jr97/odysseus`) |
| `upstream` | Upstream project (`pewdiepie-archdaemon/odysseus`) |

| Branch | Worktree | Role |
|--------|----------|------|
| `main` | `E:\Odysseus` | Production / Napzter AI |
| `develop` | `E:\Odysseus-develop` | Staging / Napzter Dev |
