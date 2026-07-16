# Plan 015: Delete the legacy MotionController copy; rebase the deprecated sequence APIs on the new engine

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 78aff46..HEAD -- packages/motor/lib/src/controllers packages/motor/lib/src/simulations packages/motor/lib/src/widgets/sequence_motion_builder.dart packages/motor/lib/motor.dart packages/motor/test/src/controllers packages/motor/test/src/widgets`
> If any listed file changed since `78aff46`, verify these anchors in the
> live code before proceeding; on a mismatch, STOP:
> - `legacy_motion_controller.dart` is 1,218 lines and `motor.dart` exports it
>   with `show SequenceMotionController` only (motor.dart lines 5–7);
> - `test/src/controllers/legacy_sequence_semantics_test.dart` exists (plan
>   007's numeric pins, 198 lines);
> - the "Mechanism anchors" excerpts under Current state below still match
>   `step_playback.dart`, `track_controller.dart`,
>   `no_motion_simulation.dart`, and `motion_controller.dart` — this plan's
>   design depends on those exact behaviors.
>
> Also check the plan 015 row's neighbors in `plans/README.md`: if plan 005
> has moved past TODO, see "Interactions with pending plans" under
> Maintenance notes.

## Status

- **Priority**: P1 (upgraded in `plans/README.md`: fixes a 1.x→2.0
  source-compatibility break)
- **Effort**: M (the design below is fully specified; the work is a ~250-line
  part file plus wiring and tests)
- **Risk**: MED (behavioral drift for existing sequence users; gated by the
  numeric semantics tests and goldens)
- **Depends on**: plans 002 and 007 (both merged into the stack)
- **Category**: tech-debt
- **Planned at**: commit `78aff46`, 2026-07-15
- **Revised**: 2026-07-15 — an independent, reference-blinded design review
  replaced the earlier "port the abandoned prototype" approach with the
  self-contained design below, derived only from the current engine. The
  engine itself (`track_controller.dart`, `_track_slot.dart`,
  `step_playback.dart`) is no longer modified by this plan.

## Why this matters

**The 2.0 type hierarchy is currently broken for sequence users.** Two
different classes named `MotionController` exist:

- `lib/src/controllers/motion_controller.dart:44` declares the NEW
  `MotionController`, which `motor.dart:8-9` exports
  (`show BoundedMotionController, MotionController`).
- `lib/src/controllers/legacy/legacy_motion_controller.dart:47` declares an
  unexported legacy copy with the same name, and `SequenceMotionController`
  (same file, lines 799–800) extends THAT copy — `motor.dart:5-7` exports
  only `SequenceMotionController` from the legacy file.

So for any consumer of `package:motor/motor.dart`,
`SequenceMotionController` is NOT a subtype of the `MotionController` they
can name: `MotionController<Offset> c = SequenceMotionController(...)` fails
to compile. In motor 1.x there was a single class, so this assignment worked
— which contradicts the CHANGELOG's promise (CHANGELOG.md lines 3–6) that
`SequenceMotionController` "stay[s] source-compatible" in 2.0. Any 1.x app
that passes its sequence controller to an API typed `MotionController<T>`
breaks. Rebasing `SequenceMotionController` onto the exported
`MotionController` restores the IS-A relationship and the compatibility
promise.

Secondary benefit: the legacy file carries a full private copy of the
pre-2.0 `MotionController`/`BoundedMotionController` (~790 lines of
duplicated controller code — its own ticker loop, converter-swap setter,
velocity tracking) solely as the base class for the deprecated-but-supported
`SequenceMotionController`. Controller-layer fixes land only in the new
engine (e.g. plan 014's converter-swap track eviction has no counterpart in
the legacy converter setter at `legacy_motion_controller.dart:130-140`), so
the legacy copy silently diverges for the rest of 2.x. Rebasing deletes the
duplicate now instead of carrying it to 3.0, and makes the deprecated APIs
benefit from every future engine fix.

**This plan overturns a recorded rejection.** The 2.0 planning round rejected
this as "L effort, MED-HIGH risk, no user benefit before 3.0 deletes it".
The maintainer approved the overturn on 2026-07-15: plan 007's numeric
characterization tests (`legacy_sequence_semantics_test.dart`) now pin legacy
loop semantics far more precisely than the golden PNGs the original
rejection had to rely on, and the source-compatibility break above upgraded
the user impact. (An earlier draft of this plan proposed porting an
abandoned prototype from an orphaned commit line; this revision replaces
that with the self-contained design below and does not require reading any
orphaned commits.)

## Current state

### What exists today (current stack tip)

- `packages/motor/lib/src/controllers/legacy/legacy_motion_controller.dart`
  (1,218 lines) — legacy `MotionController` (line 47) +
  `BoundedMotionController` (line 592), both unexported, plus the public,
  `@Deprecated` `SequenceMotionController` (line 799, annotated by plan 007;
  extends the legacy `MotionController`, not the exported one). Public API
  surface of `SequenceMotionController` (all of it must survive verbatim):
  default constructor and `.motionPerDimension` (both `@Deprecated`),
  `playSequence(sequence, {atPhase, withVelocity, onTransition})`,
  `currentSequencePhase`, `isPlayingSequence`, `activeSequence`,
  `sequenceProgress`, plus overrides of `value=`, `animateTo`, `play`,
  `stop`, `dispose`, `motion=`, `motionPerDimension=`.
- `packages/motor/lib/motor.dart` lines 5–9 (verbatim):

```5:9:packages/motor/lib/motor.dart
export 'src/controllers/legacy/legacy_motion_controller.dart'
    // ignore: deprecated_member_use_from_same_package
    show SequenceMotionController;
