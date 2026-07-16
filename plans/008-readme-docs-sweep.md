# Plan 008: Fix broken README samples, version/SDK inconsistencies, and missing doc notes

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 15e070f..HEAD -- packages/motor/README.md packages/motor/pubspec.yaml packages/motor/lib/src/track_timeline.dart packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/motion.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
> (Refreshed 2026-07-14 against the merged batch-1 stack: plan 007 already
> restructured the README — line numbers below are current; plan 006 already
> delivered the wrapper-cost docs that were originally part of this plan.)

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none (coordinate with Plan 007 if both touch the README —
  execute 007 first or rebase this on it)
- **Category**: docs
- **Planned at**: commit `15e070f` (refreshed; originally `d36d4cb`), 2026-07-14

## Why this matters

Motor is a published pub.dev package; the README is its storefront. Several
samples do not compile as written, the install instruction pins a version that
doesn't exist yet, and the SDK floor contradicts the syntax the examples use.
Separately, three verified sharp edges of the new API are documented only in
the README (or nowhere), not on the types where users hit them: the
value-equality restart semantics of `TrackTimeline`, the
`Animation<TrackValueReader>` shape of `TrackController.value`, and the
by-design "seek passes sync barriers" behavior of `scrubTo`.

## Current state

All facts below verified against commit `d36d4cb`.

README defects (`packages/motor/README.md`):

| Line (current) | Problem | Fact |
|------|---------|------|
| 36 | `motor: ^2.0.0` | `pubspec.yaml:3` says `version: 1.1.0`; 2.0 is unreleased |
| 138–141 | `MaterialSpringMotion(damping: 0.8, stiffness: 500)` | Only `MaterialSpringMotion._(...)` (private) + named token constructors exist |
| 194 | `motion: MaterialSpringMotion.expressiveSpatialDefault,` | Named *constructor*, so this is a constructor tear-off, not a `Motion` — missing `()` |
| 216 (and the sequences-section equivalent) | Claims examples use "Dart's dot-shorthand syntax" | `pubspec.yaml:11` allows SDK `>=3.5.0`; samples won't compile on 3.5–3.9 |
| 216 | Note conflates `Track.to` sugar with `Step.to` shorthand | `scale.to(1, ...)` shortly below is the `Track.to` *method* (`track.dart:77-89`); `.to(...)` inside `offset([...])` is `Step.to` dot-shorthand |
| 336 | "Pass `onTransition` … and `phaseLoop` to auto-advance in a loop" reads as `PhaseTrackBuilder` params | `phaseLoop` is a `TrackPhaseTimeline` field (`track_phase_timeline.dart:54-60`); the builder has no such param |
| 76 | "`NoMotion`" described as "Holds at the **target** value" | `NoMotion.createSimulation` holds at `start` and never reaches the target |
| 533 | `// or Motion.duration(), etc.` | `Motion.duration` is a getter; no such factory exists |

(Line numbers re-verified at commit `15e070f` after plan 007's README
restructure. Re-locate by content if they shift again.)

Missing doc notes (verified locations):

- `TrackTimeline` class dartdoc (`track_timeline.dart:5-9`) says nothing about
  `Equatable` value semantics; the restart-avoidance behavior is documented
  only on `TrackBuilder` internals (`track_builder.dart:131-135`) and README:282.
