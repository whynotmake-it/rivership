# Plan 007: Rebuild TimelineLanes as a self-updating TrackController inspector with scrubbing

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 4d16091..HEAD -- packages/motor/example packages/motor/lib`
> Parent plans 018 (inspection API) and 019 (pause/scrub/resume) MUST have
> landed — verify `packages/motor/lib/inspection.dart` exists and
> `TrackController.pause` exists before starting; if either is missing, STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/018 (inspection API), plans/019 (pause/scrub/resume)
- **Category**: dx / direction (debug tooling)
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

The current `TimelineLanes` widget is fed a `TrackTimeline` *value* and a
page-owned playhead ticker — dead reckoning. Every consuming page compensates
with hacks: the boarding pass hand-maintains a mirror of what the controller
is playing and detects barrier release by watching a track value leave zero;
the dots page derives its loop period through a `@visibleForTesting` layout
call and re-zeroes two clocks by convention; springs are drawn at design
duration while the engine settles on tolerance. The maintainer's direction:
the visualization must attach to ANY `TrackController`, update itself, be
accurate, and support scrubbing — because it will become a debug tool for
package users. Parent plans 018/019 added the engine capabilities (playback
snapshots + a working pause→scrub→resume cycle); this plan rebuilds the
widget on them and deletes every page-side hack.

## Current state

Verified at `4d16091`. Read all of these before writing code:

- `packages/motor/example/lib/widgets/timeline_lanes.dart` (787 lines) — the
  existing widget: public API `TimelineLanes(timeline:, playhead:
  ValueListenable<Duration>, laneLabels:, laneColors:, height:)`; a pure
  `layoutTimeline(...)` function (`@visibleForTesting`, line ~247) producing
  `TimelineLayout`/`TimelineLaneLayout`/`TimelineSegmentLayout` with segment
  kinds block/feathered/gap/barrier/free; a painter with feathered spring
  tails, barrier rules with token captions, a 200ms rewrite transition when
  the timeline value changes. The *visual language is good and stays* — the
  data source is what changes.
- Consumers and their hacks (all to be deleted by this plan):
  - `packages/motor/example/lib/pages/boarding_pass.dart` — `_lanesTimeline`
    hand-swapped on every interruption (search `_setLanesTimeline`); the
    `_lanePlayhead` mapping that holds the playhead at the drawn barrier
    until "release is observable as the first letter leaving zero"; the
    synthetic letters lane; a page ticker (`_playheadTicker`).
  - `packages/motor/example/lib/pages/timelines_and_steps.dart` — page
    ticker + period derived via `layoutTimeline` under
    `// ignore: invalid_use_of_visible_for_testing_member`; `restartTrigger`
    bumps to re-zero two clocks on the same frame; zero-duration anchor
    steps exist to control the loop period (these stay — they are honest
    timeline design — but the clock plumbing goes).
  - `packages/motor/example/lib/pages/sync_barriers.dart` — page ticker with
    a hardcoded 1100ms clamp.
- Engine surfaces you now have (from plans 018/019 — read their landed code,
  not just this summary):
  - `package:motor/inspection.dart`: `PlaybackSnapshot` /
    `TrackPlayback` (per-track: actual running `steps` incl. synthetic
    loop-return flag, `currentStepIndex`, `direction`, `cycle`,
    `isWaitingForSync`/`syncToken`, `startOffset`, `playhead`, actual
    `stepStarts` — where the entry after a sync step IS the barrier release
    moment — and actual `stepDurations`, the settle ledger), plus
    `controller.inspectPlayback()` and `controller.playbackRevision`.
  - `TrackController.pause()` (silent), `resume()` continuing from position,
    `scrubTo(Duration)` with post-scrub barrier re-release.
  - `TrackController` is a `Listenable` notifying every tick — the widget's
    update signal; `lastElapsedDuration` is the ticker clock.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0 |
| Tests   | `cd packages/motor/example && flutter test` | all pass |
| Motor untouched check | `git diff --name-only 4d16091..HEAD -- packages/motor/lib` | only plans-018/019 files |

## Scope

**In scope**:
- `packages/motor/example/lib/widgets/timeline_inspector.dart` (create — the
  new widget; name it `TimelineInspector`)
- `packages/motor/example/lib/widgets/timeline_lanes.dart` (delete at the
  end, after consumers migrate)
- The three consumer pages (boarding_pass, timelines_and_steps,
  sync_barriers) — migrate + delete hacks
- `packages/motor/example/test/timeline_inspector_test.dart` (create;
  port/replace `timeline_lanes_test.dart`, which is deleted with the widget)