export 'src/controllers/motion_controller.dart'
    show BoundedMotionController, MotionController;
```

- `packages/motor/lib/src/widgets/sequence_motion_builder.dart` — the
  `@Deprecated` `SequenceMotionBuilder`; its only tie to the legacy engine is
  the import on line 4 (`import 'package:motor/src/controllers/legacy/legacy_motion_controller.dart';`).
  Everything else it uses (`playSequence`, `currentSequencePhase`, `value`,
  `motion=`, `animateTo`) exists identically on the rewritten controller.
- The behavior gate:
  `packages/motor/test/src/controllers/legacy_sequence_semantics_test.dart` —
  numeric pins for none/loop/seamless/pingPong on `SequenceMotionController`,
  written by plan 007 explicitly so this rewrite could be verified. **These
  tests must pass without any expectation changes.** The second gate:
  `test/src/controllers/phase_sequence_controller_test.dart` and
  `test/src/widgets/sequence_motion_builder_test.dart` pin the
  `MotionController` API compatibility surface and the builder behavior; with
  this design they are expected to pass **unchanged** too.
- Golden PNGs under `packages/motor/test/src/widgets/golden/` pin sequence
  rendering (`loop_mode_*.png`, `spanning.png`, `state_manual_change.png`,
  `restart_trigger.png`, `state_sequence_1d_animation.png`).

### Legacy timing model (what the gate actually pins)

The legacy `SequenceMotionController` plays ONE phase at a time and
re-anchors each phase's start time to the tick at which the previous phase
was observed complete (`_setupPhaseSimulation` sets
`_currentPhaseStartTime = _lastElapsedDuration`, legacy file line 985). The
gate's numeric expectations encode this tick quantization. Concretely, for
`MotionSequence.steps([0, 1, 2], motion: linear100)` (100 ms linear phases):

- `playSequence` first sets up a leg to the initial phase with
  `motionForPhase(toPhase: first, fromPhase: null)`, which is `NoMotion` for
  plain `steps`/`states` sequences. `NoMotionSimulation.isDone(t)` is
  STRICTLY `t > 0`, so this leg completes on the SECOND tick (t=1 ms in the
  gate), and phase legs anchor at t = 1, 102, 203, 304 … (each pump
  overshoots the 100 ms boundary by 1 ms). The gate's mid-leg checks
  (`value ≈ 0.5` at t=51, `≈ 1.5` at t=152, …) only hold under this
  re-anchoring.
- `LoopMode.none`: events `T(0→1)` at t=1, `T(1→2)` at t=102,
  `PhaseSettled(2)` at t=203; final value exactly 2.
- `LoopMode.loop`: after the last phase, an ANIMATED return leg to phase 0
  using `motionForPhase(toPhase: 0, fromPhase: last)` (NOT `NoMotion` — the
  `fromPhase` is non-null), anchored at the completion tick (203): value 1.5
  at t=228, 1.0 at t=253, exactly 0 at t=304 with `currentSequencePhase == 1`.
- `LoopMode.pingPong`: after the last phase, phases are revisited in reverse
  (`n-2 … 0`), each reverse leg using
  `motionForPhase(toPhase: i, fromPhase: i+1)`, then forward again from
  index 1. Pinned visit order: `[0, 1, 2, 1, 0, 1]`.
- `LoopMode.seamless`: after the last phase, the value JUMPS to
  `valueForPhase(first)`, `PhaseSettled(first)` is emitted, and playback
  continues to phase 1 in the same frame (`T(first→second)`), anchored at
  the completion tick.
- `SpanningSequence` needs no special handling: its per-transition motion
  trimming lives entirely inside `motionForPhase` (motion_sequence.dart
  lines 539–571, returning `motion.sliced(from:, to:)` for the segment
  between the two positioned phases, in either direction). Any design that
  calls `motionForPhase(toPhase:, fromPhase:)` with the same arguments as
  legacy gets identical spanning behavior for free.
- Interruption semantics (pinned by `phase_sequence_controller_test.dart`):
  `value=`, `animateTo`, `play`, and `stop` all silently kill the sequence
  first (`isPlayingSequence` → false, `activeSequence` → null, no
  `PhaseSettled` emitted), then behave like the plain `MotionController`
  member. `motion=`/`motionPerDimension=` do NOT redirect an in-flight
  animation (legacy overrides them to skip redirection).

### Why the new engine can reproduce this without modification (mechanism anchors)

These are the load-bearing facts of the design; verify each excerpt still
matches before implementing (drift check):

1. **`Step.sync` re-anchors to the tick.** A single-track chain can carry
   `Step.sync` barriers between phases. When playback reaches a sync step it
   pauses; `TrackController._tick` releases a token in the SAME tick once
   every participating track waits on it (a single track is trivially
   "all ready"), and the release re-anchors the next segment to the tick's
   elapsed time — exactly the legacy quantization:

```167:172:packages/motor/lib/src/simulations/step_playback.dart
  void releaseSync() {
    if (!_isWaitingForSync) return;
    _isWaitingForSync = false;
    _segmentStartSeconds = _lastElapsedSeconds;
    _advanceStep();
  }