- `TrackController` (`track_controller.dart:20-21`) extends
  `Animation<TrackValueReader>`; class doc is one line ("Controls a single
  active [TrackTimeline] from a ticker."). Nothing warns that `.value` is a
  *function*, so `Tween`/`.drive()`/`Animation.value`-style composition does
  not apply. (A typed per-track view is a separate design spike — Plan 010;
  this plan only adds the doc note.)
- `TrackController.scrubTo` doc (`track_controller.dart:258`) doesn't mention
  that seeking passes sync barriers freely (documented on `SyncStep`,
  `step.dart:161-162` — cross-reference it).
- `MotionBase` carries the `{@template Motion}` doc describing "the [Motion]
  class" (`motion.dart:9-17`), which is misleading now the root is sealed;
  README:62 tells custom-motion authors to extend "these classes" without
  naming `Motion` vs `FreeMotion` (CHANGELOG:20 has the correct guidance).

Also verified as **correct** (do not "fix"): `Curves.ease` at README:449 is a
real Flutter constant; `MaterialSpringMotion.standardSpatialDefault()` at
README:59 correctly has parens; snapToEnd default docs align with code.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Analyze | `dart analyze --fatal-infos` | exit 0 |
| Full tests | `flutter test` | all pass (docs-only change) |

There is no README snippet-compilation harness in this repo; verification for
README fixes is careful reading plus the greps in Done criteria.

## Scope

**In scope**:
- `packages/motor/README.md`
- `packages/motor/lib/src/track_timeline.dart` (dartdoc only)
- `packages/motor/lib/src/track.dart` (dartdoc only, `TrackAnimation` if needed)
- `packages/motor/lib/src/controllers/track_controller.dart` (dartdoc only)
- `packages/motor/lib/src/motion.dart` (dartdoc only: `MotionBase` blurb)
- `packages/motor/pubspec.yaml` (SDK constraint — see Step 2 decision)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- Any behavioral code change. This plan is 100% docs + one pubspec constraint.
- The README sequence section — Plan 007 already restructured it (landed);
  only fix the defects listed above if they sit inside it.
- Wrapper-cost docs on `scaleTo`/`MotionTrimming` and the README "Tip"
  paragraph — Plan 006 already delivered those (landed); do not duplicate.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Message: `docs(motor): fix broken README samples and add API sharp-edge notes`.

## Steps

### Step 1: Fix the eight README defects

Apply fixes per the table above:

1. Line 36: since the CHANGELOG shows 2.0 is imminent, keep `^2.0.0` but add
   an HTML comment above it: `<!-- TODO(release): verify pubspec version is
   2.0.0 before publishing -->` — OR if the repo owner prefers, change to
   `^1.1.0`. Default to the TODO comment (2.0 branch context).
2. Lines 125–128: replace the fake constructor with a working alternative:

```dart
final customMaterial = SpringMotion(
  SpringDescription.withDampingRatio(ratio: 0.8, stiffness: 500),
);
```

   and a sentence noting `MaterialSpringMotion` itself only exposes the
   official M3 tokens.
3. Line 181: `MaterialSpringMotion.expressiveSpatialDefault` →
   `MaterialSpringMotion.expressiveSpatialDefault()`.
4. Lines 203/346: change the notes to "Dart 3.10+ dot-shorthand syntax; on
   older SDKs write the full form (`Step.to(...)`, `CupertinoMotion.smooth()`,
   `MotionConverter.offset`)" — see Step 2 for the constraint decision.
5. Line 203 (same note): split the sentence — `track.to(value)` is a method on
   `Track`; `.to(...)` inside a step list is shorthand for `Step.to(...)`.
6. Line 323: reword to "…and set `phaseLoop` on the `TrackPhaseTimeline` to
   auto-advance in a loop."
7. Line 68: "**`NoMotion`** - Holds at the current value for an optional
   duration, never reaching the target."
8. Line 591: change comment to `// or Motion.curved(...), etc.`.

**Verify**: `grep -n "expressiveSpatialDefault," packages/motor/README.md` →
no match without `()`; `grep -n "Motion.duration()" packages/motor/README.md`
→ no matches.

### Step 2: Resolve the SDK-constraint contradiction

Decision logic (execute, don't ask): check whether `lib/` source itself uses
dot-shorthands (`grep -rn "= \.\|: \.\w" lib/ --include="*.dart"` is noisy —
instead run `dart analyze` with the current constraint; the package compiled
at `>=3.5.0` so the *library* doesn't need 3.10).

- The library compiles on 3.5 ⇒ do NOT raise the package floor just for docs.
- Instead: label every dot-shorthand README snippet as 3.10+ (Step 1.4 note),
  and verify the example app's own pubspec (`example/pubspec.yaml:11`) already
  pins `^3.10.0` (it does).
- Add one sentence to README Installation: "Code samples in this README use
  Dart 3.10 dot-shorthands; motor itself supports Dart 3.5+."

If, contrary to the above, `dart analyze` on the package fails at the current
floor, STOP and report.

**Verify**: `dart analyze --fatal-infos` (packages/motor) → exit 0.

### Step 3: Add the API sharp-edge dartdoc notes

1. `TrackTimeline` (`track_timeline.dart:5-9`): add — "Timelines compare by
   value (`Equatable`): building an equal timeline on rebuild will not restart
   playback in [TrackBuilder]. Reuse instances or hoist them to fields for
   clarity; equality makes both safe."
2. `TrackController` class doc (`track_controller.dart:20-21`): expand to
   note: it is an `Animation<TrackValueReader>` — [value] is a *reader
   function*, called with a [Track] to get that track's current value. This
   keeps it usable with `ValueListenable`/`ListenableBuilder` infrastructure,
   but it does not compose with `Tween.animate`/`.drive()` the way an
   `Animation<double>` does; read specific tracks via `value(track)` inside a
   listener instead.
3. `TrackController.scrubTo` doc: add "Seeking treats sync barriers as
   zero-duration holds and passes through them freely (see [SyncStep]); tracks
   scrubbed to a time beyond a barrier will not wait for their peers."
4. `MotionBase` (`motion.dart:9-17`): retitle the template body so the root
   doc describes the *family* ("The root of motor's motion family. Concrete
   motions extend [Motion] (target-based) or [FreeMotion] (self-directed);
   this root is sealed.") — keep the `{@template Motion}` name so existing
   `{@macro}` uses still resolve.
5. README line 62 area: name the extension points — "create custom motions by
   extending `Motion` (target-based) or `FreeMotion` (self-directed)".

**Verify**: `dart analyze --fatal-infos` → exit 0; `flutter test` → all pass.

### Step 4: CHANGELOG

Add a **DOCS** entry under "Unreleased" summarizing the README fixes and new
API notes (one line).

**Verify**: `flutter test` → all pass.

## Test plan

Docs-only: the gate is analyzer cleanliness, the full test suite unchanged,
and the greps in Done criteria. Manually re-read each modified README snippet
against the real API signature it calls (constructor parameter names checked
against `motion.dart` / `track.dart`).

## Done criteria

- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `flutter test` exits 0 with zero test-file changes
- [ ] All 8 README defects from the Current-state table fixed (spot-check greps:
      no `MaterialSpringMotion(damping:` in README, no `Motion.duration()`,
      `expressiveSpatialDefault()` has parens)
- [ ] `TrackTimeline`, `TrackController`, `scrubTo`, `MotionBase` dartdoc notes added
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- `dart analyze` fails at the existing SDK floor (means the library already
  requires >3.5 and the pubspec constraint is wrong at a deeper level).
- Plan 007 landed first and rewrote README regions this plan targets — re-read
  and apply only the still-valid fixes; if the sequence section moved lines
  significantly, re-locate by content, not line number.
- You find yourself changing any non-dartdoc code line.

## Maintenance notes

- Before the 2.0 publish: resolve the `TODO(release)` comment at README:36 and
  bump `pubspec.yaml` version together.
- If Plan 010 (`animationFor`) lands, extend the `TrackController` doc note to
  point at the new per-track `Animation<T>` view as the composition path.
