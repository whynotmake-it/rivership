# Plan 010: Design spike — typed per-track Animation views (`animationFor(Track<T>)`)

> **Executor instructions**: This is a **design/spike plan**, not a
> build-everything plan. The deliverable is a working prototype plus a short
> design document with resolved open questions — not a merged feature. Follow
> the steps, honor the STOP conditions, and when done update the status row in
> `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/track.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S–M (spike + prototype; productionizing is a follow-up)
- **Risk**: LOW (additive API)
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

`TrackController extends Animation<TrackValueReader>`: its `value` is a
*function* you call with a `Track` to read that track's current value. This
was a deliberate choice — it keeps the controller compatible with
`ValueListenable`/`ListenableBuilder` infrastructure while supporting many
typed tracks at once. The cost: it does not compose with the large ecosystem
of `Animation<T>` consumers — `Tween.animate`/`.drive()`, `CurvedAnimation`,
`AnimatedBuilder` patterns that read `animation.value` as a value,
`FadeTransition(opacity:)`, `SlideTransition(position:)`, etc.

The maintainer's own proposal (adopt it — do not redesign from scratch): add
**`Animation<T> animationFor(Track<T> track)`** on `TrackController` — a
lightweight typed view over one track. That yields both worlds: the reader
stays the primary multi-track API, and any single track can be handed to
standard Flutter animation consumers, e.g.
`FadeTransition(opacity: controller.animationFor(opacity))`.

## Current state

`packages/motor/lib/src/controllers/track_controller.dart`:

```21:26:packages/motor/lib/src/controllers/track_controller.dart
class TrackController extends Animation<TrackValueReader>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
```

```63:73:packages/motor/lib/src/controllers/track_controller.dart
  /// Returns a reader for the current track values.
  @override
  TrackValueReader get value => _read;

  @override
  AnimationStatus get status => _status;

  T _read<T extends Object>(Track<T> track) => _slot(track).value as T;

  /// Returns the current velocity for [track].
  T velocity<T extends Object>(Track<T> track) => _slot(track).velocity as T;
```

Relevant facts:

- The controller uses `AnimationEagerListenerMixin`: `dispose()` is where
  listeners die; there is no lazy add/remove ticker semantics to mirror.
- `status` is whole-controller (dismissed → forward → completed; never
  reverse). There is no per-track status today; per-track *animating* state
  exists on `_TrackSlot.isAnimating` (`_track_slot.dart:29`) but is private.
- Reading a track that has never been set/animated and has no `initial`
  asserts (`_resolveInitialValue`, `track_controller.dart:409-432`).
- Flutter precedent for view-animations: `Animation.drive` returns
  `_DrivenAnimation` backed by `AnimationWithParentMixin`, which delegates
  listeners/status to the parent and overrides only `value`. That is exactly
  the shape wanted here (`package:flutter/src/animation/animations.dart`,
  `AnimationWithParentMixin`).

Repo conventions: triple-slash dartdoc on all public API; tests as widget
tests with `tester.pump`; file layout one concept per file in `src/`.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Tests | `flutter test test/src/controllers/track_animation_view_test.dart` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- Prototype: `packages/motor/lib/src/controllers/track_controller.dart`
  (the `animationFor` method) — or a new
  `packages/motor/lib/src/controllers/track_animation_view.dart` if the class
  is non-trivial.
- Prototype test: `packages/motor/test/src/controllers/track_animation_view_test.dart` (create).
- Design write-up: `plans/010-animation-for-track-spike.notes.md` (create).

**Out of scope** (do NOT touch):
- Exporting from `lib/motor.dart` — leave the prototype unexported until the
  design is approved (the test can import via `package:motor/src/...`).
- Changing `TrackController`'s own `Animation<TrackValueReader>` shape — the
  reader API stays.
- README documentation — post-approval work.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Message: `feat(motor): prototype animationFor(track) typed animation views`.

## Steps

### Step 1: Prototype the view

Implement on `TrackController`:

```dart
/// Returns this track's values as a typed [Animation].
///
/// The view delegates listeners and status to this controller and reads
/// [Track] values through [value]. Use it to hand a single track to
/// standard Animation consumers (transitions, Tween.drive chains).
Animation<T> animationFor<T extends Object>(Track<T> track) =>
    _TrackAnimationView<T>(this, track);