```

2. **`onStep` reports the barrier at the right tick.**
   `TrackController._notifyStep` (track_controller.dart lines 588–600) fires
   at most one step-index change per track per tick, and it runs BEFORE the
   sync-release loop in `_tick` (lines 534–570). So when a phase's `Step.to`
   finishes at tick t, playback stops AT the following sync step (index
   observed by `_notifyStep` at t), and the release advances to the next
   `Step.to` afterwards. Result: `onStep` fires with each sync step's index
   at exactly the tick where the previous phase completed — the same tick at
   which legacy emitted `PhaseTransitioning`. Large time gaps still stop at
   every barrier, so transitions can never be skipped within one tick.

3. **`NoMotion` holds for one tick.**
   `no_motion_simulation.dart:29` — `bool isDone(double time) => time > duration.toSeconds();`
   (strict), so a `Step.to(v, motion: NoMotion())` first step completes on
   the second tick, matching the legacy initial-phase timing exactly. Note
   `NoMotionSimulation.x` returns the START value — the initial leg holds at
   the current value for one tick and never jumps to the phase value, which
   is also exactly what legacy did.

4. **The wrapper's privates are reachable from a `part`.**
   `MotionController` (motion_controller.dart) holds `_inner`
   (`TrackController`), `_track`, `_status`, `_lastTarget`,
   `_checkStatusChanged()`, and the inner-status listener
   `_handleInnerStatus(AnimationStatus)` (lines 345–357), registered once in
   the constructor as a tear-off. In Dart, private members are virtual within
   a library, so a `part` file can `@override _handleInnerStatus` and the
   registered tear-off dispatches to the subclass — this is the hook for
   advancing loop cycles without ever emitting a spurious
   `AnimationStatus.completed` between cycles.

5. **Chain replays anchor correctly across cycles.** When a chain finishes,
   `TrackController._tick` stops the ticker and THEN notifies status
   listeners. Starting the next cycle's chain synchronously inside that
   status callback restarts the ticker within the frame, and Flutter's
   `Ticker.start()` backdates `_startTime` to `currentFrameTimeStamp` when
   started during a frame — so the next cycle is anchored at the completion
   tick, matching legacy. (This is framework behavior; it is what makes the
   pinned loop values at t=228/253 work.)

6. **Velocity hands off across phases and cycles.** Within a chain,
   `StepPlayback` carries velocities across segments. Across cycles, a
   naturally-completed slot keeps its final velocities (`_TrackSlot.stop` is
   NOT called on natural completion), and the next `play` inherits them —
   equivalent to legacy passing `velocities` into the next phase setup.

### Repo conventions that apply

- `part` files: see `track_controller.dart` line 15 (`part '_track_slot.dart';`)
  and `_track_slot.dart` line 1 (`part of 'track_controller.dart';`).
- Deprecated self-use: files touching the deprecated sequence types start
  with `// ignore_for_file: deprecated_member_use_from_same_package` (see
  `motion_sequence.dart:1`, `sequence_motion_builder.dart:1`).
- Dartdoc: triple-slash, detailed; copy the legacy class/member docs verbatim
  where the API is unchanged.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected |
|---------|----------------------------------|----------|
| Behavior gate | `flutter test test/src/controllers/legacy_sequence_semantics_test.dart` | all pass, ZERO expectation changes |
| Sequence tests | `flutter test test/src/controllers/phase_sequence_controller_test.dart test/src/widgets/sequence_motion_builder_test.dart test/src/widgets/sequence_motion_builder_golden_test.dart` | all pass |
| Full | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |
| Example | `cd example && dart analyze` | exit 0 |

