# Plan 011: Rename `Step` to `TrackStep` to resolve the Material collision before 2.0 ships

> **Executor instructions**: The name decision is already made and
> maintainer-approved: **`TrackStep`, root-only rename** (subclasses keep
> their names). Step 1 verifies the decision's assumptions; if verification
> disqualifies `TrackStep`, STOP and report — do not substitute a different
> name. Run every verification command and confirm the expected result before
> moving to the next step. When done, update the status row for this plan in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 1a2538f..HEAD -- packages/motor/lib/src/step.dart packages/motor/lib/motor.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2 (cheap now, breaking after 2.0 ships)
- **Effort**: S–M (root-only rename; subclasses and pattern matches untouched)
- **Risk**: LOW–MED (mechanical; mitigated by compiler + full suite)
- **Depends on**: none — but execute AFTER the still-open plans that cite
  `Step` call sites (005 and 009; plans 001–004, 006–008, and 013–016 have
  already landed) to avoid rebasing their diffs over a rename
- **Category**: direction / API design
- **Planned at**: commit `1a2538f`, 2026-07-16 (originally `d36d4cb`,
  2026-07-14)
- **Refreshed**: 2026-07-16 against `1a2538f` — plan 015 deleted
  `legacy/legacy_motion_controller.dart` and replaced it with the
  `controllers/sequence_motion_controller.dart` part file (new `Step.to`/
  `Step.sync` call sites); reference-site list updated and survey counts
  marked recompute-at-execution; added the plan-013 anchor facts on
  `step.dart` (`EquatableMixin` + `// ignore: deprecated_member_use` on the
  root declaration, which the rename must preserve); `lib/motor.dart` export
  is now line 18. Decision content untouched.

## Why this matters

Motor exports `Step<T>` (`lib/src/step.dart`), and Flutter's Material library
exports `Step` (the `Stepper` row widget). Every file that imports both
`package:motor/motor.dart` and `package:flutter/material.dart` — i.e. nearly
every screen in a typical app — gets an ambiguous-import error and needs
`import 'package:flutter/material.dart' hide Step;` (or a prefix) forever.
Motor 2.0 is unreleased: renaming now costs one mechanical sweep; renaming
after release is a breaking change with a deprecation cycle.

Mitigating factor to weigh honestly: thanks to Dart dot-shorthands, call sites
mostly write `.to(...)` / `.hold(...)` inside typed lists, so the literal name
`Step` appears mainly in type annotations (`List<Step<T>>`), custom-widget
signatures, and the docs. The collision still bites — dot-shorthands only
resolve when the context type is already unambiguous, and the ambiguous import
breaks that context.

## Current state

- `packages/motor/lib/src/step.dart` — `Step<T>` (sealed, line 10), subclasses
  `StepTo` (line 61), `StepFree` (91), `StepHold` (106), `StepAt` (119),
  `SyncStep` (165). All public, exported via `lib/motor.dart:18`.
- Anchor facts from plan 013 (verified at `1a2538f`): the root declaration is
  `sealed class Step<T extends Object> with EquatableMixin` and carries a
  `// ignore: deprecated_member_use` comment on the line above it
  (`step.dart:9`, suppressing the `EquatableMixin` deprecation — a
  maintainer-approved suppression, not a leftover). The rename MUST keep both
  the `with EquatableMixin` clause and that ignore comment on the renamed
  `TrackStep` declaration, or `dart analyze --fatal-infos` fails.
- Public API references to `Step` outside `step.dart` (all must follow the
  rename): `Track.to`/`Track.call`/`Track.free`/`animationFromUntypedSteps`
  (`track.dart`), `TrackAnimation.steps` (`track.dart:200`),
  `StepPlayback` (`simulations/step_playback.dart` — internal),
  `MotionController.play(List<Step<T>>)` (`controllers/motion_controller.dart:299-300`),
  the deprecated `SequenceMotionController`
  (`controllers/sequence_motion_controller.dart`, a `part` of
  `motion_controller.dart` — plan 015 DELETED the old
  `legacy/legacy_motion_controller.dart` and this part file replaced it; it
  builds `Step.to`/`Step.sync` chains in `_playChain` at lines 133–153 and
  overrides `play(List<Step<T>>)` at lines 352–359),
  `TrackController` internals (incl. `controllers/_track_slot.dart`),
  README "Tracks & Steps" section.
