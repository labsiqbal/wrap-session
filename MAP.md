# MAP · wrap-session

## What

Clean session-exit skill: owner gate on persist/git, then write a wrap receipt under `~/.local/state/session-wrap/`.

## Open first

| Need | Open |
|---|---|
| Skill procedure | [SKILL.md](SKILL.md) |
| Project rules | [AGENTS.md](AGENTS.md) |
| Hang status (read) | [bin/wrap-status.sh](bin/wrap-status.sh) |
| Detector tests | `tests/run-tests.sh` |

## Layout

```text
SKILL.md            Procedure: gate → persist → receipt; hang semantics; scope
AGENTS.md           Type, ownership, Standards pointer
bin/wrap-status.sh  Detector: read-only hang report; `init` for first-run baseline
tests/              Plain-bash test suite (fixtures.sh, run-tests.sh)
```

## Edges

- Receipt path: `~/.local/state/session-wrap/<session_id>.md` — present = clean close; missing after real work = likely missed wrap.
- Receipts live outside the repository.
- Detector scope: standalone human Hermes sessions; `subagent` and `tool` sources are excluded.
- Detector writes nothing except `.enabled-at`, and only via `bin/wrap-status.sh init`.
- Install by copying this directory to `~/.hermes/skills/wrap-session`.

## Ignore by default

- `.git/`