Environment: `dart pub get` from the worktree root (pub workspace); analysis
is clean on fresh resolution.

## Scope

**In scope**:
- `packages/motor/lib/src/controllers/legacy/legacy_motion_controller.dart` (delete)
- `packages/motor/lib/src/controllers/sequence_motion_controller.dart` (create, `part of` motion_controller.dart, `@Deprecated` preserved)
- `packages/motor/lib/src/controllers/motion_controller.dart` (add `part` directive and the imports the part needs — nothing else)
- `packages/motor/lib/src/widgets/sequence_motion_builder.dart` (import swap only)
- `packages/motor/lib/motor.dart` (export path update)
- `packages/motor/test/src/controllers/phase_sequence_controller_test.dart` (add the new tests from the Test plan; existing tests unchanged)
- `packages/motor/test/src/widgets/sequence_motion_builder_test.dart` (expected to pass with ZERO edits; any edit needs a per-test justification in your report — see Step 4)
- `packages/motor/test/src/widgets/golden/*.png` (only under the golden policy below)
- `packages/motor/MIGRATION.md` (update the 3.0 checklist: legacy folder already deleted; 3.0 now removes only the deprecated API surface)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- **The engine**: `track_controller.dart`, `_track_slot.dart`,
  `step_playback.dart`, anything under `lib/src/simulations/`. This design
  requires zero engine changes; if you find yourself editing these files,
  the design's assumptions are broken — that is a STOP, not a workaround.
- The `@Deprecated` annotations/messages and the deprecation timeline — the
  public API surface and its deprecation status are unchanged.
- `legacy_sequence_semantics_test.dart` — the gate; it must not be edited.
- `test/src/widgets/sequence_motion_builder_golden_test.dart` — the golden
  harness and its expectations must not change; only the PNGs may change,
  under the golden policy.
- `motion_sequence.dart` — `MotionSequence` types are unchanged.
- `phase_track_controller.dart`, `phase_track_builder.dart`.

## Git workflow

Isolated worktree, plain git. Branch: `agent/plan-015-sequence-rebase`
(matching the stack's `agent/plan-NNN-<slug>` bookmark convention, e.g.
`agent/plan-014-converter-leak`). Two commits:
`feat(motor)!: rebase SequenceMotionController and SequenceMotionBuilder onto the track engine`
then `chore(motor): delete legacy controller copy`. Do NOT push or open a PR
unless the operator instructed it.

## Steps

### Step 1: Create the rewritten SequenceMotionController (part file)

Create `packages/motor/lib/src/controllers/sequence_motion_controller.dart`
with `part of 'motion_controller.dart';` as line 1 (after an
`// ignore_for_file: deprecated_member_use_from_same_package` comment), and
add `part 'sequence_motion_controller.dart';` to `motion_controller.dart`
along with imports for `motion_sequence.dart` and `phase_transition.dart`.
Copy the class-level dartdoc, the `@Deprecated` annotation and message, both
constructors (`SequenceMotionController(...)` and `.motionPerDimension(...)`,
each with their own `@Deprecated`), and every public member's dartdoc
verbatim from the legacy file (lines 774–872 and the member docs below them).

The implementation, in full:

**State** (mirrors legacy bookkeeping):

```dart
MotionSequence<P, T>? _activeSequence;
List<P> _chainRun = const [];          // phases of the currently playing chain
int _currentSequencePhaseIndex = 0;    // index into _activeSequence.phases
int _sequenceDirection = 1;            // 1 forward, -1 pingPong reverse
void Function(PhaseTransition<P> transition)? _onPhaseTransition;
bool _isPlayingSequence = false;
P? _currentSequencePhase;
P? _previousSequencePhase;
```

Public getters exactly as legacy: `currentSequencePhase`,
`isPlayingSequence`, `activeSequence`, and

```dart
double get sequenceProgress {
  if (_activeSequence == null || !_isPlayingSequence) return 0;
  final totalPhases = _activeSequence!.phases.length;
  if (totalPhases <= 1) return 1;
  return _currentSequencePhaseIndex / (totalPhases - 1);
}
```

**Chain construction and playback.** A "chain" is one directional run of
phases played as a single `super.play(...)` call. Steps alternate
`Step.to` / `Step.sync`, so the step index layout is: index `2i` is the
`Step.to` for `run[i]`, index `2i−1` is the sync barrier released when the
leg into `run[i−1]` finishes:

