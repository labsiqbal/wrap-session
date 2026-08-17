---
name: wrap
description: Close a session cleanly. Owner gate on persist/git decisions, then write a wrap receipt.
disable-model-invocation: true
---

# Wrap

Close the current session cleanly. Chat is draft. Disk is truth.
`/wrap` always means: ask first, persist what the owner approves, then leave a
receipt that this session was closed.

Source of truth: `~/projects/skills-lab/wrap/`. Installed copies in
`~/.claude/skills`, `~/.hermes/skills`, `~/.codex/skills`.

## When to use

Owner types `/wrap` (or "wrap session", "tutup session") before leaving a
session with durable residue: decisions, code, ops moves, routing rules, or
work that must survive.

Skip pure chitchat with nothing to keep.

## Scope

Wrap is for standalone human-agent sessions outside the private orchestrator.
These never wrap and are never flagged as hanging:

- the firstmate orchestrator primary (sessions running under `~/firstmate`)
- `/firstmate` requests forwarded through Hermes (work runs in firstmate,
  the Hermes session is only a relay)
- Orca workers (sessions running under `~/orca/workspaces`)
- subagents, scouts, and validation agents (Hermes `subagent`/`tool` sources)

## Hang semantics

| Condition | Meaning |
|---|---|
| Receipt exists | Session closed cleanly |
| No receipt after real work | Session hanging: forgot `/wrap` or abandoned |
| Work still unfinished | Not a hang. Put it in backlog / wiki / tickets as **deferred** |

There is no `status: open` receipt. `/wrap` is always a clean close.

Read hang status (detector lives in this repo):

```bash
~/projects/skills-lab/wrap/bin/wrap-status.sh        # read-only report
~/projects/skills-lab/wrap/bin/wrap-status.sh init   # first run only: create receipt dir + rollout baseline
```

The report never writes. The only file the detector creates is the
`.enabled-at` baseline marker, and only via explicit `init`.

## Receipt

One file per session:

```text
~/.local/state/session-wrap/<session_id>.md
```

Header fields:

| Field | Values |
|---|---|
| `session_id` | harness id if known; else `local-YYYYMMDD-HHMMSS-<cwdslug>` |
| `project` | Index name, `(root)`, or `(luar workspace)` |
| `cwd` | absolute path |
| `harness` | hermes / claude / codex / other |
| `wrapped_at` | ISO-8601 |
| `next` | one first action for the next session |

Receipt body: Done / Decisions / Written / Git / Deferred / Next.
Re-wrap of same `session_id` overwrites (last wrap wins).

## Steps

### 1. Identify the session

Collect:

- `session_id`: `$HERMES_SESSION_ID` if set; else generate `local-...`
- `harness`: hermes if HERMES_* present, else infer; never invent a fake id
- `cwd` + best Index project match under `~/projects`
- `git status --short --branch` when cwd is a git work tree

Done when: receipt header fields can be filled without blanks.

### 2. Draft the Wrap Plan (do not write yet)

Show a short plan. Owner gate happens here.

```text
WRAP PLAN
project: ...
cwd: ...

Done:
- <outcome + evidence path/commit/URL>

Decisions to persist:
1. <decision> → propose write to <path>   # or skip

Deferred work:
- <item> → propose home: backlog / wiki/log / ticket / skip

Git:
- clean
- dirty, leave intentional
- commit proposed: <msg>
- push? no (default) / yes

Memory (stable facts only):
- <fact> | (none)

Next session starts with:
- <one action>
```

Rules:

- Prefer pointers to existing artifacts. Do not dump the chat.
- Ops progress/decisions → propose `wiki/log.md`.
- Coding work → propose backlog / ticket / docs / commit.
- Workspace routing/rules → propose `.standards/` / Index.
- Stable preference/env pitfall → agent memory only.
- Task progress, "Phase N done", commit SHAs as memory → **no**.
- Never auto-write, auto-commit, or auto-push in this step.

Done when: every durable residue is in Done, Decisions, Deferred, Git,
Memory, or consciously absent.

### 3. Owner gate

Ask the owner to choose:

1. which Decisions / Deferred / Memory actions to execute
2. Git: leave / commit / commit+push (push only if asked)
3. any edit to the plan

Accept forms like: `all`, selected numbers, free-text edits, or `batal`.

If aborted: write nothing; say wrap cancelled.

Done when: owner approved the action set (or cancelled).

### 4. Execute approved actions only

Run only approved writes/commits. After each, verify file exists / git state
matches the claim. Failures are reported; do not invent success.

Done when: every approved action is done or explicitly failed with reason.

### 5. Write the receipt

Create `~/.local/state/session-wrap/` if needed. Write:

```markdown
---
session_id: <id>
harness: <harness>
source: <tui|desktop|telegram|cli|other>
cwd: <abs>
project: <name>
wrapped_at: <ISO-8601>
next: <one line>
---

# Wrap · <project>

## Done
- ...

## Decisions
- ...

## Written
- path - what   # or (none)

## Git
- ...

## Deferred
- item → home   # or (none)

## Next
- ...
```

Done when: receipt file exists.

### 6. Confirm

Reply with:

- receipt path
- what was written / committed
- deferred items and where they live
- the single Next line

Stop. Do not start the next task unless the owner asks.

## Anti-patterns

- Writing before the owner answers the gate
- Dumping whole chat into `wiki/log.md`
- Inventing `status: open` / intentional hang receipts
- Leaving unfinished work only in chat with no deferred home
- Writing memory for task logs or temporary TODO state
- Committing or pushing without approval
- Using `/handoff` when the need is clean exit (`/handoff` = portability)

## Relation to other skills

| Need | Use |
|---|---|
| Clean exit / hang detection | **`/wrap`** |
| Portable packet to another agent/dir/harness | `/handoff` |
| Compress context, keep same session | `/compact` |
| Workspace sitrep | `sitrep` (reads wrap-status) |
