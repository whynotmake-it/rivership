# Plan 003: Fix _seededFrom timeline-reuse bug and PhaseTrackBuilder active-resume bug

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/controllers/phase_track_controller.dart packages/motor/lib/src/widgets/phase_track_builder.dart packages/motor/lib/src/widgets/track_builder.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (independent of Plans 001/002; merge order with 002 doesn't matter — different code paths)
- **Category**: bug
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

Two lifecycle bugs in the 2.0 phase stack:

1. **`_seededFrom` never resets.** `PhaseTrackController` applies a timeline's
   one-time `from`/`withVelocity` seeds via `_seedFromIfNeeded`, guarded by a
   `_seededFrom` flag that is set once and never cleared. Playing a *second,
   different* timeline on the same controller silently skips that timeline's
   seeds — tracks keep values from the previous timeline. Any app that swaps
   timelines on one controller (including `PhaseTrackBuilder` when its
   `timeline` widget property changes) hits this.
2. **`PhaseTrackBuilder` can never be reactivated.** Toggling `active` from
   `false` back to `true` does nothing: `didUpdateWidget` handles only the
   deactivation transition, and the reactivation falls through all other
   conditions. The sibling widget `TrackBuilder` handles this exact case, so
   the phase variant is an inconsistency, not a design choice.

## Current state

### Bug 1 — `packages/motor/lib/src/controllers/phase_track_controller.dart`

The flag and its single assignment:

```35:39:packages/motor/lib/src/controllers/phase_track_controller.dart
  TrackPhaseTimeline<P>? _activeTimeline;
  void Function(PhaseTransition<P> transition)? _onTransition;
  P? _currentPhase;
  bool _isPlayingPhases = false;
  bool _seededFrom = false;
```

```135:148:packages/motor/lib/src/controllers/phase_track_controller.dart
  void _seedFromIfNeeded(TrackPhaseTimeline<P> timeline) {
    if (_seededFrom) return;
    _seededFrom = true;
    if (timeline.from.isEmpty && timeline.withVelocity.isEmpty) return;

    final values = <TrackValue>[...timeline.from];
    for (final velocity in timeline.withVelocity) {
      final hasFrom = timeline.from.any(
        (override) => identical(override.track, velocity.track),
      );
      if (!hasFrom) values.add(_currentValueSnapshot(velocity.track));
    }
    set(values, withVelocity: timeline.withVelocity);
  }
```

Entry points that install a timeline: `setTimeline` (lines 51–58) and
`playPhases` (lines 71–95). Neither resets `_seededFrom`. Note the intended
semantics documented on `TrackPhaseTimeline.from`
(`track_phase_timeline.dart:41-45`): seeds apply "only once (when a timeline
first begins playing) so navigating between phases animates from the current
values rather than snapping back to the seed each time". The once-per-timeline
intent must be preserved — the bug is only that "once" currently means
once-per-*controller*.

`TrackPhaseTimeline` is `Equatable` (`props` at `track_phase_timeline.dart:151-157`
include phases, animations, phaseLoop, from, withVelocity), so value comparison
of timelines works.

### Bug 2 — `packages/motor/lib/src/widgets/phase_track_builder.dart`

```149:168:packages/motor/lib/src/widgets/phase_track_builder.dart
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
      // ...
      _startPlayback(restart: true);
    } else if (timelineChanged || playingChanged) {
      _startPlayback();
    } else if (phaseChanged && widget.currentPhase != null) {
      _controller.goToPhase(widget.currentPhase!);
    }
```

The reference implementation that handles reactivation correctly —
`packages/motor/lib/src/widgets/track_builder.dart`:

```123:128:packages/motor/lib/src/widgets/track_builder.dart
    if (restartTriggerChanged) {
      _updatePlayback(restart: true);
    } else if (_playbackChanged(oldWidget) ||
        widget.active != oldWidget.active) {
      _updatePlayback();
    }
```

Existing widget tests to model after:
`packages/motor/test/src/widgets/phase_track_builder_test.dart` (standard
`testWidgets` + `tester.pump` pattern).

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/widgets/phase_track_builder_test.dart test/src/sync_step_test.dart` | all pass |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/controllers/phase_track_controller.dart`
- `packages/motor/lib/src/widgets/phase_track_builder.dart`
- `packages/motor/test/src/widgets/phase_track_builder_test.dart` (extend)
- `packages/motor/test/src/controllers/` — new file
  `phase_track_controller_seeding_test.dart`
- `packages/motor/CHANGELOG.md` ("Unreleased" → "### Fixes")

