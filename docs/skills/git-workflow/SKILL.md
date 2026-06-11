---
name: git-workflow
description: Safe git habits for Felix's Napzter fork — worktrees, focused commits, staging-first promotion, no surprise force-push.
version: 1.0.0
category: dev
tags: [git, worktree, napzter, commit, promote, windows]
platforms: [windows]
status: draft
confidence: 0.95
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use for branching, committing, syncing remotes, promoting dev→prod, or any git operation on the Napzter fork.

## Procedure

1. **Know the worktrees**
   - `E:\Odysseus` → branch **`main`** (production, port 7000)
   - `E:\Odysseus-develop` → branch **`develop`** (staging, port 7001)
   - Scripts in `E:\Odysseus\scripts\` apply to both instances

2. **Start and end with status** — run `git status` in the correct worktree before and after work.

3. **Default workflow**
   - Develop on **`develop`** in `E:\Odysseus-develop`
   - Test via Napzter Dev (7001)
   - Commit on `develop`, push when user asks
   - Promote to `main` via `.\scripts\git-workflow.ps1 promote` or merge develop → main
   - Test Napzter AI (7000), then push `main`

4. **Commits**
   - One logical change per commit; message explains **why**
   - Do not commit secrets (`.env`, tokens, passwords)
   - Do not commit unless user explicitly requests (unless automated task says otherwise)

5. **Branch naming** — `feature/*` for experiments; merge into `develop` first; hotfixes branch from `main` then merge back to both branches.

6. **Sync upstream** (when asked) — `.\scripts\git-workflow.ps1 sync-upstream`, test on Dev, then promote.

7. **Risky operations** — before rebase, reset, or force-push: summarize uncommitted changes and **ask for explicit approval**. Never force-push `main` without explicit user request.

## Pitfalls

- Committing directly to `main` except promote/hotfix
- Editing the wrong worktree for the target branch
- `git commit --amend` after push without user approval
- Cherry-picking without verifying both worktrees stay consistent
- Using interactive git flags (`-i`) in automation

## Verification

- `git status` clean in affected worktree
- Changes on correct branch (`develop` vs `main`)
- Dev tested before prod promotion
- Remote push only when user requested

## Tools allowed

- **Shell MCP** — all local git commands
- **GitHub MCP** — remote PR/branch metadata, not local commits
- **Filesystem MCP** — read merge conflict files

## Output format

After git work, report: branch, worktree path, commits made (hash + message), push status, and next step for user.
