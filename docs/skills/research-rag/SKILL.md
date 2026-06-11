---
name: research-rag
description: Ground answers in local project docs and Napzter memory first; use fresh external sources only when freshness matters.
version: 1.0.0
category: dev
tags: [research, rag, documentation, citations, napzter]
platforms: [windows]
status: draft
confidence: 0.9
source: taught
created: 2026-06-11T00:00:00Z
---

## When to Use

Use when answering architecture questions, planning features, comparing approaches, or researching how Napzter/Odysseus implements something.

**Inputs expected:** question, whether answer must be current (release notes, API changes) or stable (internal architecture).

## Procedure

1. **Search local first**
   - Repo docs: `docs/`, `README.md`, `CONTRIBUTING.md`, `docs/local-workflow.md`
   - Skills library: `docs/skills/**/SKILL.md`
   - Code: grep/read relevant modules before guessing
   - Napzter **Memory** and **Skills** (if injected) for user-specific preferences

2. **Classify information freshness**
   - **Stable** — internal layout, worktree paths, skill format, git workflow → local docs suffice
   - **Time-sensitive** — upstream releases, MCP package versions, GitHub API changes → verify externally

3. **External research** (only when needed) — web search or official docs; note retrieval date; prefer primary sources (GitHub repos, official MCP docs).

4. **Synthesize** — combine local evidence with external updates; **mark assumptions** and stale sections explicitly.

5. **Cite sources** — file paths for local (`docs/local-workflow.md`), URLs for external. Distinguish "in this fork" vs "upstream default".

6. **Actionable close** — end with recommended next step for the user's Napzter setup (dev first on 7001).

## Pitfalls

- Answering from memory when repo docs contradict
- Citing upstream Odysseus behavior without checking this fork (Napzter branding, worktrees, `develop` branch)
- Treating roadmap/plan docs as implemented features — verify in code
- External research without noting date/version
- Ignoring user's dual prod/dev instances

## Verification

- At least one local source cited for repo-specific claims
- Assumptions labeled
- Freshness noted for external facts
- Recommendation specifies dev vs prod when relevant

## Tools allowed

- **Filesystem MCP** — read docs and code
- **Napzter web search / SearXNG** — external freshness (when enabled)
- **GitHub MCP** — upstream issues/releases for the odysseus project
- **Memory/skills** — user preferences and taught workflows

## Output format

```
## Answer
## Local sources
- path or skill name
## External sources (if any)
- url — retrieved date
## Assumptions
## Recommended next step
```
