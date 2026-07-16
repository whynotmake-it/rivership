# Plan 009: Minor bug batch — loop-without-motion, SpanningSequence seamless, velocityTracking updates, iteration-cap assert

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index. The four fixes are independent — if one hits a STOP
> condition, complete the others and report the blocked one.
>
> **Drift check (run first)**: `git diff --stat 1a2538f..HEAD -- packages/motor/lib/src/simulations/step_playback.dart packages/motor/lib/src/motion_sequence.dart packages/motor/lib/src/widgets/phase_track_builder.dart packages/motor/lib/src/widgets/track_builder.dart packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/loop_mode.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S (each fix independently small)
- **Risk**: LOW
- **Depends on**: none. Plans 002 (pingPong), 003 (widget lifecycle), 007
  (deprecations), 015 (sequence-controller rebase), and 016 (status
  semantics) have all landed and are reflected in the excerpts below. Plan
  005 (sync-barrier stop policy) is still open; if it lands first, re-run the
  sync suite after this plan.
- **Category**: bug
- **Planned at**: commit `1a2538f`, 2026-07-16 (originally `d36d4cb`,
  2026-07-14)
- **Refreshed**: 2026-07-16 against `1a2538f` — re-excerpted
  `PhaseTrackBuilder.didUpdateWidget` (plan 003 added the `active`
  conditions) and pinned Fix C's insertion point; updated
  `step_playback.dart` line references post-plan-002 and confirmed Fix A's
  premise and design still hold; replaced Fix A's test scenario (the original
  hold-only + `set` scenario cannot observe the fix — holds pin values to
  the start snapshot; a drifting `Step.free` timeline can); updated Fix B's
  line refs post-plan-007 (content unchanged) and made the deprecation-ignore
  header unconditional; resolved Fix C's `VelocityTracking` equality question
  against the live class (sealed, closure-holding — identity `==` is
  correct); added the 015/016 behavior-gate tests to verification; removed
  stale "if plan 002 lands after this" cross-references.

## Why this matters

Four small, verified defects with low blast radius, batched to amortize
setup. None blocks 2.0, but all are cheap and reduce surprise:

1. `LoopMode.loop` silently fails to return to the start when no return
   motion is resolvable — contradicting the documented loop semantics.
2. `SpanningSequence` with exactly two keyframes and `LoopMode.seamless`
   computes a degenerate zero-extent motion slice on loop wrap.
3. `TrackBuilder`/`PhaseTrackBuilder` ignore runtime changes to
   `velocityTracking` — the value is only read in `initState`.
4. `StepPlayback`'s 1000-iteration safety cap silently truncates processing of
   very long timelines; debug builds should surface it.

## Current state

### Fix A — loop without return motion (`step_playback.dart`)

```46:59:packages/motor/lib/src/simulations/step_playback.dart
    if (loop == LoopMode.loop) {
      // `loop` animates back to the start after the last step. Model that as a
      // synthetic final step that returns to the start snapshot, reusing the
      // first real step's motion(s). The wrap (in `_advanceStep`) then
      // continues from there without a jump. `seamless` skips this and jumps.
      final returnMotions = _firstStepMotions(_steps, _initialValues.length) ??
          _fallbackMotionPerDimension ??
          (fallbackMotion != null
              ? List<Motion>.filled(_initialValues.length, fallbackMotion)
              : null);
      if (returnMotions != null) {
        _steps.add(StepTo<T>(start, motionPerDimension: returnMotions));
      }
    }
