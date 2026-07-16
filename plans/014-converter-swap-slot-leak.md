# Plan 014: Fix the per-track state leak when swapping MotionConverters

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 00e35e70..HEAD -- packages/motor/lib/src/controllers/motion_controller.dart packages/motor/lib/src/controllers/track_controller.dart packages/motor/test/src/controllers/motion_controller_test.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1 (unbounded memory growth in a documented usage pattern)
- **Effort**: S
- **Risk**: LOW (eviction of state that is by definition no longer reachable)
- **Depends on**: none (base: the merged batch-1 stack, commit `00e35e70`)
- **Category**: bug
- **Planned at**: commit `00e35e70`, 2026-07-14

## Why this matters

`MotionController` supports swapping its `MotionConverter` at runtime — a
documented 1.1.0 feature ("allow swapping MotionConverter on MotionController
and MotionBuilder types", used e.g. to animate `EdgeInsetsGeometry`
supertypes). Since the 2.0 rewrite, `MotionController` is a wrapper over a
single-track `TrackController`, and the converter setter creates a **new
`Track` instance per swap**. `TrackController` keys all per-track state by
track identity and never evicts: the old track's `_TrackSlot` (plus possible
`_lastStepByTrack` and `_tokenParticipants` entries) is stranded on every
swap. A widget that swaps converters per build or per direction change grows
memory without bound.

