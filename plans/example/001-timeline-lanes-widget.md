# Plan 001: Build the TimelineLanes visualization widget

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example packages/motor/lib/src/track_timeline.dart packages/motor/lib/src/track_step.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (novel visualization; no existing pattern to copy)
- **Depends on**: none
- **Category**: dx / docs (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

The example app teaches nothing about motor's core orchestration model —
`Track`, steps, `TrackTimeline`, sync barriers. The redesign (plans 002–005)
introduces a "Tracks" teaching arc, and its centerpiece is a reusable widget
that renders a timeline the way every motion tool renders one: horizontal
lanes (one per track) with step segments and a moving playhead. This is the
shared mental model of After Effects, Rive, Principle, and Framer — it
translates motor's code model into the picture designers already have in
their heads. Two later plans dock this widget (Arc 2's "Timelines & steps"
page in plan 003; the flagship in plan 004), so it ships first as a
standalone, page-independent widget.

## Current state

- `packages/motor/example/lib/widgets/` — shared example widgets live here
  (`example_scaffold.dart`, `motion_track.dart`, `spring_visualizer.dart`,
  `value_recording_notifier.dart`, `labeled_slider.dart`). The new widget
  goes in this directory.
- There is no existing timeline visualization anywhere in the repo.
- The data you will visualize:

```15:27:packages/motor/lib/src/track_timeline.dart
class TrackTimeline with EquatableMixin {
  /// Creates a timeline from track [animations].
  TrackTimeline(
    this.animations, {
    this.loop = LoopMode.none,
  });

  /// Track animations in this timeline.
  final List<TrackAnimation> animations;

  /// How this timeline should loop.
  final LoopMode loop;
```

- `TrackAnimation` (in `packages/motor/lib/src/track.dart`, class at ~line
  194) has `track`, a list of `TrackStep`s, and optional `from` /
  `withVelocity`.
- `TrackStep` (in `packages/motor/lib/src/track_step.dart`) is a sealed class.
  The step kinds you must render: `.to(value, motion:)` (motion step to a
  target), `.at(duration, value, motion:)` (scheduled arrival at an absolute
  time), `.hold(duration)` (wait), `.sync(token:)` (barrier: wait until every
  track with the same token reaches its own `.sync`), `.free(motion:)`
  (self-directed physics, no target). Read the file before modeling — do not
  guess field names.
- Duration facts for layout: `Motion.duration` is a nullable getter
  (`packages/motor/lib/src/motion.dart:160`); `CurvedMotion`/`LinearMotion`
  return their fixed duration, and `SpringMotion` returns its *perceptual*
  design duration (`motion.dart:431`) — springs do not actually end at that
  time, which is exactly why springs get a feathered tail (see step 2). If
  `duration` is null (e.g. `FrictionMotion` in a `.free` step), fall back to
  a fixed placeholder width and render it with the "free" treatment.
- Design system: pages use `ExampleTheme.of(context)` from
  `packages/example_design/` — fields like `t.border`, `t.fog`,
  `t.textPrimary`, `t.textTertiary`, `ExampleTheme.spectrum` (gradient).
  Monospace captions use `fontFamily: 'JetBrains Mono'` with fallback
  `['monospace', 'Menlo']` — see `TakeawayText` in
  `packages/motor/example/lib/widgets/example_scaffold.dart:174-193` and
  match it.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Tests   | `cd packages/motor/example && flutter test` | all pass |

## Scope

**In scope** (the only files you should create/modify):
- `packages/motor/example/lib/widgets/timeline_lanes.dart` (create)
- `packages/motor/example/test/timeline_lanes_test.dart` (create)

**Out of scope** (do NOT touch):
- Anything under `packages/motor/lib/` — this widget consumes the public API
  only. If the public API is insufficient, that is a STOP condition, not a
  license to add exports.
- Existing pages and `main.dart` — no page uses this widget yet; plans 003
  and 004 wire it in.
- `packages/example_design/` — read its theme, do not extend it.

## Git workflow

- Isolated worktree; branch `agent/example-001-timeline-lanes`.
- Conventional commits, e.g. `feat(motor_example): add TimelineLanes widget`.
- Do NOT push or open a PR.

## Design requirements (the spec)

The widget's public API — keep exactly this shape unless a STOP condition
forces otherwise:

```dart
/// Renders a [TrackTimeline] as horizontal lanes with a moving playhead —
/// the After Effects mental model, honest about springs.
class TimelineLanes extends StatefulWidget {
  const TimelineLanes({
    required this.timeline,
    required this.playhead,          // ValueListenable<Duration> — pages own the clock
    this.laneLabels = const {},      // Map<Track, String>, e.g. {x: 'position'}
    this.laneColors = const {},      // Map<Track, Color>; fallback: theme text colors
    this.height = 140,
    super.key,
  });
}
```

Rendering rules (each is load-bearing; they come from a motion-design
review):

1. **One lane per `TrackAnimation`**, max 5 (assert in debug if more — Arc 2
   pages use 2–4). Lane = label on the left (11px JetBrains Mono, lane
   color), segment strip on the right.
2. **Segment shapes are honest about the motion model**:
   - Fixed-duration motions (`motion.duration != null` AND the motion is not
     a spring): sharp-edged rounded rect block spanning the step's time span.
   - Springs: block whose right edge **feathers out** (fade the fill to
     transparent over the last ~25% of the design duration) — a spring has no
     hard end time and the visual must not lie about that.
   - `.hold`: no block — a thin baseline gap (the lane's 1px baseline shows
     through).
   - `.sync(token:)`: a **vertical rule** at the barrier's resolved time,
     spanning every lane that carries the same token, with the token name
     (e.g. `#ready`) captioned once at the top of the rule. Lanes that arrive
     early show their baseline "waiting" up to the rule.
   - `.free`: a block with a dashed/It's-alive treatment (e.g. dashed border,
     no fill) using the placeholder width.
