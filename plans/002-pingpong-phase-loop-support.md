# Plan 002: Implement pingPong phase-loop support and fix Step.at reverse scheduling

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/controllers/phase_track_controller.dart packages/motor/lib/src/simulations/step_playback.dart packages/motor/lib/src/loop_mode.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (changes playback timing; characterization tests from Plan 001 are the safety net)
- **Depends on**: plans/001-pingpong-sync-seek-characterization-tests.md
- **Category**: bug
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

`LoopMode.pingPong` is public, documented API (`loop_mode.dart`, README "Loop
Modes"), but it is broken in two places in the new 2.0 track stack:

1. **Phase level**: `PhaseTrackController` handles looping in
   `_onStatusChanged`, which special-cases only `seamless` and falls through to
   generic loop behavior for everything else. Because `LoopMode.isLooping`
   includes `pingPong`, a `TrackPhaseTimeline(phaseLoop: LoopMode.pingPong)`
   silently behaves exactly like `LoopMode.loop` — phases replay forward
   instead of reversing.
2. **Step level**: `StepPlayback._moveToScheduledStepIfDue` fires `Step.at`
   boundaries without a direction guard, so on a pingPong reverse leg,
   absolute-time steps are re-triggered on the un-mirrored forward schedule,
   collapsing or skipping reverse segments.

Users choosing pingPong get wrong motion with no error. The legacy
`SequenceMotionController` *does* implement phase-level pingPong
(`legacy_motion_controller.dart:1054-1064`), so the 2.0 stack is a regression
against the API it replaces.

## Current state

### Phase level

`packages/motor/lib/src/controllers/phase_track_controller.dart` — the loop
dispatch (only `seamless` is special-cased; `pingPong` falls into the generic
branch):

```173:213:packages/motor/lib/src/controllers/phase_track_controller.dart
  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;

    final timeline = _activeTimeline;

    if (_isPlayingPhases && timeline != null && timeline.phaseLoop.isLooping) {
      final previous = _currentPhase;
      final phases = timeline.phases;
      final first = phases.first;

      if (timeline.phaseLoop == LoopMode.seamless && phases.length >= 2) {
        // ... seamless: set() back to first-phase values, animate from second
      }

      // loop (and single-phase seamless): animate from the current values back
      // to the first phase and replay the whole timeline. ...
      _currentPhase = first;
      if (previous != null && previous != first) {
        _onTransition?.call(PhaseTransitioning(from: previous, to: first));
      }
      animate(timeline.animations);
      return;
    }
```

Supporting API on `packages/motor/lib/src/track_phase_timeline.dart`:
- `phases` (ordered list), `phaseAnimations` (map), `animationsFrom(startPhase)`
  (flatten from a phase onward, line 76–84), `firstPhaseValues` (line 92–108).
- There is **no** helper to produce a *reversed* phase flattening; you will add
  one (Step 2).

Legacy reference implementation of phase pingPong (for semantics, not code
reuse) — `packages/motor/lib/src/controllers/legacy/legacy_motion_controller.dart:1054-1064`:
on reaching the end, direction flips to -1 and the next target phase is
`totalPhases - 2`; on reaching the start while reversed, direction flips to 1
and the next phase is index 1. Transitions are reported for each hop.

### Step level

`packages/motor/lib/src/simulations/step_playback.dart`:

```441:457:packages/motor/lib/src/simulations/step_playback.dart
  bool _moveToScheduledStepIfDue(double elapsedSeconds) {
    final nextStepIndex = _stepIndex + _direction;
    if (nextStepIndex < 0 || nextStepIndex >= _steps.length) return false;

    final nextStep = _steps[nextStepIndex];
    if (nextStep case StepAt<T>(:final at)) {
      final absoluteAt = _absoluteTimeFor(at);
      if (elapsedSeconds < absoluteAt) return false;

      _sample(absoluteAt - _segmentStartSeconds);
      _segmentStartSeconds = absoluteAt;
      _advanceStep();
      return true;
    }

    return false;
  }
```

`_direction` is set to -1 in `_advanceStep` when pingPong reaches the end
(lines 273–277); `_cycleStartSeconds` is rebased at each direction change.
`_absoluteTimeFor(at)` is `_cycleStartSeconds + at.toSeconds()` (line 459) —
correct on forward legs, meaningless on reverse legs (the `at` offsets were
authored forward-from-cycle-start).

### Tests that pin current behavior (written by Plan 001)

- `packages/motor/test/src/step_playback_pingpong_test.dart` — contains
  `CHARACTERIZATION` markers referencing this plan; you will flip those
  expectations to the correct mirrored behavior.
- `packages/motor/test/src/loop_mode_semantics_test.dart` — loop/seamless
  semantics that must NOT change.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/step_playback_pingpong_test.dart test/src/loop_mode_semantics_test.dart` | all pass |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/simulations/step_playback.dart`
- `packages/motor/lib/src/controllers/phase_track_controller.dart`
- `packages/motor/lib/src/track_phase_timeline.dart` (add reversed-flatten helper)
- `packages/motor/test/src/step_playback_pingpong_test.dart` (update expectations)
- `packages/motor/test/src/loop_mode_semantics_test.dart` (add phase pingPong cases)
- `packages/motor/CHANGELOG.md` (add entries under "Unreleased")

**Out of scope** (do NOT touch):
- `packages/motor/lib/src/controllers/legacy/` — legacy stack has its own
  pingPong; Plan 007 owns it.
- `packages/motor/lib/src/motion_sequence.dart`.
- Golden test PNGs — if a golden fails, STOP (see below).
- Widget layer (`phase_track_builder.dart`) — it inherits the fix via the controller.

## Git workflow

Colocated jj repo: use `jj new` / `jj desc -m "..."` for VCS mutations when
executing in the main workspace; plain git in an isolated worktree. Message
style: `fix(motor): support pingPong phase loops in PhaseTrackController`.

## Steps

### Step 1: Fix Step.at scheduling on reverse legs

In `step_playback.dart`, gate `_moveToScheduledStepIfDue` to forward legs:
at the top of the method add `if (_direction < 0) return false;`.

Rationale: on a reverse leg, `_startReverseStep` already animates toward the
previous waypoint using the step's own motion; jumping on the forward absolute
schedule is never correct. Reverse legs therefore run each `StepAt` segment as
a normal reverse animation (duration = the motion the step carries after
`scaleTo`, already captured in `_startReverseStep` via `_motionsOrNull`).
Note `_startReverseStep` resolves `StepAt` motions **without** the `scaleTo`
gap-scaling that forward playback applies (`_startCurrentStep` lines 370–394).
Mirror that: when reversing *from* a `StepAt` step whose forward leg was
gap-scaled, scale the reverse motion to the same gap so the reverse leg takes
the same time as the forward leg. Compute the gap as
`_absoluteTimeFor(at) - previousBoundaryAbsoluteTime` — if this requires more
bookkeeping than a small field recording each step's forward segment duration,
record forward segment durations in a `List<double>` populated during forward
playback and reuse them in `_startReverseStep`.

Then update the `CHARACTERIZATION`-marked expectations in
`step_playback_pingpong_test.dart` to the now-correct behavior: the reverse leg
of `[to(1, linear100), at(300ms, 2, linear)]` animates 2→1 over the same
duration the forward `at` segment took (200 ms), then 1→0 over 100 ms.

**Verify**: `flutter test test/src/step_playback_pingpong_test.dart` → all pass.

### Step 2: Add reversed phase flattening to TrackPhaseTimeline

In `track_phase_timeline.dart`, add an `@internal` method:

```dart
/// The flattened animations for playing phases in reverse order, starting
/// from the second-to-last phase (the last phase's values are the current
/// resting state when a pingPong reversal begins).
List<TrackAnimation> reversedAnimations()
```

Implementation: build a phase list `phases.reversed.skip(1)` (i.e. from the
second-to-last phase down to the first), then flatten exactly as `_flatten`
does — reuse `_flatten` by constructing the reversed map:

```dart
final reversedMap = <P, List<TrackAnimation>>{
  for (final phase in phases.reversed.skip(1)) phase: phaseAnimations[phase]!,
};
return _flatten(reversedMap);
```

`_flatten` inserts `SyncStep(token: nextPhase)` between phases, so phase
transitions during the reverse pass are still reported through
`onSyncReleased` with the correct target phase.

Note this reverses **phase order** while playing each phase's own steps
forward. That matches the legacy semantics (each phase is a target state;
reversing means visiting the states in reverse order), and avoids requiring
step-level reversal of arbitrary multi-step phases. Document this in the
method's dartdoc.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 3: Handle pingPong in PhaseTrackController

In `phase_track_controller.dart`:

1. Add a private field `bool _phaseDirectionForward = true;` reset to `true`
   in `playPhases` and `setTimeline`.
2. In `_onStatusChanged`, before the existing generic-loop branch, add a
   `pingPong` branch:
   - If `timeline.phaseLoop == LoopMode.pingPong && phases.length >= 2`:
     - When `_phaseDirectionForward` is true (just finished the forward pass):
       set `_phaseDirectionForward = false`, report
       `PhaseTransitioning(from: last, to: secondToLast)` via `_onTransition`,
       set `_currentPhase` to the second-to-last phase, and
       `animate(timeline.reversedAnimations())`.
     - When false (just finished the reverse pass): set it back to true,
       report `PhaseTransitioning(from: first, to: second)`, set
       `_currentPhase` to the second phase, and
       `animate(timeline.animationsFrom(phases[1]))`.
       (`animationsFrom` skips already-settled phases — line 76–84.)
   - Single-phase timelines: fall through to the existing generic branch
     (same as seamless does today).
3. `onSyncReleased` (lines 160–171) sets `_currentPhase` when a phase-token
   barrier releases. It works unchanged for the reverse pass because
   `reversedAnimations` uses the phase tokens as sync tokens. Confirm with a
   test that transition callbacks during the reverse pass report the
   descending phases.

Add controller-level tests to `loop_mode_semantics_test.dart` (new group,
model after the existing "phase loop" group at lines 126–188):
- 3-phase timeline, `phaseLoop: pingPong`, `playPhases` — capture
  `onTransition` events for ~2 full cycles; assert the phase order is
  `a→b→c→b→a→b→c…` and values hit each phase's targets (numeric asserts).
- 2-phase timeline pingPong — order `a→b→a→b…` with no duplicate transitions.
- Assert loop and seamless groups still pass unchanged.

**Verify**: `flutter test test/src/loop_mode_semantics_test.dart` → all pass.

### Step 4: CHANGELOG + doc comment

- `phase_track_controller.dart` class dartdoc: document phase pingPong
  semantics (phases visited in reverse order; each phase's steps play forward).
- `CHANGELOG.md` under "Unreleased" → "### Fixes": two entries — pingPong phase
  loops previously behaved like `loop`; `Step.at` scheduling on pingPong
  reverse legs fixed.

**Verify**: `flutter test` (whole package) → all pass; `dart analyze --fatal-infos` → exit 0.

## Test plan

- Updated: `step_playback_pingpong_test.dart` (expectations flipped per Step 1).
- New: controller-level pingPong phase-loop tests in
  `loop_mode_semantics_test.dart` (Step 3, ≥3 cases including transition-order
  capture).
- Regression gate: the existing loop/seamless tests in
  `loop_mode_semantics_test.dart` and all of `sync_step_test.dart` must pass
  **without modification**.

## Done criteria

- [ ] `flutter test` (packages/motor) exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] No `CHARACTERIZATION` comment referencing plans/002 remains in the test tree:
      `grep -rn "plans/002" packages/motor/test/` returns no matches
- [ ] Loop/seamless test expectations unchanged (`git diff` on
      `loop_mode_semantics_test.dart` shows only additions)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- Plan 001's characterization tests do not exist (dependency not landed).
- Any golden test (`test/src/widgets/golden/`) fails — goldens must not change;
  a failure means the fix altered non-pingPong behavior.
- The reverse-leg duration bookkeeping in Step 1 requires touching
  `_track_slot.dart` or `track_controller.dart` — that suggests a deeper
  redesign; report options instead.
- Loop or seamless expectations need editing to pass.

## Maintenance notes

- `reversedAnimations()` visits phases in reverse but plays each phase's steps
  forward. If someone later wants true step-level mirroring inside phases,
  that is a new feature, not a bug fix — keep the distinction.
- Reviewers should scrutinize the transition-event order in the new tests
  (especially at the turnaround phases: no duplicate or missing
  `PhaseTransitioning`).
- Deferred: pingPong for `TrackTimeline.loop` at the *timeline* level already
  works via `StepPlayback`; only phase-level pingPong was missing.
