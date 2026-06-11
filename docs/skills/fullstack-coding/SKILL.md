---
name: fullstack-coding
description: Plan and implement frontend/backend changes in small reviewable patches with tests and a clear change summary.
version: 1.0.0
category: dev
tags: [coding, fullstack, testing, refactor, mcp]
platforms: [windows]
status: draft
confidence: 0.9
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use when building or extending features that touch UI, API, data models, or integrations — in the Napzter/Odysseus repo or a configured workspace.

**Inputs expected:** task description, affected area (frontend/backend/both), and whether to target **dev** (`E:\Odysseus-develop`) or **prod** (`E:\Odysseus`) worktree.

## Procedure

1. **Clarify scope** — identify layers affected: UI (`static/`), routes, services, DB/migrations, config. Default to **dev worktree first** unless user specifies prod.

2. **Read before edit** — use filesystem MCP (or Napzter file tools) to open relevant files. Do not propose edits to files you have not inspected.

3. **Plan the smallest complete change** — prefer one logical change per session. List files to touch and risks (auth, migrations, breaking API).

4. **Implement** — match existing conventions (naming, imports, error handling). Minimize diff size; avoid drive-by refactors.

5. **Validate** — run applicable checks via shell MCP:
   - Python: `pytest` on touched areas or targeted test files
   - Frontend/static: lint or manual smoke if no automated test
   - PowerShell scripts: syntax check or dry-run when possible

6. **Summarize deliverable** — report: files changed, behavior change, how to test, follow-ups deferred.

## Pitfalls

- Editing prod worktree before dev validation — breaks staging-first workflow
- Large multi-feature patches — hard to review and revert
- Skipping tests after backend changes
- Mixing branding/config changes with unrelated feature work in one commit
- Using shell to read files when filesystem MCP is available — slower and noisier

## Verification

- Relevant tests pass (or explicit note why not run)
- Change is minimal and matches repo style
- User can reproduce with steps listed in summary
- Dev instance (port 7001) exercised before prod promotion when applicable

## Tools allowed

- **Filesystem MCP** — read/write source under allowed repo roots
- **Shell MCP** — tests, builds, package installs (with user approval for deps)
- **GitHub MCP** — only for issue/PR context, not for local file edits
- **Napzter agent tools** — when MCP unavailable, use built-in file/shell tools with same scope rules

## Output format

```
## Summary
(one sentence)

## Changes
- path — what changed

## How to test
1. ...

## Follow-ups
- ...
```