```

When `returnMotions == null` (e.g. steps are only `hold`/`free`/`sync` and the
track has no default motion), no synthetic return step is appended, yet the
wrap in `_advanceStep` (case `LoopMode.loop`, lines 273–278) assumes it exists
("The synthetic return step appended at construction has already animated
back to the start snapshot") and restarts at step 0 from the *current*
values. A `Step.free` timeline that drifted away from the start therefore
never returns to it — the documented `loop` contract ("loop from the end back
to the start", `loop_mode.dart:6-7`) is silently broken.

Premise re-verified at `1a2538f`: plan 002 added `_forwardSegmentSeconds`
(initialized at line 60, *after* the synthetic-step append, so a constructor
flag fits cleanly), reverse `StepAt` scaling, and a `_direction < 0` guard in
`_moveToScheduledStepIfDue` (line 466) — none of it touches the forward
`loop` wrap, so the fix's design is unchanged.

Decision: **snap to `_initialValues` on wrap when no return step was added**
(matching how `seamless` wraps, lines 284–290). No debug assert — see Step 1
for why.

### Fix B — SpanningSequence 2-keyframe seamless (`motion_sequence.dart`)

The file now starts with
`// ignore_for_file: deprecated_member_use_from_same_package` (line 1) and
every class in it carries `@Deprecated` annotations (plan 007) — that shifted
all line numbers; the method body itself is unchanged:

```581:599:packages/motor/lib/src/motion_sequence.dart
  // Gets the next best previous index from [index]
  int _getBestPreviousIndex(int index) {
    int getNaive() {
      if (index == 0) {
        switch (loop) {
          case LoopMode.none || LoopMode.pingPong:
            return 1;
          case LoopMode.loop:
            return _phasesList.length - 1;
          case LoopMode.seamless:
            return _phasesList.length - 2;
        }
      } else {
        return index - 1;
      }
    }

    return getNaive().clamp(0, phases.length - 1);
  }
```

With 2 phases and `seamless`, index 0 → previous `length - 2 == 0` →
`fromIndex == currentIndex` in `motionForPhase` (lines 539–571) →
`motion.sliced(from: x, to: x)` → zero-extent `TrimmedMotion`
(`trimmedExtent == 0`, degenerate simulation). Fix: in the `seamless` case,
return `_phasesList.length - 2` only when `length > 2`; otherwise return
`_phasesList.length - 1` (i.e. 1), matching the two-point `loop` behavior.
This is deprecated-but-supported code (removal in 3.0, per plan 007); still
worth the two-line fix. The new test file for it must carry the same
`// ignore_for_file: deprecated_member_use_from_same_package` header —
model it on `test/src/controllers/legacy_sequence_semantics_test.dart:1`.

### Fix C — velocityTracking not updatable (widgets)

`packages/motor/lib/src/widgets/phase_track_builder.dart:126-129` — passed to
the controller constructor in `initState` only. `didUpdateWidget` never
compares it. The current chain (reshaped by plan 003 — it now handles
`active` deactivation and reactivation):

```136:171:packages/motor/lib/src/widgets/phase_track_builder.dart
  @override
  void didUpdateWidget(PhaseTrackBuilder<P> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.onAnimationStatusChanged != oldWidget.onAnimationStatusChanged) {
      if (oldWidget.onAnimationStatusChanged != null) {
        _controller.removeStatusListener(oldWidget.onAnimationStatusChanged!);
      }
      if (widget.onAnimationStatusChanged != null) {
        _controller.addStatusListener(widget.onAnimationStatusChanged!);
      }
    }

    if (widget.active != oldWidget.active && !widget.active) {
      _controller.stop(canceled: true);
      return;
    }

    final timelineChanged = widget.timeline != oldWidget.timeline;
    final phaseChanged = widget.currentPhase != oldWidget.currentPhase;
    final playingChanged = widget.playing != oldWidget.playing;
    final restartTriggerChanged =
        widget.restartTrigger != oldWidget.restartTrigger;

    if (restartTriggerChanged) {
      // A restartTrigger change replays from the start (jumping back to the
      // start snapshot first) rather than animating from the current values.
      _startPlayback(restart: true);
    } else if (timelineChanged ||
        playingChanged ||
        widget.active != oldWidget.active) {
      _startPlayback();
    } else if (phaseChanged && widget.currentPhase != null) {
      _controller.goToPhase(widget.currentPhase!);
    }
  }
```