- `packages/motor/example/test/pages_smoke_test.dart` (adjust behavioral
  tests that referenced page tickers/keys you remove)

**Out of scope**:
- `packages/motor/lib/` — the engine API is fixed by plans 018/019. Gaps →
  STOP and report; do not patch the engine from this plan.
- Moving the widget into the motor package (future decision; design the
  widget so its only motor dependency is the public API + inspection.dart,
  making the future move mechanical).
- The Phases page and other pages that don't dock lanes today.

## Design (the contract)

Public API:

```dart
/// Attaches to any [TrackController] and renders its live playback as
/// horizontal lanes with an accurate playhead. Scrub by dragging.
class TimelineInspector extends StatefulWidget {
  const TimelineInspector({
    required this.controller,
    this.laneLabels = const {},   // Map<Track, String>
    this.laneColors = const {},   // Map<Track, Color>
    this.laneGroups = const [],   // List<Set<Track>> — tracks rendered as one lane
    this.scrubbable = true,
    this.height = 140,
    super.key,
  });
}
```

Behavior rules (each load-bearing):

1. **Self-updating**: subscribe to `controller` (Listenable). On each
   notification read `controller.playbackRevision`; if changed, rebuild the
   layout model from `inspectPlayback()` and play the existing 200ms
   rewrite transition (port it — old segments slide down + fade). If
   unchanged, only the playhead/actual-timing overlays update.
2. **Accurate layout, honestly staged**: segments initially span design
   durations (`Motion.duration`, springs feathered — port the existing
   painter vocabulary). As playback records ground truth, REFINE: when
   `stepDurations[i]` lands, re-span segment i to the actual duration; when
   `stepStarts[i]` lands, pin its left edge. Barrier rules sit at recorded
   release moments once known (entry in `stepStarts` after the sync step),
   design-estimated before. Visually distinguish estimated vs recorded
   (e.g. estimated = current translucency, recorded = full opacity border)
   and document the encoding in the dartdoc.
3. **Playhead from the engine, per-lane truth**: the global playhead maps
   `TrackPlayback.playhead` (slot-local, already offset-corrected by the
   engine) — no page tickers anywhere. Multi-start plans (tracks started at
   different times via separate `animate` calls) render each lane on its own
   local axis with `startOffset` alignment — the snapshot gives you both;
   pick the controller-axis alignment and note it in a comment.
4. **Loop rendering**: use `cycle` + `direction` from the snapshot — the
   playhead position within the lane is the slot-local playhead minus the
   cycle base the snapshot exposes; pingPong reverse legs move the playhead
   backwards. No page participation.
5. **Scrubbing** (when `scrubbable`): drag anywhere on the strip →
   `controller.pause()` on drag start, `controller.scrubTo(x→Duration)` per
   update (throttle to one per frame), `controller.resume()` on release. A
   paused-state affordance (e.g. playhead handle grows + "paused" pill)
   must appear so the state is legible. Scrubbing while already stopped
   (no active tracks) is a documented no-op — show the handle disabled when
   `inspectPlayback().tracks` is empty or all done.
6. **Lane policy**: `laneGroups` replaces the boarding pass's synthetic
   letters lane — grouped tracks render as one lane whose segments are the
   union span (min start → max end per step region), labeled by the first
   track's label. Cap at 5 rendered lanes (assert), counting groups as one.
7. **Zero motor-internals imports**: only `package:motor/motor.dart` and
   `package:motor/inspection.dart`.

Consumer migrations:

- **boarding_pass.dart**: replace the docked `TimelineLanes` + `_playhead`
  ticker + `_lanesTimeline` mirror + `_lanePlayhead` + the synthetic lane
  with `TimelineInspector(controller: _controller, laneGroups: [{...letter
  tracks}], laneLabels: {...})`. The interrupt visuals (plan rewrite) now
  come free via `playbackRevision`. Keep gameplay behavior identical.
- **timelines_and_steps.dart**: drop `_playhead`, `_ticker`, `_duration`,
  the `// ignore:` — dock `TimelineInspector(controller: ...)`. NOTE: this
  page currently plays via `TrackBuilder.timeline`, which owns its internal
  controller — check whether `TrackBuilder` exposes it; if not, convert the
  page to an explicit `TrackController` + `play()` (the page teaches
  timelines; an explicit controller arguably reads better — keep the
  teaching comments). `restartTrigger` plumbing goes away; mode switches
  call `controller.play(newTimeline)` directly.
