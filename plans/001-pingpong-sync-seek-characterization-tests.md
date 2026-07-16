# Plan 001: Pin pingPong, sync-barrier, and seek semantics with characterization tests

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat d36d4cb..HEAD -- packages/motor/lib/src/simulations/step_playback.dart packages/motor/lib/src/controllers/track_controller.dart packages/motor/test/src/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (additive tests only)
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `d36d4cb`, 2026-07-14

## Why this matters

Motor 2.0's playback engine (`StepPlayback`, `TrackController`) has three areas
where the current behavior is load-bearing but not pinned by tests: pingPong
reverse legs with non-`StepTo` steps, sync-barrier edge cases (a participant
stopped or re-animated mid-wait), and the parity between the tick-forward path
(`advanceTo`) and the replay path (`seekTo`/`scrubTo`). Plans 002 (pingPong
support) and 005 (sync stop policy) will modify exactly this machinery. Without
these characterization tests, those fixes land blind and can silently change
behavior the example app and downstream users depend on.

**Important**: these are *characterization* tests. Where you find behavior that
looks wrong (a known example: `Step.at` scheduling on pingPong reverse legs is
believed buggy — see Plan 002), pin the *current* behavior with a
`// CHARACTERIZATION: current behavior, believed incorrect — see plans/002` comment
rather than asserting the desired behavior. Plan 002 will then update those
expectations deliberately.

## Current state

Relevant files:

- `packages/motor/lib/src/simulations/step_playback.dart` — the step engine.
  `advanceTo` (lines 175–212) ticks forward; `seekTo` (lines 218–243) replays
  from zero; `_startReverseStep` (lines 405–439) handles pingPong reverse legs;
  `_moveToScheduledStepIfDue` (lines 441–457) handles `Step.at` scheduling.
- `packages/motor/lib/src/controllers/track_controller.dart` — sync-barrier
  release in `_tick` (lines 515–538); participant bookkeeping in
  `_mergeTokenParticipants` (lines 458–473); `stop` (lines 288–346); `scrubTo`
  (lines 259–264); `resume` (lines 267–273).
- `packages/motor/lib/src/controllers/_track_slot.dart` — per-track slot;
  `scrubTo` delegates to `StepPlayback.seekTo` (lines 94–107).

Key behavior facts verified at planning time:

1. `_startReverseStep` reverses toward the *previous* step's waypoint; for
   `StepHold`/`StepFree`/`SyncStep` in reverse it substitutes a hold at the
   current values (`step_playback.dart:427-438`).
2. `_moveToScheduledStepIfDue` has **no direction guard** — it computes
   `nextStepIndex = _stepIndex + _direction` and fires when
   `elapsedSeconds >= _absoluteTimeFor(at)` (lines 441–457). On reverse legs
   this is believed to mis-schedule (Plan 002 fixes it) — characterize, don't fix.
3. Sync release readiness (`track_controller.dart:521-526`): a participant that
   is `!slot.isAnimating` (stopped/finished) counts as ready. Stopping one
   participant means remaining tracks pass their barrier without waiting.
4. `seekTo` passes sync steps through freely by design (documented at
   `step.dart:161-162`).
5. `advanceTo` with a *smaller* elapsed than last time delegates to `seekTo`
   (`step_playback.dart:177-179`).

Existing tests to model after (conventions: `flutter_test`, fake-time
`tester.pump`, numeric assertions with the `error` constant from
`test/src/util.dart`):

- `packages/motor/test/src/loop_mode_semantics_test.dart` — the structural
  pattern for numeric StepPlayback assertions. E.g.:

```30:54:packages/motor/test/src/loop_mode_semantics_test.dart
    test('loop animates back to the start after the last step', () {
      final p = playback(LoopMode.loop);

      // Forward leg at 99ms of a 100ms linear ramp: exactly 0.99.
      p.advanceTo(0.099);
      expect(p.values.single, closeTo(0.99, error));
      // ...
```