`TrackBuilder` is unaffected: `track_builder.dart:93` constructs
`TrackController(vsync: this)` without a `velocityTracking` parameter at all
(only `PhaseTrackBuilder` exposes it). `TrackController.velocityTracking` is a
`final` field (`track_controller.dart:44`).

Decision: in `PhaseTrackBuilder.didUpdateWidget`, when
`widget.velocityTracking != oldWidget.velocityTracking`, dispose and recreate
the controller, then restart playback via the existing `_startPlayback()`
(values will re-seed from the timeline; this is acceptable for a
configuration change — document it in the property's dartdoc). Do NOT make
`TrackController.velocityTracking` mutable — recreation is simpler and this is
a rare operation.

Equality semantics — resolved against the live code, no investigation step
needed: `VelocityTracking` (`motion_velocity_tracker.dart:12-57`) is a sealed
class with two private subclasses reachable only through `const` factories
(`VelocityTracking.on`, `VelocityTracking.off`); `_VelocityTrackingOn`'s only
field is the nullable `velocityTrackerBuilder` **closure**. There are no `==`
overrides, and per this plan's original rule (closure fields ⇒ identity
comparison), do NOT add any: default identity `==` is correct because const
canonicalization makes `VelocityTracking.on() == VelocityTracking.on()` and
`VelocityTracking.off() == VelocityTracking.off()` hold. The one caveat: a
caller passing a *non-const* `velocityTrackerBuilder` closure recreated
inline on every build would trigger controller recreation each rebuild —
document in the dartdoc that such a builder should be stored in a field
(note this in the property doc added below).

### Fix D — silent 1000-iteration cap (`step_playback.dart`)

`advanceTo` (while loop at line 189) and `seekTo` (while loop at line 229):
`while (!_isDone && ... && iterations++ < 1000)`. Add after each loop:

```dart
assert(
  iterations < 1000,
  'StepPlayback processed 1000 step transitions in one advance/seek without '
  'settling. This usually means an extremely long timeline combined with a '
  'large time jump; playback state may be mid-timeline.',
);
```

(Keep the cap itself — it guards release builds against pathological loops.)

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/step_playback_test.dart test/src/loop_mode_semantics_test.dart test/src/widgets/phase_track_builder_test.dart` | all pass |
| Behavior gates (015/016) | `flutter test test/src/controllers/legacy_sequence_semantics_test.dart test/src/controllers/status_semantics_test.dart` | all pass, zero edits to these files |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/simulations/step_playback.dart` (Fixes A, D)
- `packages/motor/lib/src/motion_sequence.dart` (Fix B — `_getBestPreviousIndex` only)
- `packages/motor/lib/src/widgets/phase_track_builder.dart` (Fix C)
- `packages/motor/lib/src/loop_mode.dart` (Fix A — one doc sentence)
- Tests: `test/src/loop_mode_semantics_test.dart`,
  `test/src/motion_test.dart` or a new `spanning_sequence_test.dart`,
  `test/src/widgets/phase_track_builder_test.dart`
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- `CupertinoMotion.copyWith` — fixed by plan 004 (landed); leave it alone.
- `track_builder.dart` — it doesn't expose `velocityTracking`; adding the
  parameter there is a feature, not a fix (note it in Maintenance).
- The pingPong direction logic in `step_playback.dart`
  (`_startReverseStep`, `_forwardSegmentSeconds`, the `_direction` guard in
  `_moveToScheduledStepIfDue`) — landed via plan 002; Fix A touches only the
  forward `LoopMode.loop` wrap.
- `motion_velocity_tracker.dart` — no `==` overrides needed (see Fix C);
  removed from scope.
- `test/src/controllers/legacy_sequence_semantics_test.dart` and
  `test/src/controllers/status_semantics_test.dart` — behavior gates for
  plans 015/016; if either needs an edit, that is a STOP condition.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. One commit per fix, conventional style, e.g.