```dart
TickerFuture _playChain(
  List<P> run, {
  required P? fromPhaseForFirstLeg,
  T? withVelocity,
  bool emitTransition = true,
}) {
  final sequence = _activeSequence!;
  _chainRun = run;
  final previous = _currentSequencePhase;
  _previousSequencePhase = previous;
  _currentSequencePhase = run.first;
  _currentSequencePhaseIndex = sequence.phases.indexOf(run.first);

  final steps = <Step<T>>[
    Step.to(
      sequence.valueForPhase(run.first),
      motion: sequence.motionForPhase(
        toPhase: run.first,
        fromPhase: fromPhaseForFirstLeg,
      ),
    ),
    for (var i = 1; i < run.length; i++) ...[
      Step.sync(token: Object()),
      Step.to(
        sequence.valueForPhase(run[i]),
        motion: sequence.motionForPhase(
          toPhase: run[i],
          fromPhase: run[i - 1],
        ),
      ),
    ],
  ];

  if (withVelocity != null) {
    // Seed the track's velocity without moving its value.
    _inner.set([_track.value(value)],
        withVelocity: [_track.velocity(withVelocity)]);
  }
  if (emitTransition && previous != null) {
    _onPhaseTransition?.call(
      PhaseTransitioning(from: previous, to: run.first),
    );
  }
  final future = super.play(steps, loop: LoopMode.none, onStep: _onChainStep);
  // play() nulls _lastTarget; restore it so _getStatusWhenDone() reports
  // completed/dismissed against the current phase target, like legacy.
  _lastTarget = sequence.valueForPhase(run.first);
  return future;
}
```

Notes: each barrier gets a fresh `Object()` token (tokens only exist to make
the single track wait-and-release at the tick; nothing reads them). The
engine's `LoopMode` is ALWAYS `none` — looping is handled at this layer, in
`_handleInnerStatus` below, because the engine's own `loop`/`pingPong` use
different return/reverse-leg motions than the legacy semantics pin.

**Transitions from `onStep`.** Odd indices are the sync barriers; they fire
at exactly the tick where the previous phase completed (mechanism anchor 2):

```dart
void _onChainStep(int stepIndex) {
  if (!_isPlayingSequence) return;
  if (stepIndex.isEven) return; // Step.to of the already-reported phase.
  final runIndex = (stepIndex + 1) ~/ 2;
  final from = _chainRun[runIndex - 1];
  final to = _chainRun[runIndex];
  _previousSequencePhase = from;
  _currentSequencePhase = to;
  _currentSequencePhaseIndex = _activeSequence!.phases.indexOf(to);
  _lastTarget = _activeSequence!.valueForPhase(to);
  _onPhaseTransition?.call(PhaseTransitioning(from: from, to: to));
}
```

**playSequence** (signature, dartdoc, `ArgumentError` behavior identical to
legacy lines 897–952):

```dart
TickerFuture playSequence(
  MotionSequence<P, T> sequence, {
  P? atPhase,
  T? withVelocity,
  void Function(PhaseTransition<P> transition)? onTransition,
}) {
  _stopSequence();
  if (sequence.phases.isEmpty) return TickerFuture.complete();
  _activeSequence = sequence;
  _onPhaseTransition = onTransition;
  _isPlayingSequence = true;
  _sequenceDirection = 1;
  final targetPhase = atPhase ?? sequence.initialPhase;
  final startIndex = sequence.phases.indexOf(targetPhase);
  if (startIndex == -1) {
    throw ArgumentError('Phase $targetPhase not found in sequence');
  }
  return _playChain(
    sequence.phases.sublist(startIndex),
    fromPhaseForFirstLeg: null, // yields NoMotion for plain sequences
    withVelocity: withVelocity,
    emitTransition: false,      // legacy emits nothing at playSequence time
  );
}
```

**Loop handling — the `_handleInnerStatus` override.** This intercepts the
inner controller's completion BEFORE the base class can report
`AnimationStatus.completed` mid-sequence (legacy keeps status `forward`
across cycles):

```dart
@override
void _handleInnerStatus(AnimationStatus status) {
  if (!_isPlayingSequence || status != AnimationStatus.completed) {
    super._handleInnerStatus(status);
    return;
  }
  final sequence = _activeSequence!;
  final phases = sequence.phases;
  switch (sequence.loop) {
    case LoopMode.none:
      _completeSequence();
    case LoopMode.loop:
      // Animated return leg to the first phase, then the rest — the
      // fromPhase makes motionForPhase return a real motion, not NoMotion.
      _playChain(phases, fromPhaseForFirstLeg: _chainRun.last);
    case LoopMode.pingPong:
      if (_sequenceDirection == 1) {
        _sequenceDirection = -1;
        var start = phases.length - 2;
        if (start < 0) start = 0; // legacy clamp for single-phase sequences
        _playChain(
          [for (var i = start; i >= 0; i--) phases[i]],
          fromPhaseForFirstLeg: _chainRun.last,
        );
      } else {
        _sequenceDirection = 1;
        var start = 1;
        if (start >= phases.length) start = phases.length - 1;
        _playChain(
          phases.sublist(start),
          fromPhaseForFirstLeg: _chainRun.last,
        );
      }
    case LoopMode.seamless:
      final first = phases.first;
      _inner.set([_track.value(sequence.valueForPhase(first))]);
      _inner.resetVelocityTracking();
      _previousSequencePhase = _currentSequencePhase;
      _currentSequencePhase = first;
      _currentSequencePhaseIndex = 0;
      _onPhaseTransition?.call(PhaseSettled(first));
      if (phases.length == 1) {
        // Degenerate single-phase seamless: nothing to continue to.
        _completeSequence();
        return;
      }
      _playChain(phases.sublist(1), fromPhaseForFirstLeg: first);
  }
}
```

