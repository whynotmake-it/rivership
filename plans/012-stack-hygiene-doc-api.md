# Plan 012: Remove committed dartdoc output from the jj stack and gitignore it

> **Executor instructions**: This plan mutates jj history in the user's repo —
> it must be executed **by or with the maintainer in the main workspace**, not
> in an isolated worktree (the target is an unpushed jj change, not the
> working copy). Follow the steps exactly; jj operations are undoable via
> `jj undo` / `jj op restore`, but do not improvise revsets. When done, update
> the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: `jj log -r kmyzpvqn --no-pager` — the change
> must still exist, be mutable (not `◆`), and describe itself as `examplo`.
> If it was already rewritten, pushed, or made immutable, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW (history edit on an unpushed, mutable change; `jj undo` recovers)
- **Depends on**: none
- **Category**: dx / hygiene
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

The mutable jj change `kmyzpvqn` ("examplo") accidentally commits ~6,000 lines
of generated dartdoc output at the **repo root** (`doc/api/__404error.html`,
`doc/api/static-assets/docs.dart.js` — 4,522 lines, a binary favicon, etc.).
Generated docs don't belong in version control: they bloat the repo, create
noisy diffs, and the root-level `doc/` location suggests `dart doc` was run
from the wrong directory (the motor package keeps its real doc assets in
`packages/motor/doc/`). The change description "examplo" is also a placeholder
that should be fixed before this stack goes anywhere.

## Current state

Verified at planning time:

- `jj log` shows the mutable stack: `@` (empty) → `kmyzpvqn` "examplo" →
  `uwytqtmn` "fix(example): loaders timing" → `olusqwss` (dev bookmark, immutable).
- `jj diff -r kmyzpvqn --stat` — first 14 entries are `doc/api/**` files
  (102 + 1 + 149 + 1 + 81 + 4522 + 16 + binary + 118 + 781 + 1 + 45 + 1 + 1 lines);
  the remaining ~21 entries are legitimate example-app work under
  `packages/motor/example/`.
- The repo root `.gitignore` has no `doc/api` entry (checked with ripgrep).
- The repo is colocated (git + jj). Never use mutating git commands here.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Inspect change | `jj diff -r kmyzpvqn --stat --no-pager` | file list as above |
| Remove files from a change | see Step 1 | `doc/api` gone from the stat |
| Verify stack integrity | `jj log --no-pager` | same topology, new commit ids |

## Scope

**In scope**:
- The jj change `kmyzpvqn` (file removal + description fix)
- Root `.gitignore` (add ignore rules — as part of the same change or a new one)

**Out of scope** (do NOT touch):
- The example-app changes inside `kmyzpvqn` — they stay.
- Immutable changes (`◆`) below the dev bookmark.
- `packages/motor/doc/` — real, hand-maintained assets (gifs) plus the
  package-level generated `api/` dir; only the repo-root `doc/api` is in scope.
  (If `packages/motor/doc/api` is also generated output committed by an
  earlier immutable change, note it in the report but do not rewrite
  immutable history.)

## Git workflow

jj only. Every step is undoable with `jj undo` (or `jj op log` +
`jj op restore <op>` for multi-step recovery).

## Steps

### Step 1: Remove doc/api from the change

The files exist in `kmyzpvqn`'s tree. Restore those paths from its parent so
the change no longer introduces them:

```bash
jj restore --from uwytqtmn --to kmyzpvqn doc/
```

(`jj restore --from <parent> --to <change> <path>` resets the path in the
target change to the parent's state — the parent has no `doc/` at the root, so
this deletes the files from the change. If this jj version's flag spelling
differs, consult `jj restore --help`; the equivalent older form is
`jj restore --changes-in kmyzpvqn doc/` or editing the change via
`jj edit kmyzpvqn && rm -rf doc && jj squash`. Prefer the non-checkout form.)

**Verify**: `jj diff -r kmyzpvqn --stat --no-pager` → no `doc/` entries;
example-app entries unchanged; `jj log --no-pager` → stack topology unchanged
(descendants auto-rebased).

### Step 2: Ignore generated docs

In the working copy (`@`), add to the root `.gitignore`:

```
# dartdoc output
doc/api/
packages/*/doc/api/
```

Then describe the working-copy change or squash it where the maintainer
prefers (default: leave it in `@` with `jj desc -m "chore: ignore dartdoc output"`).

**Verify**: `rg -n "doc/api" .gitignore` → both lines present.

### Step 3: Fix the placeholder description

```bash
jj desc -r kmyzpvqn -m "feat(example): <accurate summary of the example redesign work>"
```

Derive the summary from the change's actual content
(`jj diff -r kmyzpvqn --stat`): it adds example pages (curve_trap,
motion_character, payment_success, pull_to_refresh, thermostat,
two_dimensions, why_motion, the_spring), removes others (drag_reorder_list,
flip_card, segmented_selector, staggered_entrance), reworks `main.dart`, and
adds `example/test/pages_smoke_test.dart`. Match the repo's conventional-commit
style (see `jj log` history, e.g. "feat: example redesign (#287)").

**Verify**: `jj log --no-graph -r kmyzpvqn -T 'description' --no-pager` →
the new message (verify with the change id, not `@`).

## Test plan

No code behavior changes. Gate: `jj log` topology unchanged, the example app
still analyzes (`cd packages/motor/example && dart analyze` → exit 0) since
its files were untouched.

## Done criteria

- [ ] `jj diff -r kmyzpvqn --stat` contains no `doc/` paths
- [ ] Root `.gitignore` ignores `doc/api/` and `packages/*/doc/api/`
- [ ] `kmyzpvqn` has a descriptive conventional-commit message
- [ ] `dart analyze` in `packages/motor/example` exits 0
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `kmyzpvqn` is immutable, pushed, or already rewritten (drift check).
- `jj restore` variants all fail — report the jj version (`jj --version`) and
  the error rather than falling back to git commands.
- Removing `doc/` changes any file under `packages/` in the stat output
  (would indicate a wrong revset).

## Maintenance notes

- If docs publishing is wanted later, generate into an ignored dir and deploy
  from CI instead of committing output.
- Check whether `packages/motor/doc/api` (committed in an immutable change)
  should be cleaned up in a future change on top — noted, not done here.