`fix(motor): snap to start when loop has no resolvable return motion`.

## Steps

### Step 1: Fix A — defined wrap behavior for motionless loop

In the constructor, add a private `bool _hasReturnStep` field set to true in
the branch where the synthetic step is appended (lines 56–58); it must be
assigned before `_forwardSegmentSeconds` is sized (line 60), which is already
where the constructor body sits. In the `LoopMode.loop` case of
`_advanceStep` (lines 273–278): if `!_hasReturnStep`, reset
`_currentValues`/`_currentVelocities` to `List.of(_initialValues)` /
`List.of(_initialVelocities)` (mirror the seamless case at lines 284–290).

Do NOT add a debug assert for the missing return motion: a
motion-carrying step that can't resolve (`StepTo`/`StepAt` without motion and
without track fallback) already trips the assert in `_motions`
(lines 330–338), so the only timelines reaching this path are legitimately
hold/free/sync-only. Instead add one doc sentence to `LoopMode.loop`
(`loop_mode.dart:6-7`): "If no step provides a target motion, the loop
restarts from the initial values without animating back."

Test (in `loop_mode_semantics_test.dart`, which already constructs
`StepPlayback` directly — model on the `playback(...)` helper at lines
23–28): a `StepPlayback<double>` with steps
`[StepFree(motion: FreeMotion.friction(...))]`, a non-zero initial
`velocity`, and `loop: LoopMode.loop`. Advance until the friction motion
settles at a drifted value, then advance past the wrap and assert
`values.single` is back at the start value (`closeTo(start, error)`) instead
of remaining at the drifted value. (Note: the previously drafted "hold-only
after `set`" scenario cannot observe this fix — holds pin values at the
start snapshot; only a `free` step drifts.)

**Verify**: `flutter test test/src/loop_mode_semantics_test.dart` → all pass.

### Step 2: Fix B — two-keyframe seamless slice

Change the `seamless` case in `_getBestPreviousIndex`
(`motion_sequence.dart:590-591`):

```dart
case LoopMode.seamless:
  return _phasesList.length > 2 ? _phasesList.length - 2 : 1;
```

Test (new file `test/src/spanning_sequence_test.dart` or extend an existing
sequence test; either way include the
`// ignore_for_file: deprecated_member_use_from_same_package` header —
pattern: `test/src/controllers/legacy_sequence_semantics_test.dart:1`):
`MotionSequence.spanning({0.0: a, 1.0: b}, motion: linear1s,
loop: LoopMode.seamless)` — assert
`motionForPhase(toPhase: 0.0, fromPhase: null)` returns a `TrimmedMotion` with
non-zero extent (`fromStart + fromEnd < 1.0`), and that a 3-keyframe seamless
still returns the `length - 2` slice.

**Verify**: `flutter test test/src/spanning_sequence_test.dart` (or the file
you extended) → all pass.

### Step 3: Fix C — react to velocityTracking changes

In `phase_track_builder.dart` `didUpdateWidget`, insert after the
status-listener rewiring block (lines 140–147) and before the `active`
deactivation check (line 149):

```dart
if (widget.velocityTracking != oldWidget.velocityTracking) {
  _controller.dispose();
  _controller = PhaseTrackController<P>(
    vsync: this,
    velocityTracking: widget.velocityTracking,
  );
  if (widget.onAnimationStatusChanged != null) {
    _controller.addStatusListener(widget.onAnimationStatusChanged!);
  }
  _startPlayback();
  return;
}
```

The early `return` is safe: `_startPlayback()` already respects
`widget.active` (line 180 returns immediately when inactive, and a later
reactivation re-enters via the existing `widget.active != oldWidget.active`
condition), and a fresh controller has nothing to stop or re-target, so
skipping the rest of the chain loses nothing.

