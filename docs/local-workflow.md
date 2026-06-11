# Local fork workflow (Felix)

This fork uses **git worktrees** so production and staging can run **at the same time** with separate data and ports.

## Directory layout

| Path | Branch | Role | URL |
|------|--------|------|-----|
| `E:\Odysseus` | `main` | **Production** — stable daily driver | http://127.0.0.1:7000 |
| `E:\Odysseus-develop` | `develop` | **Staging** — test changes before promote | http://127.0.0.1:7001 |
| `E:\OdysseusData` | — | Production data (DB, uploads, memory, …) | |
| `E:\OdysseusData-dev` | — | Staging data (isolated copy) | |

Both worktrees share the same Python `venv` (junction from develop → prod).

## Desktop shortcuts

| Shortcut | Launches |
|----------|----------|
| **Odysseus (Prod)** | `main` @ port 7000 |
| **Odysseus (Dev)** | `develop` @ port 7001 |

Install or refresh shortcuts:

```powershell
cd E:\Odysseus
powershell -ExecutionPolicy Bypass -File .\scripts\setup-worktrees.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-desktop-shortcut.ps1
```

## Branch model

| Branch | Role |
|--------|------|
| **`main`** | Stable / production code in `E:\Odysseus` |
| **`develop`** | Staging code in `E:\Odysseus-develop` |
| **`feature/*`** | Short-lived experiments (merge into `develop`) |

Upstream Odysseus uses **`dev`** and **`main`**. This fork uses **`develop`** locally to avoid clashing with `origin/dev` / `upstream/dev`.

## Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `https://github.com/daniel-jr97/odysseus.git` | Your fork |
| `upstream` | `https://github.com/pewdiepie-archdaemon/odysseus.git` | Upstream project |

## Daily development

```powershell
# 1. Start an experiment (in E:\Odysseus — scripts live in the main worktree)
cd E:\Odysseus
.\scripts\git-workflow.ps1 experiment my-change

# 2. Edit code in E:\Odysseus-develop (develop worktree) or on the feature branch
#    Cursor / git checkouts apply to the worktree for that branch.

# 3. Test on staging — double-click "Odysseus (Dev)" or:
.\start-odysseus-dev.ps1

# 4. Merge experiment into develop
.\scripts\git-workflow.ps1 finish

# 5. Test again on Dev shortcut

# 6. Promote to production
.\scripts\git-workflow.ps1 promote

# 7. Verify production — double-click "Odysseus (Prod)" or:
.\start-odysseus-prod.ps1

# 8. Push when satisfied
git push origin main develop
```

**Note:** After `git-workflow.ps1 promote`, the `main` worktree updates automatically. The `develop` worktree stays on `develop`.

## Pull upstream changes (optional)

```powershell
cd E:\Odysseus
.\scripts\git-workflow.ps1 sync-upstream
# test with Odysseus (Dev), then promote and verify with Odysseus (Prod)
```

## Hotfix on stable

```powershell
cd E:\Odysseus
git checkout main
git checkout -b hotfix/short-description
# fix, test with Odysseus (Prod)
git checkout main
git merge --no-ff hotfix/short-description
git checkout develop
git merge --no-ff hotfix/short-description
git push origin main develop
```

## Rules

1. Do not commit directly to `main` except via `promote` or hotfix merge.
2. Test on **Odysseus (Dev)** before promoting to `main`.
3. Prod and dev can run simultaneously (different ports, data dirs, Chroma ports).
4. Edit staging code in `E:\Odysseus-develop`; edit prod only after promote.

## Instance settings (per worktree `.env`)

Managed by `scripts/setup-worktrees.ps1`:

| Setting | Prod | Dev |
|---------|------|-----|
| `ODYSSEUS_DATA_DIR` | `E:\OdysseusData` | `E:\OdysseusData-dev` |
| `APP_PORT` | `7000` | `7001` |
| `CHROMADB_PORT` | `8100` | `8101` |
