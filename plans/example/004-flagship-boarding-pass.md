# Plan 004: Build the flagship — boarding-pass entrance, choreographed AND interruptible

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example`
> Plans 001–003 are EXPECTED to have landed. For anything else that changed,
> compare the "Current state" excerpts against live code; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (feel-critical showcase; success is partly aesthetic)
- **Depends on**: plans/example/001 (TimelineLanes)
- **Category**: dx / docs (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

The app needs one example that states the whole thesis in a single artifact:
a rich, choreographed timeline that is ALSO live to the user's hand at every
instant. The old "Now Playing" page is the named anti-pattern — tracks that
merely coexist, tap-only, nothing causing anything ("random animations, not
driven by any gesture"). The design review's verdict: what separates
"special" from "random" is *causal staging plus live physics*. This page is a
boarding-pass ticket that flies in with real entrance velocity, whose
contents pour in as consequences of the landing on independent tracks — and
which can be swiped away mid-entrance with the entrance velocity and gesture
velocity merging. It also gives the per-letter variable-font idea from the
killed Title Slide page a correct home (steps instead of `Future.delayed`).

## Current state

- Idea sources (pages die in plan 005; you are mining, not importing):
  - `packages/motor/example/lib/pages/title_slide.dart:108-114` — the
    ANTI-pattern to fix: per-letter stagger via `Future.delayed` per widget.
    Your version staggers with `.hold` steps inside one timeline.
  - `title_slide.dart:144-157` — the good part: `FontVariation('wght', ...)`
    / `FontVariation('wdth', ...)` on the 'Archivo' variable font, weight
    derived from an animated 0..1 value.
  - `packages/motor/example/lib/pages/payment_success.dart:82-155` — the
    house style for a multi-track `TrackTimeline` with `.sync(token: #ready)`
    barriers played via `controller.play(timeline)`. Match its structure and
    commenting.
  - `packages/motor/example/lib/pages/card_stack.dart:99-137` — the
    gesture-exit idiom: `FrictionMotion(...).project(from:, velocity:,
    converter: .offset)` to decide dismissal, `withVelocity:` carrying
    gesture velocity into the fling-out.
  - Barcode-style path drawing: `payment_success.dart:369-402`
    (`_CheckPainter` — `path.computeMetrics()` + `extractPath(0, length * t)`)
    is the pattern for progressive drawing; a barcode is even simpler
    (vertical bars revealed left-to-right by a 0..1 clip).
- The lanes widget to dock: `packages/motor/example/lib/widgets/timeline_lanes.dart`
  (plan 001): `TimelineLanes(timeline:, playhead:, laneLabels:, laneColors:)`.
  Its interruption behavior (old segments slide out when the timeline value
  changes) is the star here.
- Conventions: `ExamplePage` scaffold, `Stage` for the demo area, theme via
  `ExampleTheme.of(context)`, monospace captions, routes via `_route`,
  smoke-test entries — all as in plans 002/003.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Tests   | `cd packages/motor/example && flutter test` | all pass |

## Scope

**In scope**:
- `packages/motor/example/lib/pages/boarding_pass.dart` (create)
- `packages/motor/example/lib/main.dart` (APPEND one route)
- `packages/motor/example/test/pages_smoke_test.dart` (append entry + one
  behavioral test)

**Out of scope**:
- `packages/motor/lib/`, `packages/example_design/`, the lanes widget
  internals, all existing pages.
- Asset files — the ticket is drawn with containers/text/painters; no images.

## Git workflow

- Isolated worktree; branch `agent/example-004-boarding-pass`.
- Conventional commit: `feat(motor_example): add boarding-pass flagship page`.
- Do NOT push or open a PR.

## Design spec

**The scene.** A `Stage` (~420 high) containing a boarding-pass ticket
(~280×150, rounded rect, hairline border, soft shadow — reuse the container
language of `payment_success.dart`'s `_Receipt`, lines 404-457). A "Book
flight" `NeutralButton` (and auto-play once on page load).

**The entrance choreography** — ONE `TrackTimeline` played on ONE
`TrackController` via `controller.play(timeline)`, total ≈1.4s. Tracks and
staging (causality is the design constraint — each element must read as a
consequence of the landing, not a coincidence):

1. `_ticketPos` (`.offset`) + `_ticketAngle` (`.single`): ticket flies in
   from below the stage edge with real velocity (seed with
   `withVelocity:` on the TrackAnimation or `from:` below the visible edge),
   over-rotating a few degrees (~4–6°) and settling flat on a spring.
2. `_ticketSettle` (`.single`, or reuse the angle track's settle): a
   `.sync(token: #landed)` barrier gates everything below — nothing pours in
   until the ticket has landed.
3. Origin/destination codes (e.g. 'CGN → LIS'): per-letter stagger via
   `.hold(Duration(milliseconds: i * 60))` then `.to(1, ...)` — one track
   per letter built in a list (the pattern from `loaders.dart:_DotRow`,
   applied to type). Letters animate opacity AND `FontVariation` weight from
   the track value (the good part of title_slide, done right — no
   `Future.delayed` anywhere on this page; enforce via done criteria).
4. `_barcode` (`.single`): draws left-to-right behind the `#landed` barrier —
   it cannot start before the ticket has settled.
5. `_gateChip` (`.single` scale): the "GATE B12" chip pops LAST with a small
   overshoot (`.bouncySpring(extraBounce: ...)`) after its own short
   `.hold`.

Track count: aim for 5 lanes in the docked widget by grouping the per-letter
tracks into one label ("letters") — the lanes widget asserts at >5 lanes
(plan 001 rule 1). If grouping proves awkward, dock the lanes bound to a
representative subset timeline and note it.

**The interruption (the thesis).** At EVERY instant — including mid-entrance:

- Swipe the ticket: drag maps to `controller.set([_ticketPos.value(...)])`
  (interrupting the running timeline for that track), release uses
  `FrictionMotion.project` to decide: past threshold → fly out with merged
  velocity (`withVelocity: d.velocity.pixelsPerSecond`), else → spring back
  AND resume the remaining choreography naturally (re-play the timeline; the
  landed elements keep their values via `from:`-less continuation — verify
  what reads best: simplest correct approach is re-playing the full timeline
  and letting velocity continuity smooth it; if that visibly restarts settled
  elements, gate the re-play to the un-finished tracks).
- Swipe-down or a "Re-book" button mid-anything: replays the entrance.
- The docked `TimelineLanes` (playhead from a page-owned ticker synced to
  `play()`) shows the remaining segments being DISCARDED when the user
  interrupts — plan 001's rule-4 transition. This is the money shot: the
  timeline is a cheap, disposable plan.

**What this page must NOT be**: tap-only, non-causal, or decorated with
motion that nothing explains. Every animated property maps to a named track;
the code should read top-to-bottom as: tracks → timeline → play → gesture
handlers.

## Steps

### Step 1: Static ticket + entrance timeline

Build the ticket layout and the full entrance choreography (tracks 1–5,
barrier-gated). Auto-play on `initState` and on "Book flight".

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0.

### Step 2: Gesture layer

Drag/swipe with `set`, projection-based dismiss vs. spring-back with merged
velocity, re-book replay.

**Verify**: analyzer clean.

### Step 3: Dock TimelineLanes

Page-owned ticker playhead; lane labels/colors; confirm the interrupt
visibly rewrites the lanes.

**Verify**: analyzer clean.

### Step 4: Route + tests

Append `_route(BoardingPassPage.routeName, 'boarding-pass', ...)` to
`main.dart`. Smoke entry plus one behavioral test: pump the page, let the
entrance run ~30 frames (mid-flight), `tester.fling` the ticket horizontally
past the dismiss threshold, pump to settle, expect no exception and the
ticket offscreen (or in its dismissed state); tap Re-book, pump to
completion, expect the gate chip visible. Model pumping style on
`pages_smoke_test.dart:66-85`.

**Verify**: `cd packages/motor/example && flutter test` → all pass;
`dart analyze --fatal-infos` → exit 0.

## Test plan

Covered in step 4: smoke entry + the mid-entrance-interrupt behavioral test
(this pins the thesis: interruptible during choreography).

## Done criteria

- [ ] `boarding_pass.dart` exists; one `TrackTimeline`, `.sync`-gated
      content, per-letter stagger via `.hold` steps.
- [ ] `grep -n "Future.delayed" packages/motor/example/lib/pages/boarding_pass.dart`
      → no matches.
- [ ] `grep -n "\.sync(token:" packages/motor/example/lib/pages/boarding_pass.dart`
      → at least one match.
- [ ] Mid-entrance swipe works (behavioral test passes).
- [ ] `TimelineLanes` docked and bound to the playing timeline.
- [ ] `dart analyze --fatal-infos` exits 0; `flutter test` exits 0.
- [ ] `main.dart` diff append-only.
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Interrupting one track of a playing timeline via `set` doesn't behave as
  described (e.g. the whole timeline halts or the track can't rejoin) — this
  is an engine-behavior question the maintainer must rule on; do NOT patch
  around it in the example with timers or state flags.
- The per-letter track list makes the timeline exceed what `TimelineLanes`
  can render and grouping doesn't resolve it cleanly.
- The 'Archivo' variable font doesn't support the needed `wght`/`wdth` axes
  in this app (title_slide.dart:147-153 suggests it does — verify early).
- Any need to touch `packages/motor/lib/`.

## Maintenance notes

- Plan 005 places this page as the closer of the "GESTURES × TIMELINES"
  section and features it on the home grid.
- The re-play-after-interrupt behavior (step 2) is the most likely place for
  engine edge cases; whatever approach ships, comment it — future engine
  changes to timeline resumption will interact here.
- Reviewer: run it. Judge causality (does everything read as a consequence
  of the landing?) and the interrupt feel (does entrance velocity merge with
  gesture velocity, or snap?). The behavioral test only pins crash-freedom
  and end states.