- Count the blast radius during Step 1 with:
  `grep -rn "\bStep\b" packages/motor/lib packages/motor/example/lib | grep -v material | wc -l`.
  Any reference counts recorded in earlier drafts of this plan predate plan
  015's controller rewrite — recompute all survey counts at execution time;
  do not treat historical counts as expectations.
- Material's conflicting symbol: `Step` in `package:flutter/material.dart`
  (Stepper). No conflict from `widgets.dart` or `cupertino.dart`.
- The example app imports material broadly — check how it currently avoids
  the clash (`grep -rn "hide Step\|as motor" packages/motor/example/lib`): at
  planning time AND at the 2026-07-16 refresh there were **zero** workarounds
  in the repo, because library code imports `flutter/widgets.dart` (not
  material) and the example may not name the type. Do not conclude from this that consumers are unaffected —
  app code that types `List<Step<double>>` with material imported is the
  normal case.

## Candidate names (evaluate in Step 2)

**Decision (2026-07-14, maintainer + advisor): `TrackStep`.** Root-only
rename — the subclasses keep their current names (see constraints below).
Step 1's collision verification still runs; if it disqualifies `TrackStep`,
STOP and report rather than substituting another name.

History, for context (do not re-propose): round 1 candidates `MotionStep`,
`Keyframe`, `Cue`, `Beat`, `Move` were rejected by the maintainer. Round 2
produced the table below; the maintainer picked `TrackStep` over the advisor's
initial `Segment` recommendation because the `Track*` family already exists
(`Track`, `TrackAnimation`, `TrackValue`, `TrackTimeline`, `TrackController`,
`TrackBuilder`), it keeps the word "step" in prose, and it permits the
root-only rename.

Round 2 candidates as evaluated:

| Candidate | Reads as | For | Against |
|-----------|----------|-----|---------|
| `Segment` | `Segment.to(x)`, `List<Segment<T>>` | Already the *internal* vocabulary: `StepPlayback` doc says "advances segment-by-segment" and uses `_segmentIsDone`/`_segmentStartSeconds` (`step_playback.dart:10-11,471-489`); standard DAW/video-editor term for a piece on a track in a timeline, matching motor's Track/Timeline metaphor; no bare-name conflict in Flutter (`ButtonSegment` does not collide) | Three syllables; autocomplete proximity to `ButtonSegment` |
| `Span` | `Span.to(x)`, `List<Span<T>>` | Short; a step occupies a span of time on its track; no bare `Span` in Flutter (`TextSpan`/`InlineSpan` don't collide) | Brushes against legacy `MotionSequence.spanning` terminology (deprecated, removed in 3.0); connotes extent more than instruction |
| `Pose` | `Pose.to(x)`, `Pose.hold(d)` | Character-animation vocabulary; `Pose.hold` reads naturally; zero conflicts | `.free`/`.sync` are not poses; names the destination, not the instruction |
| `TrackStep` | `TrackStep.to(x)` | Keeps the word "step"; steps belong to tracks; zero conflicts | Compound-prefix style, same family as the rejected `MotionStep` |
| `Leg` | `Leg.to(x)` | Shortest; journey metaphor ("the last leg") | Quirky; `SyncLeg` reads oddly |
| Keep `Step`, document `hide Step` | — | Zero churn | Permanent tax on every consumer; the reason this plan exists |

Constraints and scope of the rename under the `TrackStep` decision:

- **Root-only rename.** Only the sealed root `Step<T>` collides with
  Material's `Step`; the subclasses `StepTo`, `StepAt`, `StepHold`,
  `StepFree`, `SyncStep` collide with nothing in the Flutter SDK and keep
  their names. This preserves every `case StepTo(:final value)` pattern match
  and most existing docs/tests untouched. (An earlier draft of this plan
  claimed the subclasses were "equally colliding-adjacent" — that was
  incorrect; verify in Step 1 that none of the five subclass names exists in
  `package:flutter/material.dart`.)
- Factory names (`.to`, `.at`, `.hold`, `.free`, `.sync`) are unchanged, so
  dot-shorthand call sites are unaffected.
- The README's teaching prose keeps the word "step" ("steps describe what a
  track does"); only type references change to `TrackStep`.
- Compatibility typedef:
  `@Deprecated('Renamed to TrackStep; will be removed in motor 3.0.')
  typedef Step<T extends Object> = TrackStep<T>;`
  kept through 2.x for early adopters of the unreleased branch, removed
  in 3.0. No per-subclass typedefs are needed (subclasses don't rename).

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |
| Example analyze | `cd example && dart analyze` | exit 0 |
| Repo-wide check | from repo root: `melos analyze` | exit 0 |

## Scope

**In scope** (Steps 3–5, post-approval):
- `packages/motor/lib/**` (rename + deprecated typedef)
- `packages/motor/test/**` (mechanical rename)
- `packages/motor/example/lib/**` (mechanical rename)
- `packages/motor/README.md`, `packages/motor/CHANGELOG.md`
- Other workspace packages that import motor (check:
  `grep -rln "package:motor" packages --include=pubspec.yaml`)

**Out of scope**:
- Renaming `Track`, `TrackAnimation`, or any other symbol.
- Renaming the *concept* in prose — README keeps saying "steps".
- `LoopMode`, `PhaseTransition` — no conflicts.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Single commit for the mechanical rename:
`feat(motor)!: rename Step to TrackStep to avoid Material collision`.

## Steps

### Step 1: Verify the decision's assumptions

1. Reproduce the collision concretely: create a scratch test
   `test/src/step_name_collision_test.dart` containing
   `import 'package:flutter/material.dart'; import 'package:motor/motor.dart';`
   and a `List<Step<double>> steps = [];` declaration; run `dart analyze` on it
   and record the exact error. Keep the file — Step 4 converts it into the
   permanent regression test.
2. Verify `TrackStep` and the five kept subclass names (`StepTo`, `StepAt`,
   `StepHold`, `StepFree`, `SyncStep`) do not exist in the Flutter SDK:
   `grep -rn "class TrackStep\b\|class StepTo\b\|class StepAt\b\|class StepHold\b\|class StepFree\b\|class SyncStep\b" $(dirname $(which flutter))/../packages/flutter/lib`
   → no matches. If any matches, STOP and report.
3. Count the rename's blast radius (root-name references only):
   `grep -rn "\bStep<\|\bStep\.\b\|\bStep\b" packages/motor/lib packages/motor/test packages/motor/example/lib | grep -v "StepTo\|StepAt\|StepHold\|StepFree\|SyncStep\|StepPlayback\|onStep\|stepIndex" | wc -l`
   and record the count in the commit description.

**Verify**: the scratch test's recorded ambiguity error mentions both
`package:flutter/src/material/stepper.dart` and `package:motor/src/step.dart`;
the SDK grep in (2) returns nothing.

### Step 2: Rename the sealed root to TrackStep

In `packages/motor/lib/src/step.dart`:

1. Rename `sealed class Step<T extends Object>` → `TrackStep<T extends Object>`
   and update the five subclass `extends Step<T>` clauses to
   `extends TrackStep<T>`. Subclass names stay as they are. Keep the
   `with EquatableMixin` clause and the `// ignore: deprecated_member_use`
   comment (currently `step.dart:9`) attached to the renamed declaration —
   see the plan-013 anchor facts in Current state.
2. Update the factory doc comments and the class dartdoc ("A single
   instruction in a track animation") — prose keeps the word "step".
3. Add at the bottom of `step.dart`:

```dart
/// The former name of [TrackStep].
@Deprecated('Renamed to TrackStep; will be removed in motor 3.0.')
typedef Step<T extends Object> = TrackStep<T>;
```

**Verify**: `dart analyze --fatal-infos` (packages/motor) → only
`deprecated_member_use_from_same_package` diagnostics at remaining internal
`Step` call sites (fixed next step), or exit 0 if none.

### Step 3: Sweep internal references

Sweep `lib/`, `test/`, `example/lib/` replacing *root-name* references only
(word-boundary matches: `Step<` type arguments, `Step.to(`, `Step.at(`,
`Step.hold(`, `Step.free(`, `Step.sync(`, `is Step\b`, `List<Step`).
Do NOT touch: `StepTo`, `StepAt`, `StepHold`, `StepFree`, `SyncStep`,
`StepPlayback` (internal, unexported — keeps its name), `onStep`,
`stepIndex`, `_lastStepByTrack`, or the word "step" in comments/prose.
Known reference sites from planning (re-verified 2026-07-16): `track.dart`
(`Track.to`/`call`/`free`/`animationFromUntypedSteps`, `TrackAnimation.steps`),
`controllers/motion_controller.dart:299-300` (`play(List<Step<T>>)`),
`controllers/sequence_motion_controller.dart` (`_playChain`'s
`Step.to`/`Step.sync` chain at lines 133–153, `play` override at 352–359),
`simulations/step_playback.dart`, `controllers/track_controller.dart`,
`controllers/_track_slot.dart`. (`legacy/legacy_motion_controller.dart` no
longer exists — deleted by plan 015.)

**Verify**: `dart analyze --fatal-infos` → exit 0 (no deprecation warnings
left inside the package); `flutter test` → all pass;
`cd example && dart analyze` → exit 0.

### Step 4: Docs + permanent regression test

README Tracks & Steps section: update code samples that name the type
(`Step.to(...)` → `TrackStep.to(...)` where written long-form; dot-shorthand
samples are unchanged); keep the prose word "step". Convert Step 1's scratch
file into a permanent regression test: material + motor co-imported, a
`List<TrackStep<double>>` declared and used with a trivial runtime expect —
the file analyzing clean IS the assertion.
CHANGELOG: **BREAKING** entry (vs the unreleased 2.0 dev branch) with the
typedef escape hatch.

**Verify**: `melos analyze` from repo root → exit 0.

### Step 5: Workspace sweep

For every other workspace package that imports motor (from the Scope grep):
apply the rename or confirm the deprecated typedef keeps them compiling
without warnings-as-errors failures. `melos test` from the repo root.

**Verify**: `melos test` → all pass (or record pre-existing failures unrelated
to the rename before starting, and show the same set after).

## Test plan

- The permanent co-import regression test (Step 4).
- Zero expectation changes anywhere — this is a pure rename; any behavioral
  test change is a red flag.

## Done criteria

- [ ] `melos analyze` and `melos test` exit 0 from the repo root
- [ ] `grep -rn "sealed class Step\b" packages/motor/lib` → no matches;
      `grep -n "class TrackStep" packages/motor/lib/src/step.dart` → one match
- [ ] Deprecated `typedef Step` exists in `step.dart` with the 3.0 removal note
- [ ] Subclass names unchanged: `grep -n "class StepTo\|class SyncStep" packages/motor/lib/src/step.dart` → both present
- [ ] Co-import regression test exists and passes
- [ ] CHANGELOG BREAKING entry with typedef note
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Step 1's SDK verification finds `TrackStep` or any kept subclass name in the
  Flutter SDK — report; do not pick a different name yourself.
- The deprecated typedef cannot alias the sealed class for exhaustive
  switching (Dart treats a typedef to a sealed type as usable in switches —
  verify; if `switch` exhaustiveness breaks through the typedef, document that
  consumers must switch on the new name and note it in CHANGELOG).
- Another workspace package uses `Step` in its own public API surface —
  renaming there is scope creep; report it.

## Maintenance notes

- 3.0: delete the deprecated typedefs (add to the 3.0 checklist in
  `MIGRATION.md` if Plan 007 landed).
- The still-open plans 005 and 009 reference `Step`/`StepTo` etc. by name in
  their excerpts; if this plan executes before either of them, update those
  plan files' excerpts or expect drift-check stops. (All other plans citing
  the old name have already landed.)