All of this runs synchronously inside the status callback, which fires
during the completion tick — so the next chain is anchored at that tick
(mechanism anchor 5). Do NOT defer any of it to a post-frame callback: a
ticker started in the `postFrameCallbacks` phase is not backdated to the
frame timestamp, which would shift every pinned loop/seamless value by one
inter-frame gap. (Legacy used a post-frame callback for the seamless
continuation; because it ran within the same `tester.pump`, the observable
per-frame event order — `PhaseSettled(first)` then
`PhaseTransitioning(first→second)` with the value already jumped — is
identical under the synchronous form. The semantics gate's seamless test
pins exactly that order.)

**Completion and teardown:**

```dart
void _completeSequence() {
  final finalPhase = _currentSequencePhase;
  _isPlayingSequence = false;
  _currentSequencePhase = null;
  _previousSequencePhase = null;
  _activeSequence = null;
  _chainRun = const [];
  if (finalPhase != null) {
    _onPhaseTransition?.call(PhaseSettled(finalPhase));
  }
  _onPhaseTransition = null;
  // Now let the base class evaluate the resting status (completed, or
  // dismissed when the final phase value equals the initial value).
  super._handleInnerStatus(AnimationStatus.completed);
}

void _stopSequence() {
  if (!_isPlayingSequence) return;
  _isPlayingSequence = false;
  _currentSequencePhase = null;
  _previousSequencePhase = null;
  _onPhaseTransition = null;
  _activeSequence = null;
  _chainRun = const [];
}
```

**Overrides** (bodies exactly as listed; these are pinned by
`phase_sequence_controller_test.dart`):

```dart
@override
set value(T newValue) { _stopSequence(); super.value = newValue; }

@override
TickerFuture animateTo(T target, {T? from, T? withVelocity}) {
  _stopSequence();
  return super.animateTo(target, from: from, withVelocity: withVelocity);
}

@override
TickerFuture play(List<Step<T>> steps,
    {LoopMode? loop, void Function(int stepIndex)? onStep}) {
  _stopSequence();
  return super.play(steps, loop: loop, onStep: onStep);
}

@override
TickerFuture stop({bool canceled = false}) {
  _stopSequence();
  return super.stop(canceled: canceled);
}

@override
void dispose() { _stopSequence(); super.dispose(); }

// Not present on legacy, required here: the base converter setter hard-stops
// the inner track (firing a completed status this class would misread as a
// chain completion) and then replaces the Track identity, which would strand
// the sequence on a forgotten track. Treat a converter swap as an
// interruption, like value=/animateTo.
@override
set converter(MotionConverter<T> newConverter) {
  _stopSequence();
  super.converter = newConverter;
}

// Legacy behavior: setting motions during a sequence must NOT redirect the
// in-flight animation (the base setters call _redirect()).
@override
set motion(Motion value) {
  _motionPerDimension = List.filled(_motionPerDimension.length, value);
}

@override
set motionPerDimension(Iterable<Motion> value) {
  assert(
    value.length == _motionPerDimension.length,
    'the number of motions must match the number of dimensions',
  );
  if (motionsEqual(_motionPerDimension, value)) return;
  _motionPerDimension = value.toList();
}
```

**Verify**: `dart analyze --fatal-infos` → exit 0 (the new class coexists
with the legacy one for now — they live in different libraries and only the
legacy one is exported).

### Step 2: Flip the wiring and delete the legacy file

1. `motor.dart`: delete lines 5–7 (the legacy export) and change the
   `motion_controller.dart` export to
   `show BoundedMotionController, MotionController, SequenceMotionController`,
   keeping an `// ignore: deprecated_member_use_from_same_package` above the
   `show` line if the analyzer requires it.
2. `sequence_motion_builder.dart` line 4: replace the legacy import with
   `import 'package:motor/src/controllers/motion_controller.dart';`. No
   other changes to this file.
3. Delete `packages/motor/lib/src/controllers/legacy/` entirely.