- **sync_barriers.dart**: same conversion; the barrier rule now sits at the
  RECORDED release time — delete the page ticker.

## Steps

### Step 1: Layout model on snapshots

Port `layoutTimeline`'s pure-function design to a new
`layoutPlayback(PlaybackSnapshot, {pixelsPerMs, laneGroups})` producing the
same segment-kind vocabulary plus `estimated|recorded` provenance per
segment. Unit-test it directly (see Test plan).

**Verify**: `dart analyze --fatal-infos` → exit 0;
`flutter test test/timeline_inspector_test.dart` (layout cases) → pass.

### Step 2: The widget

Rendering (port painter), self-update via revision, playhead, loop/pingPong,
paused affordance, scrub gesture wiring.

**Verify**: analyzer clean; widget smoke test passes.

### Step 3: Migrate the three pages, delete the old widget

One page per commit; run the page's behavioral tests after each. Delete
`timeline_lanes.dart` + `timeline_lanes_test.dart` last;
`grep -rn "TimelineLanes\|layoutTimeline" packages/motor/example` → no
matches.

**Verify**: full example suite passes after EACH page commit (no broken
intermediate states).

### Step 4: Full gates + hygiene

**Verify**: analyzer + tests in `packages/motor/example`; motor-untouched
check from the commands table; `grep -rn "invalid_use_of_visible_for_testing_member" packages/motor/example/lib` → no matches.

## Test plan

`timeline_inspector_test.dart`, modeled on the deleted
`timeline_lanes_test.dart` (pure layout unit tests + widget smoke):
1. Layout from a live controller: play a 2-track fixed-duration plan, pump
   half-way, layout from `inspectPlayback()` → spans match design durations;
   provenance `estimated` for un-reached steps, `recorded` for completed.
2. Spring refinement: after a spring step settles, its segment span equals
   the recorded actual (longer than design) — assert via the snapshot's
   `stepDurations` equality, not hardcoded ms.
3. Barrier accuracy: two tracks, one waits; after release, the barrier x
   equals the recorded release time (`stepStarts` after the sync step).
4. Rewrite: `animate` a new plan mid-flight → revision change detected,
   layout rebuilt from the NEW plan (widget test: pump, assert no
   exception + new lane count/labels).
5. Lane groups: 10 tracks grouped into 1 lane → renders 1 lane spanning
   min-start→max-end; 6 ungrouped lanes → assertion fires in debug.
6. Scrub cycle (widget test): drag on the strip → controller paused during
   drag (`isAnimating` false), values track the drag x, release resumes and
   playback completes; test tolerates the documented stopped-scrub no-op.
7. Ported page behavioral tests keep passing (boarding pass mid-entrance
   interrupt; dots mode switching; sync barrier hold).

## Done criteria

- [ ] `TimelineInspector` exists with the specced API; old widget + its test
      file deleted; zero references remain.
- [ ] All three pages migrated; their page tickers, `_lanePlayhead`,
      `_lanesTimeline` mirror, `restartTrigger` clock plumbing, and the
      `// ignore: invalid_use_of_visible_for_testing_member` are gone
      (grep-checked).
- [ ] ≥7 test cases above pass; full example suite passes.
- [ ] `packages/motor/lib` untouched by this plan's commits.
- [ ] `dart analyze --fatal-infos` exit 0.
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Plans 018/019 haven't landed, or the snapshot lacks a field this plan's
  design assumes (list the gap precisely — the snapshot contract may need a
  018 follow-up; do not reach into engine internals).
- `TrackBuilder` cannot reasonably expose or be replaced by an explicit
  controller on the dots page without hurting its teaching value — propose
  the alternative in your report instead of choosing.
- Scrubbing via pause/scrubTo/resume misbehaves in ways plan 019's tests
  don't cover (engine bug) — report with a minimal repro timeline.
- The refine-in-place rendering (rule 2) makes segments visibly jump in a
  way that reads as a glitch rather than information — propose smoothing
  (e.g. animate span changes) but flag it for maintainer review.

## Maintenance notes

- This widget is the prototype of a user-facing motor debug tool; its only
  motor imports are the public API + `inspection.dart` BY DESIGN — keep it
  that way so promotion into the motor package (or a `motor_inspector`
  package) is a file move.
- The estimated-vs-recorded visual encoding is the widget's honesty
  contract; future segment kinds must declare provenance.
- Reviewer: run the example and interrupt the boarding pass mid-entrance —
  the lanes should rewrite from the controller with zero page code; that
  demo IS the acceptance test for the whole three-plan arc.
