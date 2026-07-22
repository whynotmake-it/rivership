# Plan 003: Build Arc 2 — the tracks teaching arc (4 new pages)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example`
> Plan 001 (TimelineLanes) and plan 002 (Arc 1) are EXPECTED to have landed —
> those diffs are fine. For anything else that changed, compare the "Current
> state" excerpts against live code; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/example/001 (TimelineLanes must exist)
- **Category**: dx / docs (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

This is the missing middle of the whole example app. An API-coverage audit
found that motor's stated moat — `Track`, step choreography, `TrackTimeline`,
sync barriers, phases — is *used* by the flagship demos (payment_success,
card_stack) but *taught* by nothing: no page explains what a track is, why
track identity matters, what `.at`/`.hold`/`.sync` do, that timelines are
reusable values, or how phases differ from barriers. Several concepts have
zero coverage anywhere: `pingPong` on the supported API (the only demo is
deprecated `SequenceMotionBuilder` code in loaders.dart behind an
`// ignore:`), `TrackBuilder.timeline`, `PhaseTrackBuilder`'s `playing:`,
`.free()` steps, and `scrubTo`. These four pages close every one of those
gaps, ordered so each page adds exactly one idea, with the code itself as
the explanation. The maintainer explicitly asked that a looping showcase
survive the redesign — page 6 is it.

## Current state

- Teaching material that MIGRATES here (source pages die in plan 005):
  - `packages/motor/example/lib/pages/loaders.dart:53-106` — the staggered
    dot row (`_DotRow`): one `Track` per dot built in a list, staggered with
    leading/trailing `.hold`s, played via `TrackBuilder(loop: LoopMode.loop)`.
    This artifact is GOOD; it moves to page 6.
  - `loaders.dart:109-139` — the seamless spinner (`_Spinner`), including the
    uncommented trick at line 124: `.to(0.0, motion: .linear(.zero))` resets
    instantly so first/last frames render identically (seamless requirement).
    Moves to page 6, WITH the explanation the original never had.
  - `loaders.dart:169-240` — the `LoopMode` comparison bars using deprecated
    `SequenceMotionBuilder` (line 188, behind `// ignore: deprecated_member_use`).
    This demo is RETIRED; loop modes are taught on the supported API instead.
- The widget you will dock: `packages/motor/example/lib/widgets/timeline_lanes.dart`
  (created by plan 001) — API:
  `TimelineLanes(timeline:, playhead: ValueListenable<Duration>, laneLabels:, laneColors:)`.
  Read its dartdoc before wiring; the page owns the playhead clock.
- Key API facts (verified at `93af2da`):
  - `TrackTimeline(animations, {loop = LoopMode.none})` — value-equatable
    (`packages/motor/lib/src/track_timeline.dart:15-27`); its dartdoc:
    "building an equal timeline on rebuild will not restart playback in
    `TrackBuilder`".
  - `TrackBuilder({required animations, loop})` and
    `TrackBuilder.timeline(timeline)` — `packages/motor/lib/src/widgets/track_builder.dart:22-52`.
  - `TrackPhaseTimeline({...}, {phaseLoop = LoopMode.none, from = const [], withVelocity = const []})`
    — `packages/motor/lib/src/track_phase_timeline.dart:28-32`. The README's
    key selling point, which NO example currently states: phase boundaries
    are automatic sync barriers — every track settles before the next phase
    begins.
  - `PhaseTrackBuilder({currentPhase, playing = false, ..., velocityTracking, onTransition})`
    — `packages/motor/lib/src/widgets/phase_track_builder.dart:55-65`.
    NOTE: `phaseLoop` is a `TrackPhaseTimeline` parameter, NOT a
    `PhaseTrackBuilder` parameter.
  - `PhaseTrackController.playPhases(...)` / `.goToPhase(phase)` —
    `packages/motor/lib/src/controllers/phase_track_controller.dart:74,109`.
  - Transition events: `PhaseTransitioning` / `PhaseSettled`
    (`packages/motor/lib/src/phase_transition.dart`) — pattern-matched in
    `card_stack.dart:130`.
  - `TrackStep.free({motion})` — `packages/motor/lib/src/track_step.dart:27`.
  - `TrackController.scrubTo(Duration t)` / `.resume()` —
    `packages/motor/lib/src/controllers/track_controller.dart:274,282`.
    IMPORTANT semantics: `scrubTo` operates on the currently *active* tracks;
    after `stop(canceled: true)` it is a no-op. Scrub while playback is live.
- Conventions: same as plan 002 (ExamplePage scaffold, TakeawayText,
  dot-shorthand steps, routes via `_route`, smoke-test entries). The
  commenting standard to match: `toggle.dart:117-134` and
  `thermostat.dart:20-26` (concept comments above the declaration they
  explain).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Tests   | `cd packages/motor/example && flutter test` | all pass |

## Scope

**In scope**:
- `packages/motor/example/lib/pages/meet_tracks.dart` (create)
- `packages/motor/example/lib/pages/timelines_and_steps.dart` (create)
- `packages/motor/example/lib/pages/sync_barriers.dart` (create)
- `packages/motor/example/lib/pages/phases.dart` (create)
- `packages/motor/example/lib/main.dart` (APPEND routes only)
- `packages/motor/example/test/pages_smoke_test.dart` (append entries)

**Out of scope**:
- Deleting `loaders.dart` or any old page (plan 005).
- `packages/motor/lib/` and `packages/example_design/`.
- The TimelineLanes widget internals — consume it; if it's insufficient, STOP.

## Git workflow

- Isolated worktree; branch `agent/example-003-arc2`.
- Conventional commits per page: `feat(motor_example): add meet-tracks page`.
- Do NOT push or open a PR.

## Design spec (per page)

Pedagogical rule for all four pages: the motor calls ARE the page. Keep
scaffolding minimal (no custom painters unless specified); if a page's
motor-API-lines to total-lines ratio drops below roughly 1:4, cut decoration,
not concepts. Every page states its one lesson in `description:` and closes
with a `TakeawayText`.

### Page 5: "Meet Tracks" (`meet_tracks.dart`, route `Meet Tracks`)

- One artifact: a small badge/card in a `Stage`. Three top-level-visible
  tracks declared as fields WITH a comment stating the identity rule (a
  `Track` is an identity key — declare it once and reuse the instance;
  equal-looking tracks created per-build are different tracks):
  `_pos` (`.offset`), `_scale` (`.single`), `_tint` (`.colorRgb`) — each
  with a per-track default `motion:` that the calls then actually rely on
  (do NOT override the default in every call — that was a flaw of the old
  two_dimensions page).
- Two target states (e.g. "docked" bottom-left small gray / "featured"
  center large accent-tinted). Tapping the stage toggles:
  `_controller.animate([_pos.to(a), _scale.to(b), _tint.to(c)])` — one call,
  three properties, one clock.
- THE POINT (must be interactive): re-tap MID-FLIGHT. All three tracks
  redirect coherently, each carrying its own velocity. This answers "why one
  controller instead of three implicit animations" — unified interruption.
  Put that sentence in the takeaway.
- Show live per-track readouts (three small monospace rows:
  `value(_scale)` etc.) so the reader connects reader-API to screen.

### Page 6: "Timelines & Steps" (`timelines_and_steps.dart`, route `Timelines & Steps`)

- Top: the migrated staggered dot row from `loaders.dart:53-106` (5–6 dots,
  not 10, to keep lanes readable) — declared as ONE
  `final _timeline = TrackTimeline([...], loop: _loop)` built from `.hold` +
  `.to` steps, played with `TrackBuilder.timeline(_timeline)` (this is the
  API's zero-coverage constructor — using it here is deliberate).
- A segmented control for `LoopMode`: `.loop`, `.pingPong`, `.seamless`.
  Selecting rebuilds the timeline with the new loop mode. For `.seamless`,
  switch the artifact to the migrated spinner (`loaders.dart:109-139`) OR
  adapt the dot row so first==last values — either way, include the comment
  the original lacked: seamless requires the first and last rendered frames
  to be identical; the `.to(x, motion: .linear(.zero))` step is an instant
  jump encoded as a step.
- Docked beneath: `TimelineLanes` bound to the same timeline, playhead driven
  by a page-owned `Ticker` (create in `initState` via
  `SingleTickerProviderStateMixin`, reset on loop-mode change; for
  `.pingPong` reverse the reported Duration on odd cycles so the playhead
  visually bounces — the lanes widget renders whatever the listenable says).
  Lane labels 'dot 1'…'dot n'. This is where LoopMode becomes VISIBLE: the
  playhead jumps home (loop) vs. reverses (pingPong).
- This page satisfies the maintainer's "keep something to show looping"
  requirement — the dot row and spinner remain product-quality loaders.
- Takeaway: a timeline is a value — build it once, play it anywhere, loop it;
  steps read in order: hold, go, hold.

### Page 7: "Sync Barriers" (`sync_barriers.dart`, route `Sync Barriers`)

- Minimal two-track scenario where the barrier's effect is unmistakable:
  e.g. a "runner" dot with a short fast path and a "walker" dot with a long
  slow path, then both pop/flash together after the barrier.
- A toggle "sync barrier" that switches between two predeclared timelines:
  without — `[.to(end)]` / `[.to(end)]` then each pops on its own arrival;
  with — `[.to(end), .sync(token: #meet), .to(pop)]` on both — the fast
  track visibly WAITS at the barrier for the slow one, then both pop
  together. The diff between the two timelines should be exactly the
  `.sync(token: #meet)` lines; keep both literally in the source so a reader
  sees the delta.
- Dock `TimelineLanes` beneath; the barrier renders as the vertical rule
  (plan 001 rule 2) — the fast lane's baseline "waiting" segment is the
  visual explanation.
- End the page with a "see it composed →" pointer to Payment Success (text +
  `context.navigateTo(NamedRoute(PaymentSuccessPage.routeName))` button) —
  payment_success.dart is the payoff and stays unchanged.
- Takeaway: `.sync(token:)` makes independent clocks meet; Payment Success
  is eight tracks converging through one barrier.

### Page 8: "Phases" (`phases.dart`, route `Phases`)

- `enum _Panel { compact, expanded }` (or similar two/three-phase state).
  A card artifact with 2–3 tracks per phase, driven by
  `PhaseTrackBuilder(currentPhase: _phase, timeline: TrackPhaseTimeline({...}, from: [...]), ...)`.
  HOIST the timeline to a field with a comment on WHY that's safe vs. inline
  (value equality — quote the `TrackTimeline` dartdoc line). Tapping toggles
  the phase.
- A "play automatically" switch that flips to `playing: true` with a
  timeline whose `phaseLoop: LoopMode.loop`, showing the same phases
  auto-advancing (each phase boundary is an automatic sync barrier — STATE
  THIS in a comment; it's the README's key selling point and currently
  appears in no example).
- Wire `onTransition:` and render the last event as a monospace status line,
  pattern-matching BOTH `PhaseTransitioning` and `PhaseSettled` (cf. the
  match in `card_stack.dart:130`; `PhaseSettled` currently has zero
  coverage).
- A second, small section "let go of the wheel": one fling-able dot on the
  same page demonstrating `.free`: on fling, run
  `_controller.animate([_pos([.free(motion: FrictionMotion(...)), .to(home)])])`
  — friction coasts from live velocity, then a spring brings it home. Plus a
  scrub slider: while a phase playback is running, dragging the slider calls
  `controller.scrubTo(t)` and releasing calls `controller.resume()` — with a
  comment noting scrubbing acts on live playback (after a canceled stop it's
  a no-op by design).
- End with "see it composed →" pointer to Card Stack (kept page, the
  gesture-driven phase payoff).
- Takeaway: barriers synchronize within a plan; phases name whole states and
  choose between plans.

## Steps

### Step 1: Page 5 (Meet Tracks)

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0;
smoke entry added; `flutter test test/pages_smoke_test.dart` → passes.

### Step 2: Page 6 (Timelines & Steps)

Include a behavioral test: pump the page, let it run 2 loop cycles (~pump 240
frames of 32ms), expect no exception; switch the segmented control to
pingPong, pump another cycle, expect no exception.

**Verify**: `flutter test test/pages_smoke_test.dart` → passes.

### Step 3: Page 7 (Sync Barriers)

Behavioral test: with the barrier ON, pump until the fast track has reached
its end value while the slow one hasn't (assert via the page's exposed state
or a keyed widget's position), and assert the fast track's post-barrier
"pop" has NOT started; pump to completion, assert both popped. If asserting
mid-flight values proves too brittle from widget level, downgrade to
no-exception + final-state assertions and note the downgrade.

**Verify**: `flutter test test/pages_smoke_test.dart` → passes.

### Step 4: Page 8 (Phases)

Behavioral test: toggle the phase, pump to settle, expect the status line
shows a `PhaseSettled`; enable auto-play, pump several phase cycles, expect
no exception.

**Verify**: `flutter test test/pages_smoke_test.dart` → passes.

### Step 5: Register routes; full gate

Append four `_route(...)` entries in `main.dart` (append-only).

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0
AND `flutter test` → all pass.

## Test plan

Four smoke entries + three behavioral tests as described in steps, modeled on
`pages_smoke_test.dart`'s existing style (32ms pump loops, `takeException`).

## Done criteria

- [ ] Four pages exist; each dockable concept from the coverage gaps is
      present — grep-checkable:
      `grep -l "TrackBuilder.timeline" packages/motor/example/lib/pages/` → timelines_and_steps.dart;
      `grep -l "\.sync(token:" packages/motor/example/lib/pages/sync_barriers.dart` → match;
      `grep -l "PhaseSettled" packages/motor/example/lib/pages/phases.dart` → match;
      `grep -l "\.free(" packages/motor/example/lib/pages/phases.dart` → match;
      `grep -l "scrubTo" packages/motor/example/lib/pages/phases.dart` → match;
      `grep -rl "LoopMode.pingPong" packages/motor/example/lib/pages/timelines_and_steps.dart` → match.
- [ ] No new page imports deprecated API
      (`grep -rn "SequenceMotion\|MotionSequence\|toSteps" packages/motor/example/lib/pages/meet_tracks.dart packages/motor/example/lib/pages/timelines_and_steps.dart packages/motor/example/lib/pages/sync_barriers.dart packages/motor/example/lib/pages/phases.dart` → no matches).
- [ ] `TimelineLanes` is docked on pages 6 and 7.
- [ ] `dart analyze --fatal-infos` exits 0; `flutter test` exits 0.
- [ ] `main.dart` diff is append-only for routes.
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Plan 001's `TimelineLanes` hasn't landed, or its API differs from the
  excerpt above in a way that breaks the docking.
- `scrubTo`/`resume` behave differently than described (scrub during live
  playback doesn't visibly seek) — do not work around with engine changes.
- The pingPong playhead contract (page owns reversal) turns out to be
  unimplementable against the landed lanes widget.
- You need any change under `packages/motor/lib/`.

## Maintenance notes

- Plan 005 wires these pages into the restructured home under a "TRACKS"
  section between Arc 1 and the flagships, and adds "next:" navigation.
- Page 6 is now the app's only looping showcase (loaders.dart dies in 005) —
  if loop-mode behavior changes in the engine (e.g. plan 017 in the parent
  plan set, zero-duration pingPong), this page is the visible canary.
- Reviewer: check the ratio rule — these pages must read as motor code with
  a thin UI around it, not the reverse.