**Verify**: `dart analyze --fatal-infos` → exit 0;
`grep -rn "legacy_motion_controller" lib test` (from `packages/motor/`) → no
matches; then the gate:
`flutter test test/src/controllers/legacy_sequence_semantics_test.dart` →
all pass with zero edits to that file. If any gate test fails, compare the
observed event order/values against the "Legacy timing model" section above
and fix the controller — if the only fix would be editing the semantics
test, STOP.

### Step 3: Add the type-hierarchy and behavior tests

In `test/src/controllers/phase_sequence_controller_test.dart`, inside the
existing `group('MotionController API compatibility', ...)` (currently at
line 32), add as the first test:

```dart
testWidgets('is assignable to the exported MotionController',
    (tester) async {
  controller = SequenceMotionController<String, Offset>(
    motion: motion,
    vsync: tester,
    converter: converter,
    initialValue: Offset.zero,
  );

  final MotionController<Offset> motionController = controller;
  expect(motionController, same(controller));
});
```

This test does not compile against the pre-rewrite code (the two
`MotionController` classes are unrelated) — that is the point; it
machine-checks the restored hierarchy.

Also add, in a new `group('sequence playback', ...)` in the same file
(model the style on the semantics test — `Motion.linear(100ms)`,
`MotionConverter.single`, explicit pumps):

- `sequenceProgress` over `MotionSequence.steps([0, 1, 2], ...)` with
  `LoopMode.none`: 0 before `playSequence`; after `pump()` + `pump(1ms)` it
  is 0.5 (index 1 of 2); after two more 101 ms pumps the sequence completes
  and it returns 0 again (not playing).
- `playSequence(atPhase:)` starts mid-sequence: for phases `[0, 1, 2]` and
  `atPhase: 1`, the visited transition targets are `[2]` only (initial leg
  to 1 emits no transition), and the controller settles at value 2.

**Verify**:
`flutter test test/src/controllers/phase_sequence_controller_test.dart` →
all pass (all pre-existing tests unchanged);
`flutter test test/src/controllers/phase_sequence_controller_test.dart --plain-name "is assignable"`
→ 1 test passes.

### Step 4: Run the remaining sequence suites and apply the golden policy

Run
`flutter test test/src/widgets/sequence_motion_builder_test.dart test/src/widgets/sequence_motion_builder_golden_test.dart`.

Expectation: `sequence_motion_builder_test.dart` passes with ZERO changes
(the rewritten controller reproduces legacy event timing, so the builder —
which is unchanged apart from its import — behaves identically). If a test
fails, diagnose against the "Legacy timing model" section; editing that test
requires a per-test justification in your report, and more than two such
edits is a STOP.

Golden policy: golden changes are acceptable ONLY if (a) the numeric
semantics gate passes unchanged, and (b) your report lists each changed
golden with a one-line explanation of the visual delta. The one plausibly
legitimate delta with this design: at each phase boundary the new engine
samples the finished simulation at its exact done-time rather than at the
first tick past it — for non-snapping springs
(`state_sequence_1d_animation.png` uses `CupertinoMotion.bouncy(snapToEnd: false)`)
that is a sub-tolerance value difference that can shift antialiasing by a
pixel. Curve-based goldens (`loop_mode_*.png`, `spanning.png`) should be
byte-identical; if one of those changes, treat it as a timing bug in your
implementation, not golden churn. Unexplained golden churn is a STOP.

**Verify**: the two suites above pass; then `flutter test` (whole package)
→ all pass; `cd example && dart analyze` → exit 0.

### Step 5: MIGRATION.md + CHANGELOG

- MIGRATION.md deprecation-timeline section (3.0 checklist, lines ~221–240):
  note the legacy engine copy was removed in 2.0 itself; 3.0 removal now
  covers only the deprecated API symbols (`MotionSequence` types,
  `SequenceMotionController`, `SequenceMotionBuilder`) and their tests.
- CHANGELOG "Unreleased": REFACTOR entry — deprecated sequence APIs now run
  on the 2.0 track engine; the internal legacy controller copy is deleted.
  Document the observable deltas: (1) `playSequence`'s returned
  `TickerFuture` for LOOPING sequences now resolves at the end of the first
  cycle instead of never (matching `PhaseTrackController.playPhases` — do
  not `await` a looping sequence); (2) phase-boundary values are sampled at
  the simulation's exact completion time (sub-tolerance difference, visible
  only to non-snapping springs); (3) any golden deltas from Step 4.

**Verify**: `flutter test` → all pass; `dart analyze --fatal-infos` → exit 0.

## Test plan

- Primary gate: `legacy_sequence_semantics_test.dart` unchanged and green.
- New subtype test (Step 3): `is assignable to the exported MotionController`
  — cannot compile before the rewrite, must pass after; it is the machine
  check for the restored type hierarchy.
- New behavior tests (Step 3): `sequenceProgress` values at pinned ticks;
  `playSequence(atPhase:)` mid-sequence start. Model structure and pump
  cadence on `legacy_sequence_semantics_test.dart`.
