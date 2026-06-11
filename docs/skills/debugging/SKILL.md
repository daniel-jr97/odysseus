---
name: debugging
description: Reproduce bugs systematically, isolate the failing layer, apply the smallest fix, and verify with evidence.
version: 1.0.0
category: dev
tags: [debugging, testing, logs, mcp, troubleshooting]
platforms: [windows]
status: draft
confidence: 0.9
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use when something fails: tests, launcher scripts, MCP connections, UI errors, or unexpected runtime behavior.

**Inputs expected:** error message, steps to reproduce, which instance (Napzter Dev :7001 vs Prod :7000), and recent changes.

## Procedure

1. **Reproduce first** — repeat the failure with exact commands or UI steps. If not reproducible, gather logs before guessing.

2. **Separate symptom vs root cause** — write one line for what the user sees and one line for the likely layer (PowerShell param binding, missing file, auth, MCP env, Python exception, etc.).

3. **Hypothesize briefly** — list 2–3 hypotheses ranked by likelihood. Test the cheapest hypothesis first.

4. **Gather evidence**
   - **Filesystem MCP** — inspect config, scripts, `.env`, recent diffs in suspect files
   - **Shell MCP** — run failing command, `git status`, targeted tests, read traceback
   - **Logs** — server window output, browser console, Napzter terminal for uvicorn errors

5. **Apply smallest fix** — one focused change. Do not refactor unrelated code in the same fix.

6. **Verify** — re-run reproduction steps; add or run a test if the bug is regressable.

7. **Report** — symptom, root cause, fix, verification command, and anything still risky.

## Pitfalls

- Refactoring before reproduction
- Fixing symptoms only (e.g. catching errors without understanding cause)
- Assuming prod and dev share state — they use separate data dirs (`OdysseusData` vs `OdysseusData-dev`)
- PowerShell: `@args` splatting to script files breaks named params — use explicit arguments
- Windows shortcut icons need `.ico`, not `.png` — generic icon is not proof the script failed

## Verification

- Original failure no longer occurs
- Fix explained with evidence (not guesswork)
- No unrelated files changed
- Dev tested before prod when both are affected

## Tools allowed

- **Shell MCP** — reproduce commands, run tests, `git diff`
- **Filesystem MCP** — read configs and source
- **GitHub MCP** — only if bug ties to CI/PR context

## Output format

```
## Symptom
## Root cause
## Fix
## Verification
(ran X, saw Y)
```