- `packages/motor/test/src/sync_step_test.dart` — TrackController-level sync
  tests (groups labeled B1…D17). Note test B9 ("stop and resume preserves sync
  state", lines 263–309) actually tests `stop(canceled: true)` + fresh
  `animate`, **not** `resume()` — you will rename it in Step 4.
- `packages/motor/test/src/per_dimension_motion_test.dart` — its loop/pingPong
  cases (lines 80–115) only assert `isDone == false`; you will strengthen them.

## Commands you will need

| Purpose | Command (run from `packages/motor/`) | Expected on success |
|---------|--------------------------------------|---------------------|
| Single test file | `flutter test test/src/step_playback_pingpong_test.dart` | all pass, exit 0 |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

(From repo root, `melos test` / `melos analyze` also work — see `AGENTS.md`.)

## Scope

**In scope** (the only files you should modify/create):
- `packages/motor/test/src/step_playback_pingpong_test.dart` (create)
- `packages/motor/test/src/step_playback_seek_parity_test.dart` (create)
- `packages/motor/test/src/sync_step_test.dart` (extend, rename B9)
- `packages/motor/test/src/controllers/track_controller_scrub_resume_test.dart` (create)
- `packages/motor/test/src/controllers/track_controller_stop_settle_test.dart` (extend)
- `packages/motor/test/src/per_dimension_motion_test.dart` (strengthen)

**Out of scope** (do NOT touch):
- Anything under `packages/motor/lib/` — this plan changes zero production code.
- `packages/motor/test/src/widgets/golden/` — no golden updates.
- The legacy sequence tests (`phase_sequence_controller_test.dart` etc.) —
  covered by Plan 007.

## Git workflow

This repo is a colocated jujutsu (jj) repo. If executing directly in it, use
`jj` for VCS mutations (`jj new`, `jj desc -m "..."`) and never mutating `git`
commands. In an isolated worktree, plain git is fine. Commit message style is
conventional commits, e.g. `test(motor): characterize pingPong reverse-leg semantics`.

## Steps

### Step 1: StepPlayback pingPong reverse-leg matrix

Create `packages/motor/test/src/step_playback_pingpong_test.dart` modeled on
`loop_mode_semantics_test.dart`. Use `Motion.linear` so values are exactly
computable. Cases (all with `LoopMode.pingPong`, `MotionConverter.single`,
`start: 0`):

1. `[to(1, linear100), hold(100ms)]` — assert forward values, then that the
   reverse leg first "reverses" the hold (a hold at current value per
   `_startReverseStep` lines 430–437), then animates 1→0, then goes forward again.
   Assert values at explicit timestamps covering all four segments.
2. `[to(1, linear100), at(300ms, 2, linear)]` — forward leg, then reverse.
   Characterize whatever the reverse leg currently does at several timestamps
   and mark with the `CHARACTERIZATION` comment referencing plans/002. Do not
   assert "correct" mirrored behavior.
3. `[free(FrictionMotion(...))]` with a seeded velocity — assert that the
   reverse leg holds at current values (no reverse friction), per
   `_startReverseStep` line 427–437.
4. Multi-step `[to(0.5, linear100), to(1, linear100)]` — assert the reverse leg
   targets the *previous waypoint* (0.5) first, then the initial value (0),
   then forward again.

**Verify**: `flutter test test/src/step_playback_pingpong_test.dart` → all pass.

### Step 2: seekTo / advanceTo parity

Create `packages/motor/test/src/step_playback_seek_parity_test.dart`. For each
of these timelines, construct two `StepPlayback` instances with identical
arguments; drive one with incremental `advanceTo` calls (e.g. steps of 16 ms)
and the other with a single `seekTo(t)`; assert `values`, `velocities` (within
`error`), and `isDone` match at t = mid-segment, at a segment boundary, and
past the end:

1. Plain `[to(1, linear100), hold(50ms), to(0, linear100)]`.
2. A `LoopMode.loop` timeline (parity within the first two cycles).
3. A timeline containing `Step.sync` — expected difference: `seekTo` passes the
   barrier freely while a lone-track `advanceTo` also releases it (single
   participant); assert both and document with a comment citing `step.dart:161-162`.
4. Backward `advanceTo` (advance to 0.15 s, then `advanceTo(0.05)`) — assert it
   matches a fresh `seekTo(0.05)` (delegation at `step_playback.dart:177-179`).

**Verify**: `flutter test test/src/step_playback_seek_parity_test.dart` → all pass.

### Step 3: Sync-barrier edge cases at the controller level

Extend `packages/motor/test/src/sync_step_test.dart` with a new group
(continue the existing B-numbering, e.g. B11–B14), using the existing
widget-test pattern in that file (TrackController + `tester.pump`):

- **B11**: three tracks sharing one token, staggered durations — barrier
  releases only after the slowest arrives; assert values of the fast tracks
  hold at the barrier until release.
- **B12**: two tracks sharing a token; `stop(tracks: [fastTrack], canceled: true)`
  *before* the fast track reaches its barrier — characterize that the slow
  track then passes its barrier without waiting (readiness rule at
  `track_controller.dart:521-526`). Add the `CHARACTERIZATION` comment
  referencing plans/005.
- **B13**: two tracks sharing a token; while track A waits at the barrier,
  `animate([a.to(...)])` redirects it — assert the redirect plays and track B
  (whose participant set was updated by `_mergeTokenParticipants`) passes its
  barrier without deadlock.
- **B14**: a `TrackController` subclass overriding `onSyncReleased` records
  tokens — assert exactly one callback per token release (hook at
  `track_controller.dart:489-495`).

**Verify**: `flutter test test/src/sync_step_test.dart` → all pass.

### Step 4: scrubTo / resume coverage, and fix the B9 mislabel

1. Rename B9 in `sync_step_test.dart` from "stop and resume preserves sync
   state" to "stop(canceled) and re-animate rebuilds sync state" (it never
   calls `resume()`).
