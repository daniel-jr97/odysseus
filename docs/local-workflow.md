# Local fork workflow (Felix)

This fork uses a simple **stable vs staging** model on top of the upstream Odysseus project.

## Branches

| Branch | Role | Run Odysseus from here? |
|--------|------|-------------------------|
| **`main`** | Stable / production. Only tested work lands here. | **Yes** — daily driver |
| **`develop`** | Staging / integration. Experiments merge here first. | For testing before promote |
| **`feature/*`** | Short-lived experiment or feature branches | No |

Upstream Odysseus uses **`dev`** (active) and **`main`** (curated release). This fork adds **`develop`** so your staging branch does not collide with `origin/dev` or `upstream/dev`.

## Remotes

| Remote | URL | Purpose |
|--------|-----|---------|
| `origin` | `https://github.com/daniel-jr97/odysseus.git` | Your fork — push `main` and `develop` here |
| `upstream` | `https://github.com/pewdiepie-archdaemon/odysseus.git` | Upstream project — pull `upstream/dev` when integrating upstream fixes |

## Daily development

```powershell
# Start a new experiment (creates feature/<name> from develop)
git experiment my-change

# ... edit, test Odysseus ...

# Merge experiment into staging
git finish-experiment

# Test on develop, then promote to stable
git promote
git push origin main
```

## Pull upstream changes (optional, periodic)

```powershell
git sync-upstream
# resolve conflicts if any, test on develop, then:
git promote
git push origin main develop
```

## Hotfix on stable

```powershell
git checkout main
git checkout -b hotfix/short-description
# fix, test
git checkout main
git merge --no-ff hotfix/short-description
git checkout develop
git merge --no-ff hotfix/short-description
git push origin main develop
```

## Rules

1. Do not commit directly to `main` except via `promote` or hotfix merge.
2. Do all new work on `feature/*` branches (or on `develop` for tiny changes).
3. Only merge to `main` after you have run and tested on `develop`.
4. Keep `main` checked out when running the stable install from `E:\Odysseus`.