A reference fix exists on an orphaned branch: commit `b39ec8af`
("fix(motor): clean up old track slot on converter swap and guard
use-after-dispose"). Use it as a semantic reference only — it was written
against a diverged `TrackController` (it references a
`_pendingFallbackMotions` field that does not exist in the current code) and
its parents contain superseded work. Do NOT cherry-pick it.

## Current state

### The leak site — `packages/motor/lib/src/controllers/motion_controller.dart:134-157`

```dart
  set converter(MotionConverter<T> value) {
    if (value == _converter) return;
    // ... normalize/reinterpret ...
    if (_inner.isAnimating) _inner.stop(tracks: [_track], canceled: true);
    _converter = value;
    _track = Track<T>(value, initial: reinterpreted);   // new Track identity
    _inner
      ..set(
        [_track.value(reinterpreted)],
        withVelocity: [_track.velocity(reinterpretedVelocity)],
      )
      ..resetVelocityTracking();
    notifyListeners();
  }
```

The old `_track` is dropped without telling `_inner` to forget it.

### The keyed state — `packages/motor/lib/src/controllers/track_controller.dart:39-44`

```dart
  final List<TrackValue> _from;
  final Map<Track, _TrackSlot> _slots = {};
  final Map<Track, int> _lastStepByTrack = {};
  final Set<Track> _activeTracks = {};
  final Map<Object, Set<Track>> _tokenParticipants = {};
  final Map<Track, MotionVelocityTracker<Object>> _velocityTrackers = {};
```

There is no `_slots.remove(...)` anywhere in the file. What leaks per swap:
- `_slots[oldTrack]` — always (this is the main leak).
- `_lastStepByTrack[oldTrack]` — if the track ever reported a step.
- `_tokenParticipants` entries — only if steps with `Step.sync` were played
  through `MotionController.play` (rare but possible).
Not leaked: `_velocityTrackers` (the setter's `resetVelocityTracking()`
clears the whole map, line 94-96) and `_activeTracks` (the `stop(tracks:
[_track])` call removes it) — but `forgetTrack` should clear both anyway for
robustness, since the method will be the single "remove a track" primitive.

Since batch-1 merged, `_pruneTokenParticipants`-style logic may exist if Plan
005 has landed; check for a helper that removes tracks from
`_tokenParticipants` and reuse it if present (at planning time, Plan 005 was
still TODO and no helper exists).

### Reference implementation (adapt, don't copy) — `git show b39ec8af`

```dart
  /// Removes all internal state for [track].
  @internal
  void forgetTrack(Track track) {
    _slots[track]?.stop(canceled: true);
    _slots.remove(track);
    _activeTracks.remove(track);
    _velocityTrackers.remove(track);
    _lastStepByTrack.remove(track);
    for (final participants in _tokenParticipants.values) {
      participants.remove(track);
    }
    _tokenParticipants.removeWhere((_, participants) => participants.isEmpty);
  }
```

(The original also removed from `_pendingFallbackMotions` — skip; that field
doesn't exist in the current code.)

### Conventions

- `@internal` (from `package:meta/meta.dart`) marks package-private API — see
  `motionsEqual` in `motion_controller.dart` for the pattern.
- Test pattern: `packages/motor/test/src/controllers/motion_controller_test.dart`
  (widget tests, `tester` as vsync, `addTearDown(controller.dispose)`).

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/controllers/motion_controller_test.dart` | all pass |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

Note: the workspace resolves equatable 2.1.0 since plan 013 merged; a fresh
worktree's plain `dart pub get` from the worktree root is all the setup
needed (no lockfile pinning).

## Scope

**In scope**:
- `packages/motor/lib/src/controllers/track_controller.dart` (add `forgetTrack`)
- `packages/motor/lib/src/controllers/motion_controller.dart` (call it from
  the converter setter)
- `packages/motor/test/src/controllers/motion_controller_test.dart` (extend)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- Use-after-dispose assert guards (bundled in `b39ec8af`) — separate concern,
  deferred; note it in the CHANGELOG entry only if trivial to describe, else skip.
- Making swap-created tracks carry `motionPerDimension` as track defaults
  (also in `b39ec8af`) — behavior change to the graceful-settle path; the
  constructor-created track doesn't carry them either, so today's behavior is
  at least consistent. Record as a candidate finding, don't fix.
- `BoundedMotionController`, widgets, legacy controllers.

## Git workflow

Isolated worktree: plain git. Message:
`fix(motor): forget replaced track state on converter swap`.

## Steps

### Step 1: Add `forgetTrack` to TrackController

Add the method (adapted reference above, minus the nonexistent field), placed
near `stop`/`resync`. Dartdoc: "Removes all internal state for [track]. Used
when a track identity is being replaced (e.g. a converter swap creates a new
track). Stops the track's slot first if it is animating." Mark `@internal`.

If Plan 005 landed and a `_pruneTokenParticipants` helper exists, call it for
the token cleanup instead of inlining the loop.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 2: Call it from the converter setter

In `motion_controller.dart`, capture `final oldTrack = _track;` before
reassigning, and add `..forgetTrack(oldTrack)` as the first cascade member on
`_inner` (before `set`).

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 3: Tests

Extend `motion_controller_test.dart` with a `converter swap` group:

1. **Leak assertion (the real gate)**: add a `@visibleForTesting` getter on
   `TrackController` — `int get debugTrackCount => _slots.length;` — and
   assert it stays at 1 after 100 converter swaps on a `MotionController<Offset>`
   (each swap uses a fresh `MotionConverter.custom` instance so identity
   differs). Without the fix this reads 101.
   The test reaches the inner controller via
   `package:motor/src/controllers/...` imports; if `_inner` is inaccessible,
   instead construct a raw `TrackController`, `set`/`animate` two distinct
   tracks, call `forgetTrack` on one, and assert `debugTrackCount` drops —
   plus keep the 100-swap MotionController test as behavioral coverage.
2. **Behavior preserved**: after many swaps, `animateTo(const Offset(1, 1))`
   still settles at (1, 1) (mirror of the reference test).
3. **Reinterpretation unchanged**: swapping to an axis-flipped converter
   reinterprets the normalized value (value `(2,3)` reads `(3,2)` after the
   swap — mirror of the reference test).
4. **Mid-animation swap**: start `animateTo`, swap converter mid-flight,
   assert no exception, the animation is stopped, and the value is the
   reinterpreted current value.

**Verify**: `flutter test test/src/controllers/motion_controller_test.dart` → all pass.

### Step 4: CHANGELOG + full suite

CHANGELOG "Unreleased" → "### Fixes": swapping `converter` no longer leaks the
replaced track's internal state in the underlying `TrackController`.

**Verify**: `flutter test` → all pass; `dart analyze --fatal-infos` → exit 0.

## Test plan

The four cases in Step 3; case 1 is the machine-checkable leak gate. Full
suite green.

## Done criteria

- [ ] `flutter test` exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `grep -n "forgetTrack" packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/controllers/motion_controller.dart` → both present
- [ ] The leak test asserts a slot count (not just behavior)
- [ ] CHANGELOG updated
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The drift check fails (Plans 002/005/009 may land in the same files —
  re-read the excerpts against live code; proceed only if the leak site and
  keyed-state maps still match).
- `forgetTrack` breaks any existing sync/stop test — the eviction must be
  invisible to every path except converter swaps.
- Exposing `debugTrackCount` conflicts with lint rules that forbid
  `@visibleForTesting` on the class — report options instead of weakening the
  leak assertion.

## Maintenance notes

- `forgetTrack` becomes the single primitive for removing a track identity;
  if a future public API allows replacing tracks on `TrackController`
  directly, route it through this method.
- Deferred from `b39ec8af` and recorded here so it isn't lost: (a)
  use-after-dispose assert guards on `MotionController`; (b) whether
  swap-created (and constructor-created) tracks should carry
  `motionPerDimension` as track-level defaults for the slot settle path.