**Out of scope** (do NOT touch):
- `track_builder.dart` — it is the correct reference; leave it alone.
- `track_controller.dart`, `step_playback.dart`.
- The seamless/loop/pingPong logic in `_onStatusChanged` (Plan 002's territory).

## Git workflow

Colocated jj repo: `jj new` / `jj desc` for VCS mutations in the main
workspace; plain git in an isolated worktree. Message style:
`fix(motor): re-seed from/withVelocity when the active timeline changes`.

## Steps

### Step 1: Key seeding to the active timeline instead of the controller

In `phase_track_controller.dart`, replace the `bool _seededFrom` flag with a
record of *which timeline* was seeded:

```dart
TrackPhaseTimeline<P>? _seededTimeline;
```

In `_seedFromIfNeeded`:

```dart
void _seedFromIfNeeded(TrackPhaseTimeline<P> timeline) {
  if (_seededTimeline == timeline) return; // Equatable value comparison
  _seededTimeline = timeline;
  if (timeline.from.isEmpty && timeline.withVelocity.isEmpty) return;
  // ... rest unchanged
}
```

Using value equality (not `identical`) preserves the documented
once-per-timeline behavior when a widget rebuild passes an equal-but-new
timeline instance, while a genuinely different timeline re-seeds.

Also reset `_seededTimeline = null` nowhere else — `setTimeline` and
`playPhases` already call `_seedFromIfNeeded` (via `playPhases`) or are
followed by `goToPhase` which calls it (line 115); the value comparison makes
explicit resets unnecessary.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 2: Controller-level seeding tests

Create `packages/motor/test/src/controllers/phase_track_controller_seeding_test.dart`
(model the widget-test setup on `sync_step_test.dart`'s controller groups):

1. Timeline A with `from: [track.value(10)]` → `playPhases(A)` → assert the
   track starts at 10. After settle, `playPhases(B)` where B has
   `from: [track.value(99)]` → assert the track snaps to 99 before animating
   (this is the bug fix).
2. Replay the *same* timeline A (equal value) after settling mid-values →
   assert the seed is NOT re-applied (documented once-per-timeline semantics,
   `track_phase_timeline.dart:41-45`).
3. `withVelocity`-only seed (no `from` entry for the track): assert the track
   keeps its current value but starts with the seeded velocity (overshoot
   observable with a spring motion), and that a second, different timeline's
   velocity seed also applies.

**Verify**: `flutter test test/src/controllers/phase_track_controller_seeding_test.dart` → all pass.

### Step 3: Fix reactivation in PhaseTrackBuilder

In `phase_track_builder.dart` `didUpdateWidget`, mirror `TrackBuilder`: after
the `restartTriggerChanged` branch, include the reactivation condition:

```dart
if (restartTriggerChanged) {
  _startPlayback(restart: true);
} else if (timelineChanged ||
    playingChanged ||
    widget.active != oldWidget.active) {
  _startPlayback();
} else if (phaseChanged && widget.currentPhase != null) {
  _controller.goToPhase(widget.currentPhase!);
}
```

(`_startPlayback` already early-returns when `!widget.active`, and the
deactivation transition is handled by the guard above it, so the only new
behavior is: `active` false→true restarts playback from the current widget
configuration.)

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 4: Widget tests for active toggling

Extend `phase_track_builder_test.dart`:

1. Pump a `PhaseTrackBuilder(playing: true, active: true, ...)` with a 2-phase
   looping timeline; pump `active: false` (values freeze); pump `active: true`
   → assert values start changing again within a few frames.
2. Same for manual mode: `active: false→true` with a `currentPhase` set →
   assert the controller animates to that phase's values.
3. Regression guard: rebuild with an equal-value timeline while active →
   assert playback does NOT restart (compare values across the rebuild
   mid-animation; model after `track_builder_test.dart:138-163`).

**Verify**: `flutter test test/src/widgets/phase_track_builder_test.dart` → all pass.

### Step 5: CHANGELOG

Add two entries under "Unreleased" → "### Fixes" in
`packages/motor/CHANGELOG.md` describing both bugs from the user's
perspective.

**Verify**: `flutter test` (whole package) → all pass.

## Test plan

- New: `phase_track_controller_seeding_test.dart` — 3 cases (re-seed on new
  timeline; no re-seed on equal timeline; velocity-only seeds).
- Extended: `phase_track_builder_test.dart` — 3 cases (reactivation in playing
  and manual mode; no-restart on equal rebuild).
- Full suite green: `flutter test`.

## Done criteria

- [ ] `flutter test` (packages/motor) exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `grep -n "_seededFrom" packages/motor/lib/` returns no matches
- [ ] CHANGELOG updated under "Unreleased"
- [ ] No files outside the in-scope list modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The excerpts above don't match the live code (drift — especially if Plan 002
  landed first and reshaped `_onStatusChanged`; that's fine, but if it touched
  `_seedFromIfNeeded` or `didUpdateWidget`, re-read before editing).
- Test 2 in Step 2 fails because equal-value timeline replay DOES re-seed:
  that means `TrackPhaseTimeline` equality is broken (check `props`), which is
  a separate bug — report it rather than switching to `identical`.
- Fixing reactivation requires changes to `_startPlayback`'s restart logic
  beyond the condition shown.

## Maintenance notes

- The seeding semantics are now: once per *timeline value* per controller.
  If a future API wants "re-seed on every play", that should be an explicit
  parameter, not a behavior change here.
- Reviewers should check that `active` toggling doesn't double-start playback
  when combined with a simultaneous `timeline` change (both conditions true in
  one `didUpdateWidget` — the single `else if` chain handles it, keep it that way).
