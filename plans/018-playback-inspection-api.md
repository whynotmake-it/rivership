# Plan 018: Add a playback-inspection API to the motor engine

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 4d16091..HEAD -- packages/motor/lib packages/motor/test`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (blocks the timeline-inspector tool)
- **Effort**: M
- **Risk**: MED (engine file, but strictly additive — no behavior change allowed)
- **Depends on**: none
- **Category**: dx / direction (debug tooling API)
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

The example app's `TimelineLanes` widget visualizes timelines by dead
reckoning: pages hand it a `TrackTimeline` value plus a hand-rolled ticker,
and it re-derives step timing from design durations. It cannot be accurate in
principle, because only the engine knows (a) what plan each track is
*currently* following after an interrupt rewrites it, (b) when a spring step
*actually* settled, (c) when a sync barrier *actually* released, and (d) the
actual loop period. The maintainer wants the visualization to become a robust
debug tool that attaches to ANY `TrackController` and updates itself — which
requires the engine to expose an inspection surface. This plan adds that
surface as a pull-model snapshot API: immutable, built on demand, zero cost
when nobody inspects, and consistent with the tick it is read on.

## Current state

All paths relative to `packages/motor` unless noted. Verified at `4d16091`.

- `lib/src/controllers/track_controller.dart` — the controller. Every piece
  of per-track playback state is private: `_slots` (line 47),
  `_activeTracks` (49), `_tokenParticipants` (50), `_lastElapsed` (65),
  `_status` (67). Public reads today: `value(track)`, `velocity(track)`,
  `isAnimating`, `status`, `lastElapsedDuration` (109–110, null when
  stopped), and `@visibleForTesting int debugTrackCount` (53–55).
- `play(timeline)` does NOT retain the timeline — it immediately decomposes:

```177:186:packages/motor/lib/src/controllers/track_controller.dart
  TickerFuture play(
    TrackTimeline timeline, {
    void Function(Track track, int stepIndex)? onStep,
  }) {
    return _startAnimations(
      animations: timeline.animations,
      loop: timeline.loop,
      onStep: onStep,
    );
  }
```

- `lib/src/controllers/_track_slot.dart` — `part of 'track_controller.dart'`
  (the repo's established pattern for private controller internals). Holds
  `_stepPlayback` (line 21), `_playback` state, and `_startOffset` (23) —
  the ticker-elapsed time at which this track's animation began:

```19:23:packages/motor/lib/src/controllers/_track_slot.dart
  List<double> _currentValues;
  List<double> _velocityValues;
  StepPlayback<T>? _stepPlayback;
  _TrackSlotPlayback _playback = _TrackSlotPlayback.idle;
  Duration _startOffset = Duration.zero;
```

- `lib/src/simulations/step_playback.dart` — public class, NOT exported from
  `motor.dart` (tests deep-import it). Key private state:

```105:130:packages/motor/lib/src/simulations/step_playback.dart
  final List<TrackStep<T>> _steps;
  final MotionConverter<T> _converter;
  final LoopMode _loop;
  ...
  /// The duration each step occupied during forward playback.
  late final List<double?> _forwardSegmentSeconds;
  ...
  var _stepIndex = 0;
  var _direction = 1;
  var _cycleStartSeconds = 0.0;
  var _segmentStartSeconds = 0.0;
  var _lastElapsedSeconds = 0.0;
  var _isDone = false;
  var _isWaitingForSync = false;
```

  Public getters already exist for `values`, `velocities`,
  `currentStepIndex` (returns −1 when done), `isDone`, `isWaitingForSync`,
  `syncToken`. NOT exposed: the steps list, segment start times, forward
  segment durations, direction, loop cycle (no cycle *counter* exists at all
  — only `_cycleStartSeconds`, reassigned at wraps in `_advanceStep`).
- Actual settle durations are recorded post-hoc into
  `_forwardSegmentSeconds` via `_recordForwardSegmentDuration`
  (`step_playback.dart:310–314`), refined by a 24-iteration binary search
  (`_completionTime`, 509–523). Actual barrier release time exists only
  transiently at `releaseSync()` (`_segmentStartSeconds =
  _lastElapsedSeconds`, 169–174) and is stored nowhere.
- For `LoopMode.loop`, a **synthetic return step** is appended to `_steps`
  (`step_playback.dart:46–60`, `_hasReturnStep` at 112) — an inspection API
  must expose this honestly (the caller's plan has N steps; playback may have
  N+1).
- Repo conventions for exposure levels (follow these):
  - `@internal` (from `package:meta`) for cross-file engine plumbing:
    `TrackController.forgetTrack` (`track_controller.dart:370`),
    `TrackPhaseTimeline.animationsFrom` (`track_phase_timeline.dart:75`).
  - `@visibleForTesting` for test-only: `debugTrackCount`.
  - `lib/motor.dart` is the only public library — flat `export` list, some
    with `show` combinators.
- Analyzer gate: `dart analyze --fatal-infos` must stay clean (infos fatal).
  Doc comments are lint-required on public members (`public_member_api_docs`
  via lintervention).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Tests   | `cd packages/motor && flutter test` | all pass |
| Example gate | `cd packages/motor/example && dart analyze --fatal-infos && flutter test` | exit 0, all pass |

## Scope

**In scope**:
- `packages/motor/lib/inspection.dart` (create — new entrypoint library)
- `packages/motor/lib/src/inspection/playback_snapshot.dart` (create — the
  snapshot value types)
- `packages/motor/lib/src/controllers/track_controller.dart` and
  `_track_slot.dart` (snapshot assembly + revision counter; additive only)
- `packages/motor/lib/src/simulations/step_playback.dart` (recording
  additions + package-private getters; additive only)
- `packages/motor/test/src/inspection/playback_snapshot_test.dart` (create)
- `packages/motor/CHANGELOG.md` (one entry under Unreleased)

**Out of scope** (do NOT touch):
- `motor.dart`'s existing export list (the new API ships ONLY via
  `package:motor/inspection.dart` — maintainer decision, keeps the core API
  clean).
- Any behavior change to playback, status semantics, or scrubbing —
  `resume()`/`scrubTo` fixes are plan 019, not this plan.
- The example app (plan example/007 consumes this API later).
- `pubspec.yaml` version (release management is separate).

## The API (build exactly this shape)

New library `package:motor/inspection.dart`:

```dart
/// Debug and tooling introspection for motor playback.
///
/// This surface exists for inspectors, debug overlays, and tests. It is
/// read-only: nothing here can mutate playback.
library motor.inspection;

