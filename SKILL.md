---
name: wrap-session
description: "Use when wrapping a session with durable handoff."
disable-model-invocation: true
---

# Wrap Session

Close current Hermes session cleanly. Chat is draft. Disk is truth.

`/wrap-session` means: inspect session residue, propose durable actions, wait for
owner approval, execute only approved actions, then write receipt.

## Use

Use before leaving session with code, decisions, documents, operational changes,
or unfinished work another session must resume.

Skip chitchat with nothing durable.

## Receipt

One receipt per session:

```text
~/.local/state/session-wrap/<session_id>.md
```

Use `$HERMES_SESSION_ID` when available. Otherwise generate
`local-YYYYMMDD-HHMMSS-<cwdslug>`.

Receipt front matter must contain:

- `session_id`
- `harness: hermes`
- `source`: `tui`, `desktop`, `telegram`, `cli`, or `other`
- `cwd`: absolute path
- `project`: nearest Git root name, nearest directory name, or `(root)`
- `wrapped_at`: ISO-8601 timestamp
- `next`: one first action

Body headings: Done, Decisions, Written, Git, Deferred, Next.

A receipt means clean close. Unfinished work is **deferred**, never an open
receipt. Re-wrap same session ID overwrites old receipt.

## Procedure

### 1. Inspect

Collect session ID, source, absolute current directory, project label, and—when
inside a Git worktree—`git status --short --branch`.

Completion: every receipt field has a truthful value.

### 2. Draft Wrap Plan

Do not write yet. Show:

```text
WRAP PLAN
project: ...
cwd: ...

Done:
- outcome + evidence path, commit, or URL

Decisions to persist:
1. decision → proposed path, or skip

Deferred work:
- item → proposed backlog, ticket, or document home

Git:
- clean, or dirty and intentional
- proposed commit message, if needed
- push: no by default

Memory:
- stable fact, or none

Next session starts with:
- one action
```

Point to existing artifacts. Do not copy whole chat into a document. Put every
unfinished item in a real home or explicitly mark it skipped.

### 3. Owner gate

Ask owner to approve or edit:

1. Decisions, Deferred, and Memory writes
2. Git action: leave, commit, or commit+push
3. Plan edits

Accept `all`, selected numbers, free-text edits, or `cancel`.

On cancel: write nothing and report cancellation.

### 4. Execute approved actions

Run only approved writes and Git actions. Verify each external effect before
claiming success. Report failures as failures.

### 5. Write receipt

Create parent directory when missing. Write:

```markdown
---
session_id: <id>
harness: hermes
source: <tui|desktop|telegram|cli|other>
cwd: <absolute path>
project: <project>
wrapped_at: <ISO-8601>
next: <one action>
---

# Wrap Session · <project>

## Done
- ...

## Decisions
- ...

## Written
- path — what, or (none)

## Git
- ...

## Deferred
- item → home, or (none)

## Next
- ...
```

Completion: receipt file exists at expected path.

### 6. Confirm

Reply with receipt path, files or Git changes made, deferred work and its home,
and Next line. Stop.

## Optional status report

Run companion detector through Hermes `terminal`:

```bash
bin/wrap-status.sh
bin/wrap-status.sh init
```

It reads Hermes `state.db` plus receipts. `init` is explicit and creates only
receipt directory plus rollout baseline. Without Hermes state database, it
reports receipts and exits successfully.
