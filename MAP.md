# MAP · wrap

## What

Clean session-exit skill: owner gate on persist/git, then write a wrap receipt under `~/.local/state/session-wrap/`.

## Open first

| Need | Open |
|---|---|
| Skill procedure | `SKILL.md` |
| Project rules | `AGENTS.md` |
| Hang status (read) | `~/projects/assistant/bin/wrap-status.sh` |

## Layout

```text
SKILL.md   Procedure: gate → persist → receipt; hang semantics
AGENTS.md  Type, ownership, Standards pointer
```

## Edges

- Receipt path: `~/.local/state/session-wrap/<session_id>.md` — present = closed; missing after real work = hang.
- Receipts live outside the repo; this tree is skill source of truth only.
- Installed copies: `~/.claude/skills`, `~/.hermes/skills`, `~/.codex/skills`.

## Ignore by default

- `.git/`
