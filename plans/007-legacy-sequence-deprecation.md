# Plan 007: Deprecate the legacy sequence stack for 2.0, pin its behavior, and chart 3.0 removal

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/controllers/legacy/ packages/motor/lib/src/motion_sequence.dart packages/motor/lib/src/widgets/sequence_motion_builder.dart packages/motor/lib/motor.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (must land before the 2.0 release to start the deprecation clock)
- **Effort**: M
- **Risk**: LOW–MED (annotations are safe; the parity tests may surface real divergences)
- **Depends on**: none (parallel-safe with 001–006)
- **Category**: tech-debt / migration
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

Motor 2.0 ships two paradigms for the same job: the legacy sequence stack
(`MotionSequence`, `SequenceMotionController`, `SequenceMotionBuilder`) and the
new track stack (`TrackPhaseTimeline`, `PhaseTrackController`,
`PhaseTrackBuilder`). The CHANGELOG already declares the legacy stack a
"compatibility shim", but nothing in code or docs says so: no `@Deprecated`
annotations exist anywhere in `lib/`, and the README documents sequences as a
first-class feature (135 lines). Worse, keeping `SequenceMotionController`
alive requires a full 1,201-line copy of the *old* `MotionController` in
`lib/src/controllers/legacy/legacy_motion_controller.dart`, duplicating the
new 523-line `MotionController`.

Decided direction (do not re-litigate): **2.0 keeps the legacy APIs working
with minimal breaking changes, marks them `@Deprecated` for removal in 3.0,
and pins their behavior with numeric tests so the shim can't silently rot.**
Rewriting `SequenceMotionController` on the new engine was considered and
rejected for 2.0: it overrides private members of the legacy controller
(`_tick`, `_motionPerDimension`, `_target`), so a rewrite is a
behavior-risking L-effort task with no user benefit before 3.0 deletes it.

## Current state

- `packages/motor/lib/motor.dart` — exports:

```5:6:packages/motor/lib/motor.dart
export 'src/controllers/legacy/legacy_motion_controller.dart'
    show SequenceMotionController;
```

  plus `export 'src/motion_sequence.dart';` (line 15) and
  `export 'src/widgets/sequence_motion_builder.dart';` (line 27).

- `packages/motor/lib/src/controllers/legacy/legacy_motion_controller.dart` —
  private legacy `MotionController` + `BoundedMotionController` (not exported;
  only `SequenceMotionController`, lines 792–1183, is public). The legacy
  controller classes shadow the new ones by name inside this file only.
- `packages/motor/lib/src/motion_sequence.dart` (663 lines) — `MotionSequence`
  and subclasses (`StateSequence`, `StepSequence`, `SpanningSequence`). Note:
  it re-exports `loop_mode.dart` (line 9) — `LoopMode` is NOT legacy and must
  not be deprecated.
- `packages/motor/lib/src/widgets/sequence_motion_builder.dart` (333 lines) —
  `SequenceMotionBuilder` widget.
- `packages/motor/lib/src/widgets/base_motion_builder.dart` — check whether it
  references sequence types before annotating (it should not).
