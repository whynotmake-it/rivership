# Plan 005: Restructure the home, execute the kill list, make the arc navigable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/example/README.md` — unless a reviewer dispatched you and told
> you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 93af2da..HEAD -- packages/motor/example`
> Plans 001–004 MUST have landed (9 new pages + lanes widget). Verify the
> nine new page files listed under "Current state" exist before starting; if
> any is missing, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (large deletion + full home rewrite; easy to leave dangling refs)
- **Depends on**: plans/example/002, 003, 004
- **Category**: dx / docs (example app)
- **Planned at**: commit `93af2da`, 2026-07-22

## Why this matters

After plans 002–004 land, the app contains both the new teaching arc and all
the old pages. This plan cuts over: it deletes the twelve killed pages,
rewrites the home grid into four narrative sections with chapter numbers,
adds "next →" navigation so the arc reads as a path instead of a card salad
(the maintainer's "disjointed" complaint is partly navigation), and replaces
the example's boilerplate README. After this plan the app IS the redesigned
app.

## Current state

**Pages that must EXIST when you start** (from plans 002–004), with their
`routeName` constants:
- `pages/instant_vs_animated.dart` (`Instant vs. Animated`)
- `pages/curve_trap_escape.dart` (`The Curve Trap`)
- `pages/spring_character.dart` (`Spring Character`)
- `pages/photo_flick.dart` (`More Than One Dimension`)
- `pages/meet_tracks.dart` (`Meet Tracks`)
- `pages/timelines_and_steps.dart` (`Timelines & Steps`)
- `pages/sync_barriers.dart` (`Sync Barriers`)
- `pages/phases.dart` (`Phases`)
- `pages/boarding_pass.dart` (route name per plan 004)

**Pages to DELETE** (files + routes + home cards + smoke-test entries):
- `pages/why_motion.dart`, `pages/curve_trap.dart`, `pages/the_spring.dart`,
  `pages/interruptible_motion.dart`, `pages/motion_character.dart`,
  `pages/two_dimensions.dart` (replaced by Arc 1)
- `pages/now_playing.dart` (the named anti-pattern), `pages/thermostat.dart`,
  `pages/title_slide.dart`, `pages/loaders.dart` (ideas migrated in plans
  003/004), `pages/drawer.dart`, `pages/accordion.dart`
- Widgets that become orphaned by those deletions — verify before deleting
  each (`grep -rn "<name>" packages/motor/example/lib packages/motor/example/test`):
  - `widgets/motion_track.dart` (used only by curve_trap + interruptible_motion today)
  - `widgets/spring_visualizer.dart` — CAREFUL: `main.dart:27` imports it for
    the home `_SpringPreview` vignette and plan 002's spring_character page
    may reuse `SpringVisualizer`/`SpringPainter`. Delete ONLY if unused after
    the home rewrite; otherwise keep.
  - `widgets/labeled_slider.dart` and `widgets/value_recording_notifier.dart`
    are used by the NEW pages — do not delete.

**Pages KEPT** (unchanged by this plan): toggle, snap_carousel, toast,
payment_success, card_stack, pull_to_refresh, picture_in_picture,
draggable_icons (maintainer explicitly spared Draggable Icons).

**Files that encode the old structure**:
- `packages/motor/example/lib/main.dart` — routes (`motorRoutes`,
  lines 47–89), home page with four sections (`_whyCards`, `_everydayCards`,
  `_composeCards`, `_gestureCards`, lines 198–423) and ~20 private preview
  vignette classes (lines 482–1190). All of this gets rewritten.
- `packages/motor/example/test/pages_smoke_test.dart` — one entry per page
  (lines 33–54) plus behavioral tests for Payment Success (66) and
  Thermostat (87 — Thermostat dies, its test goes too).
- `packages/motor/example/lib/widgets/example_scaffold.dart` — `ExamplePage`
  (lines 5–81) has no footer/next-link support yet; you will add it.
- `packages/motor/example/README.md` — stock Flutter boilerplate ("A new
  Flutter project", tutorial links, a Localization section referencing arb
  files that don't exist). Replace entirely.
- The apps-level example imports motor's example routes:
  `apps/example/lib/main.dart:26` uses `motorRoutes` — the route list must
  keep working as a `List<NamedRouteDef>` export.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze (example) | `cd packages/motor/example && dart analyze --fatal-infos` | exit 0 |
| Analyze (apps consumer) | `cd apps/example && dart analyze --fatal-infos` | exit 0 |
| Tests   | `cd packages/motor/example && flutter test` | all pass |
| Dangling refs | `grep -rn "why_motion\|the_spring\|interruptible_motion\|motion_character\|two_dimensions\|now_playing\|thermostat\|title_slide\|loaders\|/drawer\|accordion" packages/motor/example/lib packages/motor/example/test` | no matches (note: `curve_trap` is replaced by `curve_trap_escape` — grep for `pages/curve_trap.dart` specifically) |

## Scope

**In scope**:
- Delete the twelve page files + orphaned widgets listed above.
- `packages/motor/example/lib/main.dart` (full rewrite of routes + home)
- `packages/motor/example/lib/widgets/example_scaffold.dart` (add `next`
  footer support to `ExamplePage`)
- The nine new page files + eight kept page files: ONLY to add the
  `next:` footer parameter and (for kept pages) their card copy if it lives
  in the page — do not otherwise modify kept pages (plan 006 owns polish).
- `packages/motor/example/test/pages_smoke_test.dart` (remove dead entries)
- `packages/motor/example/README.md` (rewrite)

**Out of scope**:
- Behavioral changes to any kept page (plan 006).
- `packages/motor/lib/`, `packages/example_design/`.
- `apps/example/` — it consumes `motorRoutes`; keep that export shape so it
  needs no changes. Verify with its analyzer, but do not edit it.

## Git workflow

- Isolated worktree; branch `agent/example-005-restructure`.
- Commits: `refactor(motor_example)!: restructure home around the teaching arc`
  (the deletion commit), plus separate commits for README and navigation.
- Do NOT push or open a PR.

## Target home structure

Four sections, in order, each card showing a chapter number (e.g. `1.2`) in
the existing `index:`-style corner (see `ExampleCard(index: ...)` usage at
`main.dart:199-269` — extend the label to `"1.2"` strings if `index` is an
int; check `ExampleCard`'s API in `packages/example_design/` and use
whatever it supports, adding a `chapterLabel` only if `ExampleCard` already
exposes a suitable slot — do NOT modify example_design):

1. **FEEL THE DIFFERENCE** — Instant vs. Animated · The Curve Trap · Spring
   Character · More Than One Dimension
2. **TRACKS** — Meet Tracks · Timelines & Steps · Sync Barriers · Phases
3. **GESTURES × TIMELINES** — Toggle · Pull to Refresh · Card Stack ·
   Payment Success · Boarding Pass (featured/flagship card)
4. **RECIPES** — Snap Carousel · Toast · Picture in Picture · Draggable Icons

Each card needs: pill label (the page's headline API, e.g. `Track<Offset>`,
`TrackTimeline + sync`), a one-line description stating the LESSON (not the
artifact), and a monochrome preview vignette in the established style
(simple shapes, theme colors — model on the existing `_TogglePreview`,
`main.dart:597-635`). Write new vignettes for the nine new pages; keep the
kept pages' existing vignettes.

**Navigation as a path**: add to `ExamplePage` an optional
`next` parameter (`({String label, String routeName})?` or a tiny value
class). When set, render a right-aligned footer link "next: <label> →" below
the page content that calls `context.navigateTo(NamedRoute(routeName))`
(auto_route is already imported app-wide). Wire the chain: 1.1 → 1.2 → 1.3 →
1.4 → 2.1 → … → 3.5; recipes have no `next`. Sync Barriers and Phases
already point at their payoffs (Payment Success / Card Stack) per plan 003 —
the `next` chain should route Sync Barriers → Phases (the payoff links are
in-content, the footer stays the arc spine).

## Steps

### Step 1: Add `next` footer to `ExamplePage`

**Verify**: `cd packages/motor/example && dart analyze --fatal-infos` → exit 0.

### Step 2: Rewrite `main.dart`

New route list (nine new + eight kept pages), new home with the four
sections, chapter numbers, new vignettes for new pages. Delete the dead
route entries and dead vignette classes.

**Verify**: analyzer clean in BOTH `packages/motor/example` AND
`apps/example`.

### Step 3: Delete dead pages and orphaned widgets

Delete the twelve pages; run the orphan check for each candidate widget
before deleting it.

**Verify**: dangling-refs grep (see commands table) → no matches;
`dart analyze --fatal-infos` → exit 0.

### Step 4: Update the smoke test

Remove dead entries and the Thermostat behavioral test; keep the Payment
Success behavioral test and all tests added by plans 002–004. Every route in
the new `motorRoutes` must have a smoke entry — add any missing kept-page
entries.

**Verify**: `flutter test` → all pass; count check: number of entries in the
smoke map == number of page routes in `motorRoutes` (minus the home route).

### Step 5: Wire the `next:` chain and rewrite the README

README: name of the app, the four sections with one line per page (lesson,
not artifact), how to run (`flutter run` in this directory), and a pointer
to the package README for API docs. Optionally fold in the good FAQ copy
from the deleted accordion page (`accordion.dart:14-36`) as a short FAQ
section — it was well-written motor documentation.

**Verify**: full gate — `dart analyze --fatal-infos` exit 0 in both
packages, `flutter test` all pass.

## Test plan

No new test files; the smoke-test rewrite in step 4 IS the test work. The
count check in step 4 prevents silently unrouted or untested pages.

## Done criteria

- [ ] Twelve dead pages deleted; orphan widgets resolved; dangling-refs grep
      clean.
- [ ] Home shows exactly the four sections in order with chapter numbers and
      per-page vignettes.
- [ ] Every non-recipe page has a working `next:` footer; the chain is
      unbroken from 1.1 to 3.5 (manual click-through or a widget test that
      pumps each page and finds the footer).
- [ ] `README.md` no longer contains "A new Flutter project".
- [ ] `dart analyze --fatal-infos` exits 0 in `packages/motor/example` AND
      `apps/example`; `flutter test` exits 0.
- [ ] Smoke-map count == route count (minus home).
- [ ] Status row updated in `plans/example/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Any of the nine new pages from plans 002–004 is missing or its `routeName`
  differs from this plan's table.
- `ExampleCard` (in `packages/example_design/`) has no usable slot for a
  chapter label and you'd have to modify example_design — report instead.
- `apps/example` breaks in a way not fixable by keeping the `motorRoutes`
  export shape.
- Deleting a "orphaned" widget breaks a NEW page (means plans 002/003 reused
  it — keep the widget and note it).

## Maintenance notes

- Adding a page later means: page file + route + smoke entry + home card +
  splicing the `next:` chain — consider documenting this checklist at the
  top of `main.dart`.
- Plan 006 (kept-page polish) rebases on this; its diffs are confined to
  kept pages' comments/idioms so conflicts should be trivial.
- Reviewer: click through the whole `next:` chain once on a device/simulator;
  the arc-as-path feel is the acceptance test.
