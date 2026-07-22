# Plan 002: Rebuild Arc 1 — the "Feel the difference" sheet arc + 2D photo flick

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED (four new interactive pages; feel matters and is hard to gate)
- **Depends on**: none (parallel-safe with plan 001)
- **Category**: dx / docs (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

The current intro arc ("WHY PHYSICAL MOTION", six pages) fails its job. The
maintainer's verdict, confirmed by code reading and a design review:
dots-on-rails *look* like sliders but reject touch (the worst possible first
impression for a motion library whose thesis is "input and motion are one
system"); the Curve Trap page re-targets a 700ms ease-in-out curve on every
drag frame, so it feels like a broken slider instead of demonstrating the
trap; the 2D page clamps drags to a square but animates the release
unclamped, so cards fling through walls; and three separate spring pages
(The Spring / Carry the Momentum / Motion Character) fragment one lesson
across disjointed cards. This plan replaces all six pages with four, each
carrying exactly one lesson, built around one recurring real-world artifact —
a bottom sheet in a mini phone frame — that switches deliberately to a photo
flick-dismiss when the arc graduates to 2D.

## Current state

Pages being REPLACED (do not delete them in this plan — plan 005 owns
deletion and home-grid rewiring; this plan only ADDS new pages and routes):

- `packages/motor/example/lib/pages/why_motion.dart` — two dots on rails,
  button-toggled instant vs. animated.
- `packages/motor/example/lib/pages/curve_trap.dart` — rail handle +
  duration slider. The jank mechanism, for reference (every drag update
  restarts a curve from standstill):

```58:62:packages/motor/example/lib/widgets/motion_track.dart
  void _aim(double target) {
    widget.controller.animate([
      widget.track.to(target.clamp(0.0, 1.0), motion: widget.motion),
    ]);
  }
```

- `packages/motor/example/lib/pages/the_spring.dart` — spring visualizer +
  duration/bounce sliders. NOTE its description claims "carrying whatever
  speed you let go with" but the code never injects drag-end velocity — the
  replacement page must actually do what this one only claimed.
- `packages/motor/example/lib/pages/interruptible_motion.dart` — spring vs.
  curve on the same janky rail, with a live velocity readout worth keeping.
- `packages/motor/example/lib/pages/motion_character.dart` — four columns,
  each tap-to-launch *independently* (comparison without a shared stimulus).
- `packages/motor/example/lib/pages/two_dimensions.dart` — the broken 2D
  demo. The bug, for reference (drag clamped to a square; release animates
  unclamped):

```61:69:packages/motor/example/lib/pages/two_dimensions.dart
  void _onPanUpdate(DragUpdateDetails d, Size field) {
    final limit = field.shortestSide / 2 - 40;
    final next = _controller.value(_pos) + d.delta;
    final clamped = Offset(
      next.dx.clamp(-limit, limit),
      next.dy.clamp(-limit, limit),
    );
    _controller.set([_pos.value(clamped)]);
  }
```

Conventions to match:

- Every page uses `ExamplePage(title:, description:, action:, child:)` from
  `packages/motor/example/lib/widgets/example_scaffold.dart`, `Surface` /
  `Stage` containers, and closes with `TakeawayText('...')` (monospace
  caption). Read that file first.
- Theme via `ExampleTheme.of(context)`; trajectory graphs via
  `TrajectoryLine` (from `package:example_design/example_design.dart`, used
  in `motion_track.dart:86-90`) and `ValueRecordingNotifier`
  (`packages/motor/example/lib/widgets/value_recording_notifier.dart`).
- Routes are registered in `packages/motor/example/lib/main.dart` via the
  `_route(name, path, builder)` helper (`main.dart:39-45`) and pages carry
  `static const routeName`.
- Idiomatic motor: tracks declared as fields with `Track(.single, initial: 0.0)`,
  dot-shorthand steps (`_pos.to(target, motion: .smoothSpring())`),
  `controller.set([...])` for gesture-following, `controller.animate([...])`
  for targets. See `packages/motor/example/lib/pages/toggle.dart:117-134` for
  the drag→set→release-carries-velocity idiom, including its two excellent
  comments — replicate that commenting standard.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0, "No issues found!" |
| Tests   | `cd packages/motor/example && flutter test` | all pass |

## Scope

**In scope**:
- `packages/motor/example/lib/pages/instant_vs_animated.dart` (create)
- `packages/motor/example/lib/pages/curve_trap_escape.dart` (create)
- `packages/motor/example/lib/pages/spring_character.dart` (create)
- `packages/motor/example/lib/pages/photo_flick.dart` (create)
- `packages/motor/example/lib/widgets/phone_frame.dart` (create — shared mini
  device frame + demo sheet, used by the first three pages)
- `packages/motor/example/lib/main.dart` (APPEND routes only — do not remove
  or reorder existing routes/cards; plan 005 owns the rewrite)
- `packages/motor/example/test/pages_smoke_test.dart` (append entries for the
  four new pages)

**Out of scope**:
- Deleting the old six pages or their home cards (plan 005).
- `packages/motor/lib/` — example-only change.
- The timeline-lanes widget (plan 001) — Arc 1 does not use it.

## Git workflow

- Isolated worktree; branch `agent/example-002-arc1`.
- Conventional commits, one per page is fine:
  `feat(motor_example): add instant-vs-animated sheet page`.
- Do NOT push or open a PR.

## Design spec (per page — these interaction rules are the product)

**Affordance rules for the whole arc** (from the design review; violating
these recreates the old bugs): tappables look like buttons; nothing that
looks draggable is tap-only; the sheet gets a grabber pill ONLY from page 3
on — the grabber's first appearance is the signal "now you can touch it."

### Shared widget: `PhoneFrame` + `DemoSheet` (`widgets/phone_frame.dart`)

- `PhoneFrame({required Widget child, double? width})`: a mini device frame —
  rounded rect (~9:19.5 aspect, ~180–220px wide), hairline border
  (`t.border`), solid surface fill, subtle status-bar hint, `ClipRRect`ed
  content. It exists so the sheet has a visible "offscreen" to enter from
  (the page itself scrolls, so sheets need their own stage).
- `DemoSheet({required double value, bool grabber = false, Widget? child})`:
  a bottom sheet surface positioned by `value` (0 = fully offscreen below the
  frame, 1 = open at ~70% frame height), rounded top corners, optional
  grabber pill, plus a scrim whose opacity follows `value`. The sheet is
  *dumb* — pages own the controllers and pass the animated value in. Do not
  clamp overshoot away: springs overshooting past 1 should visibly
  overshoot (translate past the rest position), that's the point.

### Page 1: "Instant vs. Animated" (`instant_vs_animated.dart`, route name `Instant vs. Animated`)

- Two `PhoneFrame`s side by side, labeled `Instant` and `Animated` (labels in
  the established 16px w500 style, cf. `why_motion.dart:_Panel`).
- ONE button ("Open sheet" / "Dismiss" toggling) fires BOTH simultaneously —
  this lesson is a comparison and needs both in view at once.
- Left frame: state swap. `controller.set([sheet.value(target)])` — sheet
  and scrim appear fully-formed in one frame. It must be exactly what a
  no-animation app ships — not an artificial strawman.
- Right frame: `controller.animate([sheet.to(target, motion: .smoothSpring())])`
  — sheet springs, scrim fades with it.
- Use ONE `TrackController` with two tracks (`_instantSheet`, `_animatedSheet`)
  so the code contrast is a single line: `set` vs `animate`. Put that
  contrast in a code-hint caption on the page (cf. `why_motion.dart`'s
  `codeHint` strings).
- Also allow tapping each frame's scrim to dismiss that frame's sheet (honest
  affordance; still tap-only).
- Takeaway text: motion is how a user keeps their place; `set` and `animate`
  are the same API surface.

### Page 2: "The Curve Trap — and the escape" (`curve_trap_escape.dart`, route name `The Curve Trap`)

- ONE `PhoneFrame` with the sheet. NO dragging on this page at all — the
  interrupt generator is discrete: an "Open/Close" button (tap it again
  mid-flight) and a "Reverse at 40%" button that programmatically fires the
  reversal at a deterministic mid-flight moment so curve and spring get an
  identical stimulus.
- A `CupertinoSlidingSegmentedControl` toggling `CurvedMotion(700ms, Curves.easeInOut)`
  vs `CupertinoMotion.smooth(duration: 700ms)` (mirror the segmented control in
  `interruptible_motion.dart:63-72`).
- Below the frame: a live graph (reuse `ValueRecordingNotifier` +
  `TrajectoryLine` exactly as `the_spring.dart:69-80` does) recording the
  sheet's position every frame — with TWO traces: position AND velocity. The
  position kink is subtle; the velocity discontinuity is stark. Read velocity
  via `controller.velocity(track)` (see `interruptible_motion.dart:88`). If
  `TrajectoryLine` can't overlay two traces, stack two thin graph strips.
- Behavior being demonstrated (verify it reads on screen): with the curve,
  tapping Close mid-flight makes the sheet dead-stop and ease the other way
  from a standstill — visible hesitation and a velocity cliff to zero. With
  the spring, the reversal is one fluid arc and the velocity trace is
  continuous.
- Takeaway text: a curve is a fixed shape on a fixed clock — it does not know
  you were moving. A spring is re-solved every frame from live position and
  velocity.

### Page 3: "Spring Character" (`spring_character.dart`, route name `Spring Character`)

- The sheet GROWS ITS GRABBER here — first draggable page. Drag the sheet;
  drag maps 1:1 to `controller.set([...])` (recording live velocity); on
  release, `controller.animate([sheet.to(target)])` with NO explicit
  `withVelocity` — the controller carries tracked velocity (copy the idiom
  and the comment style from `toggle.dart:117-134`). Fling up/down chooses
  the target by velocity sign above a threshold, else nearest (cf.
  `toggle.dart:124-134`).
- `LabeledSlider`s (existing widget, `widgets/labeled_slider.dart`) for
  duration (150–1200ms) and bounce (0–1) feeding a
  `CupertinoMotion(duration:, bounce:)` used on release.
- A preset row: four small buttons — `.smooth()`, `.bouncy()`,
  `MaterialSpringMotion.standardSpatialDefault()`,
  `.expressiveSpatialDefault()` — that set the sliders/motion to the preset.
  All presets act on the SAME sheet responding to the SAME gesture, so
  character differences are felt on identical stimuli (this replaces the old
  four-independent-columns page, whose flaw was no shared stimulus).
- Keep a small settle-trace graph (same `ValueRecordingNotifier` pattern) so
  tuning bounce visibly changes the settle shape.
- Takeaway text: two numbers are a personality — and the spring listens to
  your hand: release velocity flows straight into the simulation.

### Page 4: "More Than One Dimension" (`photo_flick.dart`, route name `More Than One Dimension`)

- New artifact, deliberately: a photo viewer flick-dismiss. A small grid of
  3–4 placeholder "photos" (styled rects — match `_Card` in
  `two_dimensions.dart:171-189` for the container language); tapping one
  "opens" it centered and large in a `Stage`.
- Drag the opened photo freely — NO bounds, no clamping anywhere (the old
  page's drag-clamp/release-fling contradiction is the bug being retired).
  Drag = `controller.set([_pos.value(next)])`; release =
  `controller.animate([_pos.to(home, ...)])` with the gesture velocity
  (`d.velocity.pixelsPerSecond` → `withVelocity:`), where `home` is the
  center. If the release velocity projects past a dismiss threshold
  (`FrictionMotion(...).project(from:, velocity:, converter: .offset)`,
  cf. `card_stack.dart:101-108`), the photo instead animates offscreen and
  shrinks back to its grid slot (a simple "closed" state swap after the
  fling completes is fine — keep it minimal).
- THE MONEY SHOT — per-axis projections: draw the photo's X projection as a
  dot sliding on a horizontal axis line at the bottom of the stage and its Y
  projection on a vertical axis line at the left, each leaving its own short
  1D fading trace. A toggle "Independent axes" switches the return spring
  from a single `motion:` to
  `motionPerDimension: [CupertinoMotion.snappy(), CupertinoMotion.bouncy(extraBounce: .35)]`
  (same motions as the old page, `two_dimensions.dart:31-34`). With it on,
  the user SEES the Y dot still oscillating after the X dot has parked.
- Do NOT declare a track-default motion that every call then overrides (the
  old page's `_pos` had a dead `motion: .bouncySpring()` — declare the track
  without a default, or actually use the default).
- Takeaway text: one Offset track, one spring per axis — velocity is
  preserved per dimension, which a single-clock curve cannot express.

## Steps

### Step 1: Build `PhoneFrame` + `DemoSheet`

As specced. Verify visually via the widget being usable in a scratch test if
needed, but the gate is analyzer-clean.

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0.

### Step 2: Page 1 (Instant vs. Animated)

**Verify**: analyzer clean; add smoke-test entry
`'Instant vs. Animated': () => const InstantVsAnimatedPage()` to the map in
`test/pages_smoke_test.dart:33-54`; `flutter test test/pages_smoke_test.dart`
→ passes.

### Step 3: Page 2 (Curve Trap + escape)

Additionally write one behavioral widget test in the smoke test file: pump
the page, tap Open, pump ~200ms, tap Close, pump to settle, expect no
exception AND (curve mode) expect the recorded velocity trace to contain a
sign flip/discontinuity — if asserting on the trace is impractical from
widget-test level, a no-exception interaction test is acceptable; note the
downgrade in your report.

**Verify**: `flutter test test/pages_smoke_test.dart` → passes.

### Step 4: Page 3 (Spring Character)

**Verify**: analyzer clean; smoke entry added; `flutter test` passes.

### Step 5: Page 4 (Photo flick)

Include a behavioral test: open a photo, `tester.fling` it, pump to settle,
expect it returned home (its center back at the stage center) and no
exception — this pins the "no fling-through-walls, returns home" contract
that the old page broke.

**Verify**: `flutter test test/pages_smoke_test.dart` → passes.

### Step 6: Register routes

Append four `_route(...)` entries in `main.dart`'s `motorRoutes` list (after
the existing "why" routes; exact position doesn't matter — plan 005 rewrites
the ordering). Do NOT add home cards — plan 005 owns the home grid.

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0
AND `flutter test` → all pass.

## Test plan

Covered in steps: four smoke entries + two behavioral tests (curve-trap
interaction, photo-returns-home), modeled on the existing style in
`pages_smoke_test.dart` (`testWidgets`, manual `tester.pump` loops with 32ms
frames — see `pages_smoke_test.dart:26-30`).

## Done criteria

- [ ] Four new pages + `phone_frame.dart` exist and follow the affordance
      rules (no grabber before page 3; page 2 has no drag surface).
- [ ] Page 3 actually carries release velocity into the spring (grep: the
      release handler contains `animate` with no `withVelocity` after a
      drag that used `set`, OR explicit `withVelocity:` from gesture — either
      idiom, but the velocity must flow).
- [ ] Page 4 has no positional clamping in any drag handler
      (`grep -n "clamp" packages/motor/example/lib/pages/photo_flick.dart`
      shows no clamping of the drag position; clamping opacity etc. is fine).
- [ ] `dart analyze --fatal-infos` exits 0; `flutter test` exits 0 with the
      new entries present.
- [ ] `main.dart` diff is append-only for routes (no removals/reorders).
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- `TrajectoryLine`/`ValueRecordingNotifier` genuinely can't express the
  two-trace graph on page 2 even as stacked strips.
- The sheet-in-frame layout can't work inside `ExamplePage`'s scroll view
  without gesture conflicts you can't resolve with standard
  `GestureDetector` configuration.
- You find yourself wanting to modify `packages/motor/lib/` for any reason.
- Existing smoke tests break in ways unrelated to your added entries.

## Maintenance notes

- Plan 005 deletes the six old pages and rewires the home grid to point at
  these four; keep `routeName` strings stable ('The Curve Trap' and 'More
  Than One Dimension' intentionally reuse the old display names).
- The `PhoneFrame`/`DemoSheet` pair is intentionally page-owned-state and
  dumb; if a later page needs a self-managing sheet, extend there, not here.
- Reviewer: judge feel by running the app (`flutter run` in
  `packages/motor/example`), not just tests — page 2's "visible hesitation
  vs. fluid arc" contrast is the product.
