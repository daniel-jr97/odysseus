---
name: github-prs
description: Review and draft pull requests using GitHub MCP for hosted metadata and local tools for code inspection.
version: 1.0.0
category: dev
tags: [github, pull-request, review, mcp, issues]
platforms: [windows]
status: draft
confidence: 0.9
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use when reading, reviewing, summarizing, or drafting pull requests and issue responses on the Napzter fork (`origin`: daniel-jr97/odysseus).

**Inputs expected:** PR number or URL, review goal (summarize, review diff, draft description, respond to comments).

## Procedure

1. **Fetch PR context via GitHub MCP** — title, description, author, linked issues, review comments, CI status if available.

2. **Understand impact** — classify changes: bugfix, feature, refactor, docs, ops. Note user-facing vs internal-only.

3. **Inspect code locally when needed** — use filesystem + shell to checkout branch or read files; GitHub MCP for metadata, not for running tests.

4. **Review structure**
   - **Blockers** — must fix before merge
   - **Suggestions** — should fix
   - **Optional** — nice to have
   - Separate security, correctness, and style

5. **Draft PR content** — plain-language summary: what changed, why, how to test, risks/rollbacks.

6. **Respond to comments** — address each thread; link commits or line references when possible.

## Pitfalls

- Using shell `curl` to GitHub API when GitHub MCP is configured — prefer MCP
- Approving without reading changed files for non-trivial PRs
- Vague summaries ("misc fixes") — be specific
- Mixing upstream (`pewdiepie-archdaemon/odysseus`) and fork remotes without clarifying target
- Suggesting force-push to `main` without explicit user approval

## Verification

- PR summary matches actual diff scope
- Test plan is actionable
- Blockers clearly separated from suggestions
- Issue links included when present

## Tools allowed

- **GitHub MCP** — PRs, issues, comments, repo metadata
- **Filesystem MCP** — read local copies of changed files
- **Shell MCP** — `git fetch`, `git diff`, run tests on PR branch
- **`gh` CLI** — acceptable via shell when MCP unavailable

## Output format

```
## PR summary
## Impact
## Test plan
## Review
### Blockers
### Suggestions
### Optional
```

Use `templates/pr-template.md` in repo when present for description structure.
