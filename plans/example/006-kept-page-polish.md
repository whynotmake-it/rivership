# Plan 006: Polish the kept flagships — comments and idiom consistency, no redesign

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example/lib/pages/toggle.dart packages/motor/example/lib/pages/pull_to_refresh.dart packages/motor/example/lib/pages/card_stack.dart packages/motor/example/lib/pages/payment_success.dart`
> Plan 005 may have added a `next:` parameter to these pages — that diff is
> expected. Any other drift: compare excerpts before proceeding; on a
> mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (comments + mechanical idiom unification; no behavior change)
- **Depends on**: none (rebase after plan 005 to avoid trivial conflicts)
- **Category**: docs / dx (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

The four kept flagship pages are the examples users will copy from most, and
a pedagogy audit found each has a teaching blemish: unexplained non-obvious
API choices, three different value-reading styles in one file, and silent
cleverness. The maintainer chose comment-level polish only — the pages'
behavior and structure are liked and must not change. Every edit in this
plan is either a comment or a mechanical idiom unification with identical
runtime behavior.

## Current state

All line numbers at `93af2da` (they may shift slightly if plan 005 added a
`next:` param — match on content, not line number).

**`packages/motor/example/lib/pages/toggle.dart`** (liked; best comments in
the app at lines 117-122 and 131-133 — the standard to extend):
- THREE value-reading styles in one file, no guidance on which is idiomatic:
  - `ValueListenableBuilder(valueListenable: _c, builder: (context, v, _) => ... v(_value)...)` (line 150-153)
  - `AnimatedBuilder` + explicit generics `_controller.value<double>(_burst)` (lines 272-288)
  - `AnimatedBuilder` + plain `.value` on a `SingleMotionController` (lines 365-369)
- `.bouncySpring().trimmed(fromEnd: .5)` at line 252 — an advanced wrapper
  (skip the first half of the spring) dropped without a word.
- Same track value clamped differently in one builder: `.clamp(0.0, 1.0)`
  for the fill color (line 153) vs `.clamp(0.0, 1.05)` for thumb position
  (line 165) — deliberate (lets the thumb overshoot slightly while the color
  saturates) but unexplained.

**`packages/motor/example/lib/pages/pull_to_refresh.dart`** (liked):
- The bool + future chain at lines 67-86 (`_refreshing`, `.whenComplete`) is
  exactly the state juggling `PhaseTrackController` was built to replace. The
  maintainer REJECTED rewriting it (recorded in `plans/example/README.md`);
  instead, add an honest comment: this page manages its two states manually
  because there are only two and one timer — see the Phases page
  (`pages/phases.dart`, from plan 003) for the named-state alternative.
- The spin trick at lines 71-80 (`_spin.to(current + math.pi * 8, ...)` on a
  linear curve, while `_onDragUpdate` also writes `_spin` at line 47) is
  subtle and uncommented — one comment on why the target is relative to the
  current value.

**`packages/motor/example/lib/pages/card_stack.dart`** (liked):
- `velocityTracking: .off()` at line 81 — never explained. The reason is a
  great lesson: the drag feeds positions via `set()` (which would otherwise
  make the tracker derive velocity from those samples) but the release hands
  the gesture recognizer's velocity in explicitly via
  `withVelocity: [_offset.value(velocity)]` (line 119), so tracking is
  redundant and could double-count. Write that comment.
- Top-level `final _offset = Track<Offset>(...)` at line 11, shared by all
  three `_DragCard` states — silently relies on the track-identity rule.
  One comment: a `Track` is an identity key; sharing one instance across
  cards is safe because each card has its own controller.

**`packages/motor/example/lib/pages/payment_success.dart`** (liked; already
the best-commented timeline in the app):
- The only gap: `.bouncySpring(extraBounce: .4).trimmed(fromEnd: .5)` at
  line 132 — same unexplained `trimmed` as toggle.dart. One comment (write
  it once here, once in toggle.dart): `.trimmed(fromEnd: .5)` plays only the
  first half of the spring's arc — here, the pop rises with spring character
  but hands off to the settle `.to(1)` before the wobble.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0 |
| Tests   | `cd packages/motor/example && flutter test` | all pass |

## Scope

**In scope** (comments + one mechanical unification, nothing else):
- `packages/motor/example/lib/pages/toggle.dart`
- `packages/motor/example/lib/pages/pull_to_refresh.dart`
- `packages/motor/example/lib/pages/card_stack.dart`
- `packages/motor/example/lib/pages/payment_success.dart`

**Out of scope**:
- ANY behavior change: no motion retuning, no restructuring, no gesture
  changes, no widget-tree reshaping beyond the reading-style unification.
- All other pages; `packages/motor/lib/`.

## Git workflow

- Isolated worktree; branch `agent/example-006-polish`; rebase on plan 005's
  result if it has landed.
- One commit: `docs(motor_example): explain non-obvious API choices in kept pages`.
- Do NOT push or open a PR.

## Steps

### Step 1: Unify toggle.dart's value-reading style

Pick ONE style for `TrackController` reads and use it for both track-based
widgets in the file: `ValueListenableBuilder<TrackValueReader>(valueListenable: _c, builder: (context, value, _) => ...value(_track)...)`
(the style at line 150 — it's the most self-documenting: the builder
receives the reader). Convert the `_LikeButton`'s `AnimatedBuilder` +
`_controller.value<double>(...)` reads (lines 272-293) to it. Leave the
`_RotateToggle`'s `SingleMotionController` + `AnimatedBuilder` (line 365)
as-is — different controller type, plain `.value` IS its idiom — but add a
one-line comment saying exactly that, so the file reads as two idioms by
design instead of three by accident. Behavior must be identical.

**Verify**: `cd packages/motor/example && flutter test` → all pass;
`dart analyze --fatal-infos` → exit 0.

### Step 2: Add the comments

All comments listed in "Current state": trimmed-wrapper (toggle line ~252 +
payment_success line ~132), clamp asymmetry (toggle ~153/165),
manual-two-state rationale + pointer to the Phases page (pull_to_refresh
~67), relative spin target (pull_to_refresh ~71), velocityTracking-off
rationale (card_stack ~81), track-identity note (card_stack ~11). Match the
prose quality of `toggle.dart:117-122` — explain WHY, one to three lines,
no restating what the code says.

**Verify**: `dart analyze --fatal-infos` → exit 0 (comment lines must respect
the 80-char lint).

### Step 3: Full gate

**Verify**: `flutter test` → all pass. Then confirm no behavior change:
`git diff` contains ONLY comment lines and the step-1 reading-style
conversion (no changed motion parameters, durations, targets, or thresholds
— review your own diff hunk by hunk).

## Test plan

No new tests — existing smoke + behavioral tests must pass unchanged. The
step-3 diff self-review is the behavioral gate.

## Done criteria

- [ ] toggle.dart has at most two reading styles, each with a one-line
      idiom note.
- [ ] All seven comments from step 2 present.
- [ ] `git diff` shows no non-comment behavioral change besides the
      reading-style conversion.
- [ ] `dart analyze --fatal-infos` exits 0; `flutter test` exits 0.
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- The `ValueListenableBuilder` conversion in step 1 changes behavior or
  fails a test (e.g. generics don't line up) after one fix attempt — revert
  the conversion, ship the comments only, and note it.
- The excerpted code doesn't match (beyond plan 005's `next:` addition).
- You feel the urge to fix anything behavioral you notice — report it
  instead; this plan is comments only.

## Maintenance notes

- If pull_to_refresh is ever rewritten on `PhaseTrackController` (rejected
  for now), delete the step-2 rationale comment along with it.
- Reviewer: read the diff as prose — every comment should teach something a
  copying user would otherwise miss.