```

with the view following Flutter's `AnimationWithParentMixin` pattern:

```dart
class _TrackAnimationView<T extends Object> extends Animation<T>
    with AnimationWithParentMixin<TrackValueReader> {
  _TrackAnimationView(this.parent, this._track);

  @override
  final TrackController parent;
  final Track<T> _track;

  @override
  T get value => parent.value(_track);
}
```

(`AnimationWithParentMixin` supplies listener/status delegation; confirm its
import path is exported from `package:flutter/animation.dart` — it is.)

Decide and document (in the notes file) whether to cache views per track
(`Map<Track, Animation>` on the controller) or return a new instance per call.
Recommendation to start from: return a new instance — the view is stateless
(two fields), and caching introduces a lifetime question for no measurable
win; note that `==` between two views of the same track is identity, which is
fine for framework consumers.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 2: Prototype tests

`test/src/controllers/track_animation_view_test.dart`:

1. `animationFor(track).value` equals `controller.value(track)` before, during
   (mid-`tester.pump`), and after an animation.
2. A `ListenableBuilder`/`AnimatedBuilder` on the view rebuilds when the
   controller ticks (listener delegation works).
3. Composition: `controller.animationFor(scale).drive(Tween(begin: 0.5, end: 1.0))`
   — assert the driven value maps correctly while animating (requires
   `T == double` for the Tween case; use a `MotionConverter.single` track).
4. `FadeTransition(opacity: controller.animationFor(opacity))` in a widget
   test — pumps without error and opacity follows the track.
5. Status: the view's `status` mirrors the whole controller (document this
   explicitly in the test name — per-track status is out of scope).
6. Disposal: disposing the controller after removing widget listeners doesn't
   throw; the view does not need its own dispose (assert via test that no
   ticker/listener leaks are reported by the test framework).

**Verify**: `flutter test test/src/controllers/track_animation_view_test.dart` → all pass.

### Step 3: Write the design notes

Create `plans/010-animation-for-track-spike.notes.md` answering, with evidence
from the prototype:

1. **Status semantics** — is whole-controller status acceptable for views, or
   does any real consumer (e.g. `AnimatedIcon`-style status listeners) need a
   per-track status? If needed, sketch what per-track status would require
   (`_TrackSlot.isAnimating` is available; direction is not — cross-reference
   how `MotionController` derives direction from `DirectionalMotionConverter`,
   `motion_controller.dart:262-284`).
2. **Lifetime** — views handed to long-lived widgets after controller
   disposal: what happens today (`AnimationEagerListenerMixin.dispose`
   behavior) and whether it matches `AnimationController` expectations.
3. **Naming** — `animationFor(track)` vs `track.animationOf(controller)` vs a
   getter-style `controller[track]`; recommend one (default: `animationFor`,
   the maintainer's own name).
4. **Uninitialized tracks** — reading a never-touched track asserts; should
   `animationFor` eagerly resolve the slot (forcing the assert at view
   creation, which is a better stack trace) or stay lazy? Recommend eager
   `_slot(track)` touch in `animationFor` when the track has an `initial`.
5. **Velocity** — should the view expose velocity (`velocityFor`)? Recommend
   deferring.
6. Go/no-go recommendation and the productionizing checklist (export from
   `motor.dart`, README section, CHANGELOG entry).

**Verify**: notes file exists and answers all six questions.

## Test plan

The six prototype tests in Step 2 double as the acceptance evidence for the
design notes. Full package suite must stay green: `flutter test` → all pass.

## Done criteria

- [ ] `flutter test` exits 0 (including the new view tests)
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] Prototype NOT exported from `lib/motor.dart`
      (`grep -n "track_animation_view" packages/motor/lib/motor.dart` → no match,
      if the separate-file option was taken)
- [ ] `plans/010-animation-for-track-spike.notes.md` answers all six questions
      with a go/no-go recommendation
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `AnimationWithParentMixin` cannot be used because `TrackController`'s
  listener mixins conflict — report the exact conflict and prototype a manual
  delegation instead only if it is <30 lines.
- Test 3 or 4 reveals a framework consumer that requires `status` transitions
  the whole-controller status cannot provide (e.g. never reaching `completed`
  while other tracks run) — capture the case in the notes and mark the spike
  "needs design review" rather than working around it.

## Maintenance notes

- If approved, productionizing must also update the `TrackController` doc note
  added by Plan 008 (which currently says composition "does not apply") to
  point at `animationFor`.
- A per-track `status` is the most likely follow-up request; the notes file's
  question 1 is the groundwork.
