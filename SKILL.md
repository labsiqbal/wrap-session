---
name: wrap
description: Close a session cleanly. Audit done/open/disk/git, write wrap receipt, mark closed or intentional open.
disable-model-invocation: true
---

# Wrap

Close the current session so the next harness (or tomorrow-you) is not guessing.
Chat is draft. Disk is truth. The wrap receipt is the session's hang-status.

Source of truth: `~/projects/skills-lab/wrap/`. Installed copies in
`~/.claude/skills`, `~/.hermes/skills`, `~/.codex/skills`.

## When to use

Owner types `/wrap` (or "wrap session", "tutup session") before leaving a
session that did real work: decisions, code, ops moves, routing rules, or open
questions that must survive.

Skip for pure chitchat with zero durable residue.

## Receipt (source of truth for hang status)

Write exactly one receipt per session:

```text
~/.local/state/session-wrap/<session_id>.md
```

| Field | Values |
|---|---|
| `status` | `closed` = done wrapping; `open` = intentional hang |
| `open_reason` | required when `status: open` - why still hanging |
| `session_id` | harness id if known; else `local-YYYYMMDD-HHMMSS-<cwdslug>` |
| `project` | Index name, or `(root)`, or `(luar workspace)` |
| `cwd` | absolute path |
| `harness` | hermes / claude / codex / other |

**Hang semantics**

- receipt `status: closed` → clean exit
- receipt `status: open` → hang **on purpose** (owner knows)
- **no receipt** after real work → hang **forgot /wrap** (or abandoned)

Do not invent other statuses.

Read hang status with:

```bash
~/projects/assistant/bin/wrap-status.sh
```

## Steps

### 1. Identify the session

Collect:

- `session_id`: `$HERMES_SESSION_ID` if set; else generate `local-...`
- `harness`: hermes if HERMES_* present, else infer; never guess a fake id
- `cwd` + best Index project match under `~/projects`
- `git status --short --branch` when cwd is a git work tree

Done when: you can fill the receipt header fields without blanks except
`open_reason` (only for open).

### 2. Draft the wrap (do not write yet)

Produce a short draft for the owner:

```text
WRAP DRAFT
status: closed | open
project: ...
cwd: ...

Done:
- <outcome + evidence path/commit/URL>

Open (priority order):
- <item> - next action

Disk writes proposed:
- <path> - <what>   # or (none)

Git:
- clean | dirty intentional | commit proposed: <msg>

Memory (stable facts only):
- <fact> | (none)

Skip (conscious):
- <thing> - why

Next session starts with:
- <one action>
```

Rules for the draft:

- Prefer pointers to existing artifacts over re-dumping chat.
- Ops progress/decisions → propose `wiki/log.md` entry.
- Coding work → propose backlog/ticket/docs/commit as appropriate.
- Workspace routing/rules → propose `.standards/` / Index change.
- Stable preference/env pitfall → propose agent memory only.
- Task progress / "Phase N done" / commit SHAs as memory → **no**.
- Never auto-commit, auto-push, or auto-write. Draft only in this step.

Done when: draft is on screen and every real residue of the session is either
in Done, Open, Disk, Git, Memory, or Skip.

### 3. Owner gate

Ask the owner to confirm:

1. `closed` or `open` (if open, get `open_reason` in one line)
2. which Disk / Git / Memory actions to execute (all / some / none)

If owner aborts: write nothing; say wrap cancelled.

Done when: owner chose status and the action set.

### 4. Execute approved actions only

Run only what the owner approved. After each write, verify the file exists /
git state matches the claim.

Done when: every approved action is done or explicitly failed with reason.

### 5. Write the receipt

Create `~/.local/state/session-wrap/` if needed. Write the receipt:

```markdown
---
session_id: <id>
harness: <harness>
source: <tui|desktop|telegram|cli|other>
cwd: <abs>
project: <name>
status: closed|open
open_reason: <only if open; else omit or "">
wrapped_at: <ISO-8601>
next: <one line>
---

# Wrap · <project> · <status>

## Done
- ...

## Open
- ...

## Disk
- path - what   # or (none)

## Git
- ...

## Memory
- ...

## Skip
- ...

## Next
- ...
```

Overwrite if the same `session_id` is re-wrapped (last wrap wins).

Done when: receipt file exists and frontmatter `status` matches the owner choice.

### 6. Confirm

Reply with:

- receipt path
- `status: closed|open` (+ reason if open)
- what was written / committed
- the single Next line

Stop. Do not start the next task unless the owner asks.

## Anti-patterns

- Dumping the whole chat into `wiki/log.md`
- Marking `closed` while Open items have no home on disk and no `open` status
- Writing memory for task logs or temporary TODO state
- Committing without owner approval
- Skipping the receipt because "nothing big happened" after real decisions
- Using `/handoff` instead of wrap when the need is close/hang status (handoff
  is for portability to another agent/dir/harness; wrap is for clean exit)

## Relation to other skills

| Need | Use |
|---|---|
| Clean exit / hang status | **`/wrap`** |
| Portable packet to another agent/dir/harness | `/handoff` |
| Compress context, keep same session | `/compact` |
| Workspace sitrep | `sitrep` (reads wrap-status) |