export 'src/inspection/playback_snapshot.dart';
```

`lib/src/inspection/playback_snapshot.dart` — immutable value types:

```dart
/// A point-in-time view of everything a [TrackController] is playing.
@immutable
class PlaybackSnapshot {
  final int revision;               // monotonic; bumps on every plan change
  final Duration? tickerElapsed;    // controller's clock (null when stopped)
  final AnimationStatus status;
  final List<TrackPlayback> tracks; // one per slot that has ever played
}

/// One track's live playback state.
@immutable
class TrackPlayback {
  final Track<Object> track;
  final List<TrackStep<Object>> steps;  // the ACTUAL running plan, including
                                        // the synthetic loop-return step;
                                        // flagged by [hasSyntheticReturnStep]
  final bool hasSyntheticReturnStep;
  final LoopMode loop;
  final int currentStepIndex;           // -1 when done
  final int direction;                  // 1 forward, -1 pingPong reverse
  final int cycle;                      // completed loop wraps (new counter)
  final bool isWaitingForSync;
  final Object? syncToken;
  final Duration startOffset;           // slot start on the ticker axis
  final Duration playhead;              // slot-local elapsed (last advanceTo)
  /// Actual recorded step timings on the slot-local axis. Index i is step
  /// i's actual start; null when not yet reached this cycle. The end of a
  /// sync step's wait (== the next step's start) IS the barrier release
  /// moment.
  final List<Duration?> stepStarts;
  /// Actual duration each step occupied during forward playback
  /// (the engine's settle ledger); null when not yet completed.
  final List<Duration?> stepDurations;
}
```

Access: an extension in the same file —

```dart
extension TrackControllerInspection on TrackController {
  /// Builds an immutable snapshot of current playback. Cheap: copies only
  /// small lists; safe to call from a listener on every tick.
  PlaybackSnapshot inspectPlayback() => ...;
  /// Monotonic counter, incremented whenever the playing plan changes
  /// (play/animate/set/stop/scrub). Lets observers detect rewrites without
  /// diffing snapshots.
  int get playbackRevision => ...;
}
```

Implementation notes (the executor must follow these):
- The extension cannot reach privates; implement the assembly INSIDE
  `track_controller.dart` as `@internal` members
  (`TrackController.internalInspectPlayback()` / `internalPlaybackRevision`)
  that the extension delegates to — mirroring how `@internal` is used today.
  Alternatively make `playback_snapshot.dart` a `part` of nothing — do NOT
  do that; use the `@internal` delegation, it keeps file structure clean.
- `StepPlayback` gains additive recording: `_stepStartSeconds`
  (`List<double?>`, assigned in `_startCurrentStep` for forward direction),
  a `_cycle` counter (incremented in each of `_advanceStep`'s three wrap
  branches), and package-visible getters (`stepsView` as unmodifiable,
  `forwardSegmentSeconds` view, `stepStartSeconds` view, `direction`,
  `cycle`, `lastElapsedSeconds`). Mark these `@internal` with doc comments.
  Recording cost: one list assignment per step transition — nothing per
  tick.
- `_startAnimations`, `set`, `stop` (both paths), and `scrubTo` each bump
  `_playbackRevision++` (one new int field). Do not notify listeners from
  the bump — every one of those paths already notifies.
- Snapshot durations convert from the engine's seconds doubles via
  microseconds (`Duration(microseconds: (s * 1e6).round())`) — match the
  conversion already used in `_track_slot.dart:73–77` (read it first).
- ZERO behavior change: no existing test may need modification. If one
  fails, that is a STOP condition, not a test to fix.

## Steps

### Step 1: Recording additions in StepPlayback

Add `_stepStartSeconds`, `_cycle`, and the `@internal` getters. Sizing: both
per-step lists are sized like `_forwardSegmentSeconds` (read how it's
initialized before copying the pattern). Reset semantics: `seekTo`'s
`_reset()` re-clears them (find `_reset`, mirror what it does to
`_forwardSegmentSeconds`).

**Verify**: `cd packages/motor && dart analyze --fatal-infos` → exit 0;
`flutter test` → all pass (no existing test touched).

### Step 2: Snapshot assembly + revision in TrackController

`_playbackRevision` field with bumps at the four mutation sites; `@internal
PlaybackSnapshot internalInspectPlayback()` assembling `TrackPlayback` per
slot from `_slots` + each slot's `StepPlayback` getters. Slots with no
playback (`_stepPlayback == null`) are omitted. Include stopped-but-seeded
slots only if they have a playback object.

**Verify**: analyzer clean; `flutter test` all pass.

### Step 3: The value types and public entrypoint

`playback_snapshot.dart` (types + extension delegating to the `@internal`
members) and `lib/inspection.dart`. Full dartdoc on every public member —
this is a shipping debug API; document the synthetic-return-step caveat, the
slot-local vs ticker-axis time distinction (`startOffset` + `playhead`), and
that `stepStarts[i+1]` after a sync step is the barrier release moment.

**Verify**: analyzer clean.

### Step 4: Tests

`packages/motor/test/src/inspection/playback_snapshot_test.dart`, modeled
structurally on `test/src/controllers/track_controller_scrub_resume_test.dart`
(read it for the TickerProvider/pump idioms used in this repo). Cases:
1. Two-track `play` → snapshot has 2 tracks, correct steps (including
   `hasSyntheticReturnStep` true for `LoopMode.loop` and false otherwise),
   `currentStepIndex` 0, revision constant across pumps without plan change.
2. Pump past step 1 of a fixed-duration two-step plan → `stepStarts[1]`
   non-null and ≈ step 0's duration; `stepDurations[0]` non-null.
3. Sync barrier: fast+slow tracks with `.sync(token:)` → while fast waits,
   its `isWaitingForSync`/`syncToken` reflect it; after release, fast's
   post-barrier `stepStarts` equals the slow track's arrival time (±1 frame).
4. Spring step: `stepDurations[0]` after settle is GREATER than the motion's
   design `duration` (this is the whole point — assert the ledger records
   actual settle, e.g. a `CupertinoMotion(duration: 250ms)` records ≥300ms).
5. Loop: after pumping >1 full cycle of a short looping plan, `cycle` ≥ 1.
6. Revision: bumps exactly once per `animate` call and once per
   `stop(canceled: true)`; unchanged by pumping.
7. Interruption: `animate` a new target mid-flight → snapshot's `steps` for
   that track reflect the NEW plan; revision bumped.

**Verify**: `flutter test test/src/inspection/playback_snapshot_test.dart` →
all pass; then full `flutter test` → all pass.

### Step 5: CHANGELOG + full gates

CHANGELOG entry under Unreleased: `FEAT: playback inspection API
(package:motor/inspection.dart) — immutable snapshots of live playback for
debug tooling.` Run the example gate too (example must be unaffected).

**Verify**: all four command-table gates green.

## Test plan

Covered in step 4 (7 cases). No golden tests. Existing suites must pass
byte-identical — the CI gate for "no behavior change" is `flutter test` with
zero modified existing test files (`git diff --name-only -- packages/motor/test`
shows only the new file).

## Done criteria

- [ ] `package:motor/inspection.dart` exists; `grep -n "inspection" packages/motor/lib/motor.dart` → no matches (core library untouched).
- [ ] All 7 new tests pass; full motor + example suites pass.
- [ ] `git diff --name-only 4d16091..HEAD -- packages/motor/test` lists ONLY the new test file.
- [ ] `dart analyze --fatal-infos` exit 0 in `packages/motor` AND `packages/motor/example`.
- [ ] Every public member of the new library has dartdoc.
- [ ] CHANGELOG updated; status row updated in `plans/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Any existing test fails after your change — you altered behavior.
- Assembling the snapshot requires making `StepPlayback` exported or moving
  files — the `@internal` delegation should suffice; if it doesn't, report
  why.
- The per-step recording measurably complicates `_advanceStep`'s wrap logic
  (the three loop branches) — that code was hardened by plans 002/009/016;
  if your addition needs more than trivial insertions there, report.
- The code at the excerpted locations doesn't match (drift).

## Maintenance notes

- Plan 019 (scrub/pause/resume) and plan example/007 (inspector widget)
  build on this; the snapshot shape is their contract — API changes after
  they land require coordinating all three.
- The `inspection.dart` entrypoint is deliberately separate; when the
  inspector widget ships to users, this library is what gets documented.
- Reviewer: scrutinize the "no behavior change" claim by diffing
  `step_playback.dart` hunks — every insertion should be a recording or a
  getter, never a control-flow change.
