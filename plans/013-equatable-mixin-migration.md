# Plan 013: Migrate off deprecated EquatableMixin so analysis is clean on equatable 2.1+

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/step.dart packages/motor/lib/src/track.dart packages/motor/lib/src/track_timeline.dart packages/motor/lib/src/motion_sequence.dart packages/snaptest/lib/src/snaptest_settings.dart packages/heroine/lib/src/shuttle_builders.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW (mechanical mixin swap; equality semantics identical)
- **Depends on**: none (trivial merge conflict expected with Plan 007 on
  `motion_sequence.dart` class-declaration lines — both add/edit lines at the
  class headers; resolve at merge time)
- **Category**: dx / migration
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

equatable 2.1.0 deprecates `EquatableMixin` ("use Equatable as a mixin
instead"). The workspace's pub constraints allow `>=2.0.0 <3.0.0`, so any
fresh resolution (new checkout, CI, worktree — anywhere the untracked
`pubspec.lock` doesn't pin 2.0.8) picks 2.1.0 and `dart analyze --fatal-infos`
fails with `deprecated_member_use` infos in three packages. This already broke
four executor runs. The fix is the migration the deprecation message asks for:
use `Equatable` as a mixin (possible since 2.1.0, where `Equatable` became a
`mixin class`), and raise the constraint floor to 2.1.0 so the mixin usage is
valid at the lowest allowed version.

## Current state

All uses of `EquatableMixin` across the workspace (verified at planning time):

| File | Line | Declaration |
|------|------|-------------|
| `packages/motor/lib/src/step.dart` | 9 | `sealed class Step<T extends Object> with EquatableMixin {` |
| `packages/motor/lib/src/track.dart` | 165 | `class TrackValue<T extends Object> with EquatableMixin {` |
| `packages/motor/lib/src/track.dart` | 185 | `class TrackAnimation<T extends Object> with EquatableMixin {` |
| `packages/motor/lib/src/track_timeline.dart` | 10 | `class TrackTimeline with EquatableMixin {` |
| `packages/motor/lib/src/motion_sequence.dart` | 36 | `abstract class MotionSequence<P, T extends Object> with EquatableMixin {` |
| `packages/snaptest/lib/src/snaptest_settings.dart` | 58 | `class SnaptestSettings with EquatableMixin {` |
| `packages/heroine/lib/src/shuttle_builders.dart` | 11 | `abstract class HeroineShuttleBuilder with EquatableMixin {` |

Also check for uses in `test/` directories of all three packages (`grep -rn
"EquatableMixin" packages/*/test`) and migrate any found the same way.

Constraints to bump (all currently `equatable: ">=2.0.0 <3.0.0"`):
- `packages/motor/pubspec.yaml:16`
- `packages/snaptest/pubspec.yaml:26`
- `packages/heroine/pubspec.yaml:16`

`packages/heroine/lib/src/heroines.dart` imports equatable but declares no
`EquatableMixin` in the grep — inspect it; if it uses `Equatable` as a
superclass or only `props`, leave it unchanged.

Environment facts:
- The repo is a pub workspace (root `pubspec.yaml` has a `workspace:` list;
  member packages have `resolution: workspace`). Run `dart pub get` from the
  repo root of your worktree; the root `pubspec.lock` is untracked/ignored.
- Do NOT copy any lockfile from the maintainer's checkout for this plan — the
  whole point is to be clean under a fresh resolution that picks equatable
  2.1.0. Verify `grep -A2 "^  equatable" pubspec.lock` shows `2.1.0` (or
  later) after pub get.
- Equality semantics of `Equatable`-as-mixin and `EquatableMixin` are
  identical (`props`-based `==`/`hashCode`); `stringify` defaults may differ
  in `toString` only, which nothing in these packages asserts on.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Resolve deps | `dart pub get` (worktree root) | exit 0; lockfile shows equatable ≥2.1.0 |
| Analyze motor | `cd packages/motor && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Analyze snaptest | `cd packages/snaptest && dart analyze --fatal-infos` | exit 0 |
| Analyze heroine | `cd packages/heroine && dart analyze --fatal-infos` | exit 0 |
| Test motor | `cd packages/motor && flutter test` | all pass |
| Test snaptest | `cd packages/snaptest && flutter test` | all pass |
| Test heroine | `cd packages/heroine && flutter test` | all pass |

## Scope

**In scope**:
- The seven declarations in the table above (`with EquatableMixin` →
  `with Equatable`), plus any additional `EquatableMixin` uses found in the
  three packages' `test/` dirs.
- The three `pubspec.yaml` equatable constraints → `">=2.1.0 <3.0.0"`.
- CHANGELOG entries: motor, snaptest, heroine — one line each under their
  unreleased/next section ("migrate off deprecated EquatableMixin; equatable
  floor raised to 2.1.0").

**Out of scope** (do NOT touch):
- Any other dependency constraint or lockfile commit.
- Rewriting equality by hand / removing equatable.
- The other workspace packages (no EquatableMixin uses found).
- `props` implementations — they stay exactly as they are.

## Git workflow

Isolated worktree: plain git, single commit, e.g.
`refactor: migrate EquatableMixin to Equatable mixin (equatable 2.1+)`.

## Steps

### Step 1: Fresh resolution

`dart pub get` from the worktree root. Verify the lockfile resolves equatable
≥2.1.0. Reproduce the baseline failure once for the record:
`cd packages/motor && dart analyze --fatal-infos` → expect the 5
`EquatableMixin` deprecation infos.

### Step 2: Migrate the declarations

Replace `with EquatableMixin` → `with Equatable` at the seven sites (and any
test-dir finds). Imports stay `package:equatable/equatable.dart` (it exports
both symbols). Bump the three pubspec constraints to `">=2.1.0 <3.0.0"` and
re-run `dart pub get`.

**Verify**: all three `dart analyze --fatal-infos` commands → exit 0;
`grep -rn "EquatableMixin" packages/motor packages/snaptest packages/heroine --include="*.dart"` → no matches.

### Step 3: Tests

Run the three packages' test suites.

**Verify**: all pass. Equality-dependent tests (motor's `track_test.dart`
timeline equality, `sequence_motion_builder_test.dart` equality/hash groups,
snaptest settings tests, heroine shuttle-builder tests) are the meaningful
signal — if any equality test fails, STOP (semantics changed).

### Step 4: CHANGELOGs

One-line entry in each of the three packages' CHANGELOGs.

**Verify**: re-run analyze once more after edits → exit 0.

## Done criteria

- [ ] `grep -rn "EquatableMixin" packages --include="*.dart"` → no matches
- [ ] All three packages: `dart analyze --fatal-infos` exit 0 under a FRESH
      resolution (equatable ≥2.1.0 in the lockfile)
- [ ] All three packages: `flutter test` exit 0
- [ ] Three pubspec constraints read `">=2.1.0 <3.0.0"`
- [ ] No lockfile committed (`git status` clean after commit)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `Equatable` cannot be used as a mixin at 2.1.0 (compile error mentioning
  "mixin" on the `with Equatable` clause) — the migration target is wrong;
  report the exact error and equatable version.
- Any equality-dependent test changes outcome after the swap.
- Raising the floor to 2.1.0 causes a version-solving conflict anywhere in the
  workspace (report the solver output).

## Maintenance notes

- Plans 007 and 011 edit `motion_sequence.dart` / `step.dart` class headers;
  whichever merges second resolves a one-line conflict on the declaration
  lines.
- After this lands, the "copy the maintainer's lockfile" workaround given to
  earlier executors becomes unnecessary; reviewers should stop issuing it.