2. Create `packages/motor/test/src/controllers/track_controller_scrub_resume_test.dart`:
   - animate a two-track timeline, `stop(canceled: true)` mid-flight, then
     `scrubTo` several timestamps and assert values match a `seekTo`-derived
     expectation; assert the ticker is not running (`isAnimating == false`).
   - after scrubbing, call `resume()` and assert the animation completes to its
     targets.
   - `resync`: mid-animation, call `controller.resync(tester)` with a second
     `TickerProvider` and assert values are preserved and the animation still
     completes.

**Verify**: `flutter test test/src/controllers/track_controller_scrub_resume_test.dart` → all pass.

### Step 5: Partial graceful stop + strengthen weak assertions

1. Extend `track_controller_stop_settle_test.dart`: two tracks (one spring
   motion, one linear); call `stop(tracks: [springTrack])` (no `canceled`) —
   assert the spring track settles gracefully (value keeps changing after the
   stop call) while the linear track continues to its target, and that the
   returned `TickerFuture` completes when everything is at rest.
2. In `per_dimension_motion_test.dart` (lines 80–115), replace the bare
   `expect(playback.isDone, isFalse)` assertions in the loop and pingPong cases
   with numeric per-dimension value assertions at 2–3 timestamps (the two
   dimensions use different motions, so assert they diverge as expected).

**Verify**: `flutter test` (whole package) → all pass.

## Test plan

This plan *is* tests. Final check: `flutter test` from `packages/motor/` passes
with ~20 new test cases across 3 new files and 3 extended files, and
`dart analyze --fatal-infos` is clean.

## Done criteria

- [ ] `flutter test` (packages/motor) exits 0, including all new tests
- [ ] `dart analyze --fatal-infos` (packages/motor) exits 0
- [ ] Every characterization of believed-buggy behavior carries a
      `CHARACTERIZATION` comment naming the follow-up plan (002 or 005)
- [ ] No files under `packages/motor/lib/` modified (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpted line ranges in "Current state" don't match the live code.
- A test you write reveals behavior so broken it cannot be characterized
  deterministically (e.g. non-deterministic values across identical runs).
- You find yourself wanting to change production code to make a test pass —
  that is Plans 002/005's job, not this one's.

## Maintenance notes

- Plans 002 and 005 will deliberately flip the `CHARACTERIZATION`-marked
  expectations; reviewers of those PRs should see the expectation changes as
  part of the diff, which is the point of writing these first.
- The seek-parity harness (Step 2) is reusable for any future `StepPlayback`
  change; keep it generic.