- `phase_sequence_controller_test.dart` (existing tests) and
  `sequence_motion_builder_test.dart`: pass unchanged; each deviation
  individually justified, >2 deviations = STOP.
- Golden policy: byte-identical expected for curve-based goldens; minimal,
  explained changes only for the non-snapping-spring golden.
- Full suite green.

## Done criteria

- [ ] `packages/motor/lib/src/controllers/legacy/` no longer exists
- [ ] `SequenceMotionController` IS-A exported `MotionController`:
      `flutter test test/src/controllers/phase_sequence_controller_test.dart --plain-name "is assignable"`
      → 1 test passes (this test cannot compile against the pre-rewrite code)
- [ ] `legacy_sequence_semantics_test.dart` passes with zero diff
- [ ] `git diff --stat -- packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/controllers/_track_slot.dart packages/motor/lib/src/simulations` → empty (engine untouched)
- [ ] `SequenceMotionController` and `SequenceMotionBuilder` still carry their
      exact `@Deprecated` annotations and messages
- [ ] `flutter test` exits 0; `dart analyze --fatal-infos` exits 0; example analyzes
- [ ] Every changed golden is listed and explained in the report
- [ ] MIGRATION.md 3.0 checklist updated
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The semantics gate (`legacy_sequence_semantics_test.dart`) fails and the
  only fix is editing its expectations — report the exact numeric divergence
  and which mechanism anchor it falsifies.
- Reproducing the pinned behavior appears to require modifying
  `track_controller.dart`, `_track_slot.dart`, or `step_playback.dart` —
  the design is premised on zero engine changes.
- A `Step.sync` barrier in a single-track chain is NOT released in the same
  tick it is reached (observable as every `PhaseTransitioning` in the gate
  arriving one pump late) — this falsifies mechanism anchor 2.
- Overriding `_handleInnerStatus` from the part file does not intercept the
  base class's listener (observable as `AnimationStatus.completed`
  notifications firing between loop cycles) — this falsifies mechanism
  anchor 4.
- Plan 005 (sync-barrier stop policy) has landed and the gate's timing
  shifted — reconcile with its change before continuing (see Maintenance
  notes).
- More than two existing tests in `phase_sequence_controller_test.dart` /
  `sequence_motion_builder_test.dart` need edits.
- A golden changes and you cannot explain the visual delta in one sentence,
  or a curve-based golden changes at all.
- The Step 3 subtype test cannot be made to compile — i.e.
  `SequenceMotionController` could not be rebased onto the exported
  `MotionController` without changing the public API. Restoring that
  hierarchy is this plan's primary goal; do not ship a rewrite that keeps
  the classes unrelated.

## Maintenance notes

- After this lands, 3.0's deletion checklist shrinks to: remove the
  deprecated API symbols and their tests; no engine code dies with them.
- **What a reviewer should scrutinize**: the tick-anchoring claims — run the
  gate with `--plain-name` per test and check the transition-event ordering;
  and the `_handleInnerStatus` interception (no status flapping between loop
  cycles: add a temporary status listener and assert only one `forward` and
  one terminal status for a `none` sequence).
- **Interactions with pending plans** (TODO in `plans/README.md` as of
  `78aff46`):
  - Plan 005 (sync-barrier stop policy) edits `track_controller.dart`'s
    release logic. This plan makes the deprecated sequence stack a CONSUMER
    of single-track sync barriers, so 005 gains a new stakeholder: its
    executor must re-run `legacy_sequence_semantics_test.dart` after
    changing release policy. Single-track chains (participants = one track)
    should be unaffected by a stopped-participant policy, but verify.
  - Plan 009 Fix A rewrites the `LoopMode.loop` return-motion fallback
    (`_firstStepMotions`) in `step_playback.dart`. The earlier draft of this
    plan edited that same region; this revision does NOT (looping is handled
    above the engine, with explicit per-leg motions), so the
    "015 before 009" ordering note in `plans/README.md` is stale — 009 no
    longer conflicts with 015. Flag this to the index maintainer in the PR.
  - Plan 011 (run last) renames `Step` → `TrackStep` and cites
    `legacy_motion_controller.dart:1156` in its survey — after this plan
    lands, that legacy reference disappears (though the new
    `sequence_motion_controller.dart` adds new `Step.to`/`Step.sync` call
    sites for 011 to rename); plan 011's executor should treat its survey
    counts as stale.
- Deliberately deferred: `SequenceMotionBuilder` still creates a
  `SequenceMotionController` internally; no builder-level rewrite onto
  `PhaseTrackBuilder` is attempted — the whole stack dies in 3.0.
- The orphaned prototype line that inspired the earlier draft of this plan
  is not used by this revision and can be abandoned independently.