- README sequence docs: `packages/motor/README.md:340-475` ("Sequence
  Animations"), plus the Tracks-vs-Sequences callout at line 344.
- CHANGELOG statement of intent: `packages/motor/CHANGELOG.md:31`.
- Existing legacy tests: `test/src/controllers/phase_sequence_controller_test.dart`
  (extensive API coverage, but **no numeric LoopMode playback characterization**),
  `test/src/widgets/sequence_motion_builder_test.dart` (equality/hash + widget
  behavior), `sequence_motion_builder_golden_test.dart` (loop semantics pinned
  by PNGs only — goldens can't explain logic drift).
- The numeric-test pattern to copy: `test/src/loop_mode_semantics_test.dart`
  (its header comment even says it matches "the legacy sequence controllers").
- Deprecation lint: the repo uses `lintervention`; deprecated-member-use
  warnings inside the package itself must be silenced with
  `// ignore: deprecated_member_use_from_same_package` where legacy types
  reference each other, or by annotating at the right granularity (see Step 2).

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |
| Find annotations | `grep -rn "@Deprecated" lib/` | matches per Step 2 list |

## Scope

**In scope**:
- `packages/motor/lib/src/motion_sequence.dart` (annotations only)
- `packages/motor/lib/src/controllers/legacy/legacy_motion_controller.dart`
  (annotation on `SequenceMotionController` only)
- `packages/motor/lib/src/widgets/sequence_motion_builder.dart` (annotation)
- `packages/motor/README.md` (restructure sequence section)
- `packages/motor/MIGRATION.md` (create)
- `packages/motor/CHANGELOG.md`
- `packages/motor/test/src/controllers/legacy_sequence_semantics_test.dart` (create)

**Out of scope** (do NOT touch):
- Deleting or refactoring any legacy implementation code — 3.0's job.
- `LoopMode` and `PhaseTransition` — shared with the new stack, not deprecated.
- `MotionBuilder`/`MotionController` (new, non-legacy) — not deprecated.
- The example app (`packages/motor/example/`) — if it uses deprecated APIs,
  note it in the report; do not migrate it here.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Split into two commits:
`test(motor): pin legacy sequence loop semantics numerically` and
`feat(motor)!: deprecate MotionSequence stack for removal in 3.0`.

## Steps

### Step 1: Pin legacy loop semantics numerically (before annotating)

Create `packages/motor/test/src/controllers/legacy_sequence_semantics_test.dart`
modeled on `loop_mode_semantics_test.dart`, driving a
`SequenceMotionController<int, double>` with `MotionSequence.steps` and
`Motion.linear` motions (exact values):

1. `LoopMode.none` — plays phases in order, settles, emits `PhaseSettled`.
2. `LoopMode.loop` — after the last phase, animates back to phase 0 and
   replays; assert values mid-return-leg.
3. `LoopMode.seamless` — jumps to phase 0 and continues; assert no visible
   reverse animation (value continuity when first == last).
4. `LoopMode.pingPong` — phases visited `0→1→2→1→0→1…`; assert via captured
   `onTransition` events and values at timestamps.
5. Parity spot-check vs the new stack: express the same 3 phases as a
   `TrackPhaseTimeline` on a `PhaseTrackController` and assert the visited
   phase order matches for `loop` and (if Plan 002 has landed) `pingPong`.
   If the orders diverge, document the delta in `MIGRATION.md` instead of
   failing — record it with a comment and an expectation matching the actual
   behavior of each stack.

**Verify**: `flutter test test/src/controllers/legacy_sequence_semantics_test.dart` → all pass.

### Step 2: Annotate the legacy surface

Add `@Deprecated(...)` with an actionable, versioned message to these public
symbols (class-level annotation covers members):

| Symbol | File | Message (exact) |
|--------|------|-----------------|
| `MotionSequence` (and factory-exposed subclasses `StateSequence`, `StepSequence`, `SpanningSequence`, and the `ValueWithMotion` typedef) | `motion_sequence.dart` | `'Use Track/TrackPhaseTimeline with PhaseTrackBuilder or PhaseTrackController instead. See MIGRATION.md. MotionSequence will be removed in motor 3.0.'` |
| `SequenceMotionController` | `legacy/legacy_motion_controller.dart` | `'Use PhaseTrackController with a TrackPhaseTimeline instead. See MIGRATION.md. SequenceMotionController will be removed in motor 3.0.'` |
| `SequenceMotionBuilder` | `sequence_motion_builder.dart` | `'Use PhaseTrackBuilder with a TrackPhaseTimeline instead. See MIGRATION.md. SequenceMotionBuilder will be removed in motor 3.0.'` |

Do NOT annotate: `LoopMode` (shared), `PhaseTransition`/`PhaseSettled`/
`PhaseTransitioning` (used by the new stack), the private legacy
`MotionController`/`BoundedMotionController` (not exported; annotating them
only creates same-package noise).

Where legacy code references other deprecated legacy symbols and the analyzer
flags `deprecated_member_use_from_same_package`, add targeted
`// ignore:` comments (file-level `// ignore_for_file:` acceptable in
`legacy_motion_controller.dart` and `motion_sequence.dart`). The package's own
tests for legacy behavior (Step 1's file, existing sequence tests) will also
need `// ignore_for_file: deprecated_member_use_from_same_package` headers.

**Verify**: `dart analyze --fatal-infos` → exit 0 (all deprecation warnings
resolved via ignores or non-legacy call sites); `flutter test` → all pass.

### Step 3: Write MIGRATION.md

Create `packages/motor/MIGRATION.md` covering 1.x → 2.0. Contents:

1. **Breaking behavior changes** (from CHANGELOG "Unreleased", one subsection
   each with before/after code): spring `snapToEnd` default true; automatic
   velocity tracking on by default (`VelocityTracking.off()` to opt out);
   directional `status` for comparable converters (`reverse` now reported);
   `PhaseTransition` factory constructors removed (construct
   `PhaseSettled`/`PhaseTransitioning` directly); sealed `MotionBase` root
   (custom motions extend `Motion` or `FreeMotion`).
2. **Sequences → Tracks migration table**, mapping each legacy construct to
   its replacement with a code pair:
   - `MotionSequence.states({...}, motion: m)` + `SequenceMotionBuilder` →
     `TrackPhaseTimeline({...})` with one `Track` + `PhaseTrackBuilder`.
   - `MotionSequence.steps([...])` → a single track animation with multiple
     `Step.to`s (or `TrackTimeline` + `loop:`).
   - `MotionSequence.spanning({...})` → `Step.at` absolute-time steps.
   - `SequenceMotionController.playSequence` → `PhaseTrackController.playPhases`.
   - `currentSequencePhase`/`isPlayingSequence`/`sequenceProgress` →
     `currentPhase` (+ note: no direct `sequenceProgress` equivalent; suggest
     deriving from `onTransition` events).
3. **Deprecation timeline**: deprecated in 2.0, removed in 3.0.
4. Any behavioral deltas discovered in Step 1's parity test.

Use README code style (dot-shorthands where the README uses them).

**Verify**: file exists; `dart analyze --fatal-infos` still exit 0.

### Step 4: Restructure README + CHANGELOG

1. README: retitle "Sequence Animations 🎬" to "Sequence Animations (deprecated)",
   add a deprecation callout box at the top of the section linking to
   `MIGRATION.md`, and shorten the section to the essentials (keep it usable
   for existing users; cut the "Advanced: Phase Motion Controllers" subsection
   down to a pointer at `PhaseTrackController`). Add a short "Choosing an API"
   table near the top of Usage: single value → `MotionBuilder`/controllers;
   multiple properties/choreography → Tracks & Steps; legacy sequences →
   deprecated, see MIGRATION.md.
2. CHANGELOG "Unreleased": add a **DEPRECATION** entry naming the three
   symbols and the 3.0 removal, linking MIGRATION.md.

**Verify**: `flutter test` → all pass; `grep -rn "@Deprecated" packages/motor/lib/`
lists exactly the symbols from Step 2's table.

## Test plan

- Step 1's numeric semantics file (≥5 cases) — the durable behavior pin that
  outlives golden PNGs.
- Existing sequence tests continue passing with only `// ignore_for_file:`
  header additions (no expectation changes).

## Done criteria

- [ ] `flutter test` exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `grep -c "@Deprecated" packages/motor/lib/src/motion_sequence.dart` ≥ 4
- [ ] `SequenceMotionController` and `SequenceMotionBuilder` carry `@Deprecated`
- [ ] `packages/motor/MIGRATION.md` exists and covers the 5 breaking changes +
      sequence migration table
- [ ] README sequence section marked deprecated with MIGRATION.md link
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Step 1 reveals the legacy stack's `LoopMode` behavior differs from the
  documented semantics in `loop_mode_semantics_test.dart`'s header — pin what
  it actually does and report the divergence; do not "fix" legacy behavior.
- Annotating a symbol breaks compilation of non-legacy `lib/` code (would mean
  the new stack depends on a legacy type — report which).
- The example app fails analysis due to deprecations and CI treats infos as
  fatal for the example too — report rather than migrating the example here.

## Maintenance notes

- 3.0 checklist (record in MIGRATION.md's timeline section): delete
  `lib/src/controllers/legacy/`, `motion_sequence.dart` (move the `LoopMode`
  re-export), `sequence_motion_builder.dart`, their tests and goldens, and the
  README section.
- The 1,201-line legacy `MotionController` copy is retained *only* as
  `SequenceMotionController`'s base; nobody should extend or export it. A
  reviewer should reject any new dependency on `controllers/legacy/`.
- If pub.dev scoring penalizes same-package deprecated usage, prefer the
  file-level ignores added in Step 2 over restructuring.
