# Napzter skills library (from MCP roadmap)

Starter skills derived from `odysseus-mcp-skills-roadmap.md`, formatted for Napzter's native `SKILL.md` importer.

| Skill | Folder | Purpose |
|-------|--------|---------|
| MCP setup | [mcp-starter-setup](./mcp-starter-setup/SKILL.md) | Register filesystem, shell, GitHub MCPs |
| Coding | [fullstack-coding](./fullstack-coding/SKILL.md) | Feature work with tests |
| Debugging | [debugging](./debugging/SKILL.md) | Reproduce → fix → verify |
| Git | [git-workflow](./git-workflow/SKILL.md) | Worktrees, commits, promote |
| GitHub PRs | [github-prs](./github-prs/SKILL.md) | PR review and drafts |
| Research | [research-rag](./research-rag/SKILL.md) | Local docs first, cite sources |
| Local Napzter | [napzter-local-development](./napzter-local-development/SKILL.md) | Windows shortcuts, branding, launchers |

## Add to Napzter Dev (recommended first)

1. Open http://127.0.0.1:7001 → **Memory** → **Skills** tab (or Memories → Add Skill).
2. For each skill folder above, open `SKILL.md`, copy all contents.
3. **Add Skill** (draft) or paste via **Edit** on an existing draft → **Save** → **Publish**.
4. Enable **Skills** injection (toggle in Skills header).
5. Test: `/skills list` or ask *"Use the debugging skill to triage a test failure"*.

## Add to Napzter Prod

Repeat the same steps on http://127.0.0.1:7000 after dev validation. Skills live under each instance's data dir (`OdysseusData` vs `OdysseusData-dev`), not in git by default.

## MCP before skills

Register MCP servers using the **mcp-starter-setup** skill before relying on filesystem/shell/GitHub tools in the other skills.
