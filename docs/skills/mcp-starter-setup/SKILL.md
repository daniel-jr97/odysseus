---
name: mcp-starter-setup
description: Register filesystem, shell, and GitHub MCP servers in Napzter with least-privilege paths and a phased test plan.
version: 1.0.0
category: dev
tags: [mcp, napzter, filesystem, shell, github, setup, admin]
platforms: [windows]
status: draft
confidence: 0.9
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use when setting up or troubleshooting the **first three MCP servers** for Napzter coding agents: **filesystem**, **shell**, and **GitHub**. Admin access required.

## Procedure

1. **Prerequisites** — verify: Git on PATH, Node.js/npm (`npx`), Python + `uvx` (for shell MCP), GitHub PAT with minimal repo scope. Do not store tokens in git.

2. **Add MCP in Napzter** — Settings → Connections (or Integrations) → **MCP** → Add server. Paste JSON config for command, args, and env. Enable one server at a time; wait for **Connected** status before adding the next.

3. **Filesystem MCP (add first)** — restrict to repo folders only:
   ```json
   {
     "command": "cmd",
     "args": [
       "/c", "npx", "-y", "@modelcontextprotocol/server-filesystem",
       "E:\\Odysseus", "E:\\Odysseus-develop"
     ]
   }
   ```
   Test: list root, read `README.md`. Confirm the model cannot browse outside allowed paths.

4. **Shell MCP (add second)** — example:
   ```json
   {
     "command": "uvx",
     "args": ["mcp-server-shell"]
   }
   ```
   Test with safe commands: `git status`, `dir`, then project tests (`pytest`, `npm test`) only after basics pass.

5. **GitHub MCP (add third)** — set `GITHUB_PERSONAL_ACCESS_TOKEN` in server env (not in chat):
   ```json
   {
     "command": "cmd",
     "args": ["/c", "npx", "-y", "@modelcontextprotocol/server-github"],
     "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "<your-pat>" }
   }
   ```
   Test: list repo metadata, read a PR or issue.

6. **Combined trial** — run one end-to-end task: read a file (filesystem) → run tests (shell) → summarize open PR (GitHub). Each step should use the **right** MCP, not shell for file reads or GitHub for local tests.

## Pitfalls

- Filesystem root too broad (whole user profile or `C:\`) — leaks private files
- Adding all three MCPs before testing each one — hard to debug failures
- GitHub PAT with org-wide or admin scope — use least privilege
- Shell MCP running destructive commands before policy is clear — start read-only
- Storing PAT in committed config files — use Napzter MCP env UI only

## Verification

| MCP | Test | Pass |
|-----|------|------|
| Filesystem | List `E:\Odysseus` | Repo files only |
| Filesystem | Read README | Full text returned |
| Shell | `git status` | Branch + tree shown |
| Shell | One test/build command | Pass/fail output |
| GitHub | Read PR metadata | Title, body, comments |
| Combined | File + test + PR summary | Correct tool per step |

## Tool roles (reference)

- **Filesystem** — read/write project files within allowed roots
- **Shell** — run tests, builds, local git, logs
- **GitHub** — PRs, issues, comments, hosted repo metadata (not local file edits)