Do NOT modify `VelocityTracking` (see Current state — identity `==` is
correct). Document on the `velocityTracking` property (line 97–98; it is a
`{@macro motor.velocityTracking}` reference whose template lives in
`base_motion_builder.dart:75` and is shared by other widgets — add the new
sentences BELOW the macro line in `phase_track_builder.dart`, not inside the
shared template): changing it recreates the controller and restarts playback;
a custom `velocityTrackerBuilder` closure should be stored in a field, not
recreated inline per build, or every rebuild will recreate the controller.

Test (`test/src/widgets/phase_track_builder_test.dart`): pump with tracking
on, rebuild with `const VelocityTracking.off()` → assert playback restarted
(fresh controller) and no exception/ticker leak; rebuild with an equal value
(`const VelocityTracking.on()` twice) → assert the controller is NOT
recreated (playback not restarted).

**Verify**: `flutter test test/src/widgets/phase_track_builder_test.dart` → all pass.

### Step 4: Fix D — assert on iteration-cap truncation

Add the assert after both loops as specified in Current state (use
`iterations <= 1000` semantics carefully: the loop exits with the cap fired
only when work remained — assert on
`_isDone || _isWaitingForSync || iterations < 1000` after the `advanceTo`
loop (line 189 ff.), and
`_isDone || iterations < 1000 || _segmentStartSeconds > elapsedSeconds` after
the `seekTo` loop (line 229 ff.), matching each loop's legitimate exits).

No new test (constructing a >1000-step timeline is slow and low-value); the
assert is the deliverable.

**Verify**: `flutter test` (whole package) → all pass; `dart analyze --fatal-infos` → exit 0.

### Step 5: CHANGELOG + gates

One "### Fixes" entry per fix (A–C; D is debug-only, group it with A's entry
or list separately).

**Verify**: `flutter test` → all pass, explicitly including
`test/src/controllers/legacy_sequence_semantics_test.dart` (plan 015's
behavior gate) and `test/src/controllers/status_semantics_test.dart`
(plan 016's status gate) with zero edits to either file.

## Test plan

- Fix A: motionless-loop (free-motion drift) wrap test (Step 1).
- Fix B: 2-keyframe + 3-keyframe seamless slice tests (Step 2).
- Fix C: recreate-on-change + no-recreate-on-equal widget tests (Step 3).
- Fix D: assert only.
- Full suite green throughout, including the 015 legacy-semantics gate and
  the 016 status-semantics gate, both unmodified.

## Done criteria

- [ ] `flutter test` exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] All four fixes present (read the diff against the Current-state excerpts)
- [ ] `git diff --stat` shows zero changes to
      `test/src/controllers/legacy_sequence_semantics_test.dart` and
      `test/src/controllers/status_semantics_test.dart`
- [ ] CHANGELOG updated
- [ ] `plans/README.md` status row updated (note any fix blocked by a STOP)

## STOP conditions

Stop and report back if:

- Fix A's snap-on-wrap breaks an existing loop test — that would mean some
  caller relies on the drift-through behavior; report which. (The 015
  legacy-semantics gate is the most likely tripwire: `SequenceMotionController`
  plays chains with `loop: LoopMode.none` only, so it should be unaffected —
  if it fails anyway, report.)
- Fix B's change affects `motionForPhase` results for `loop`/`none`/`pingPong`
  (it must only touch the `seamless` branch).
- Fix C requires touching `motion_velocity_tracker.dart` after all — the
  equality analysis in Current state would then be wrong; report before
  changing that file.

## Maintenance notes

- Consider exposing `velocityTracking` on `TrackBuilder` too (feature,
  deferred — noted here so it isn't re-audited as a gap).
- Plan 002 has landed: pingPong reverse legs replay recorded forward
  durations (`_forwardSegmentSeconds`) and never take the `LoopMode.loop`
  wrap branch, so Fix A's snap only applies to forward `loop` wraps —
  reviewers should confirm no snap logic leaked into the reverse path.
- Plan 005 (sync-barrier stop policy) is still open and also edits
  `track_controller.dart`; the two plans touch disjoint code, but whichever
  lands second should re-run the full suite.