3. **Playhead**: a 2px vertical line (theme `textPrimary`) driven by the
   `playhead` listenable, drawn over all lanes. When `timeline.loop` is
   `LoopMode.loop` the playhead visibly jumps back to 0 at the end of the
   total span; for `LoopMode.pingPong` it reverses direction. The *widget*
   does not own time — it renders whatever `playhead` reports; the page's
   clock produces the jump/reverse. Document this contract in the dartdoc.
4. **Interruption = plan-rewriting**: when `didUpdateWidget` sees a *different*
   `timeline` (value inequality — `TrackTimeline` is `Equatable`), animate
   the old segments out (slide down + fade, ~200ms) and the new segments in.
   This is the single most important behavior: motor's differentiator vs. the
   AE mental model is that the timeline is a cheap, disposable plan. Use a
   plain motor `SingleMotionController` or an implicit builder from motor for
   this transition — this file is example code; it should itself read as
   idiomatic motor usage.
5. **Time→x mapping**: linear, shared across all lanes. Total span = the max
   over lanes of the lane's resolved end time; resolve step times by walking
   steps in order (`.at` uses its absolute duration from the step's own
   definition — read `track_step.dart` for whether `.at`'s duration is
   absolute-from-start or relative; render what the engine does, and cite the
   line in a code comment). Sync barriers align: the barrier time is the max
   arrival time across its participating lanes; later steps in every
   participating lane start at the barrier time.
6. Layout the model first, then paint: derive a
   `List<_LaneLayout>` (pure function of `TrackTimeline` → segment geometry)
   in a separately testable top-level or static function
   (`layoutTimeline(TrackTimeline, {required double pixelsPerMs})` or
   similar), and keep the painter dumb. The pure function is what the unit
   tests target.

## Steps

### Step 1: Read the step model, write the layout function

Read `packages/motor/lib/src/track_step.dart` fully (it's short) and
`packages/motor/lib/src/track.dart:178-230`. Then implement the pure layout
function producing per-lane segment lists with resolved start/end times and
segment kinds (block / feathered / gap / barrier / free). Handle `.at`
according to what the engine actually does (cite the line), `.sync` with the
max-arrival rule above, and null-duration motions with the placeholder.

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0.

### Step 2: Implement the widget and painter

`TimelineLanes` as specced, painting from the layout model. Feathered spring
tails, barrier rules with token captions, baseline gaps for holds, playhead
from the listenable, and the timeline-swap transition (rule 4).

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 3: Unit-test the layout function

In `packages/motor/example/test/timeline_lanes_test.dart`, model the
structure after the existing `packages/motor/example/test/pages_smoke_test.dart`
(plain `flutter_test`, no golden files). Cover:
- two tracks, `.to`-only, different motion durations → total span is the max.
- a `.hold` produces a gap segment with the right time span.
- a `.sync(token:)` on two tracks with unequal arrival times → both lanes'
  post-barrier segments start at the max arrival time; barrier time equals it.
- a spring step is marked feathered; a `CurvedMotion` step is not.
- a `.free` step (e.g. `FrictionMotion`) gets the placeholder treatment and
  does not crash the span computation.

Plus one widget smoke test: pump `TimelineLanes` with a 3-lane timeline and a
`ValueNotifier<Duration>`, advance the notifier, `expect(tester.takeException(), isNull)`.

**Verify**: `cd packages/motor/example && flutter test test/timeline_lanes_test.dart` → all pass.

### Step 4: Full gate

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0
AND `flutter test` → all pass (existing smoke tests unaffected).

## Done criteria

- [ ] `packages/motor/example/lib/widgets/timeline_lanes.dart` exists with the
      specced public API and all six rendering rules implemented.
- [ ] Layout is a pure, separately tested function; ≥6 unit tests pass.
- [ ] `dart analyze --fatal-infos` exits 0 in `packages/motor/example`.
- [ ] `flutter test` exits 0 in `packages/motor/example`.
- [ ] No files outside the in-scope list modified (`git status`).
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Resolving step timing requires engine internals that aren't exported from
  `package:motor/motor.dart` (e.g. you cannot determine `.at` semantics or
  barrier arrival times from public API + the step definitions alone).
- `TrackStep`'s sealed subclasses don't expose the fields (duration, motion,
  token) needed for layout — do NOT add getters to the motor package.
- The timeline-swap transition (rule 4) can't be expressed with public motor
  API in reasonable code.
- Analyzer failures persist that predate your change (baseline is clean at
  `93af2da` — if it isn't in your worktree, check the `pubspec.lock` note in
  `plans/example/README.md` first).

## Maintenance notes

- Plans 003 and 004 consume this widget; if you change the public API shape,
  those plans' excerpts drift — note it in your report.
- A draggable playhead (scrubbing via `TrackController.scrubTo`) is
  explicitly deferred; the `playhead` listenable contract was chosen so
  scrubbing can be added without reshaping the API.
- Reviewer should scrutinize: the honesty rules (feathered springs, barrier
  alignment) — a reviewer comparing the lanes against a running timeline
  should see them agree.
