# Plan 019: Make pause → scrub → resume a first-class, non-rewinding cycle

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 4d16091..HEAD -- packages/motor/lib packages/motor/test`
> Plan 018 (inspection API) may have landed — its additive diffs are
> expected. For anything else, compare the "Current state" excerpts against
> live code; on a mismatch, STOP.

## Status

- **Priority**: P1 (blocks inspector scrubbing)
- **Effort**: M
- **Risk**: HIGH (touches ticker lifecycle and status semantics — both were
  deliberately hardened in 2026; regressions here are subtle)
- **Depends on**: none strictly (parallel-safe with 018), but example/007's
  scrub UI needs both
- **Category**: bug / dx
- **Planned at**: commit `4d16091`, 2026-07-22

## Why this matters

The maintainer wants the timeline inspector to support scrubbing. The engine
already has `scrubTo`/`resume`, but the cycle is broken for interactive use:
**`resume()` after a scrub rewinds playback to the ticker's zero** instead of
continuing from the scrubbed position, and **scrubbing a track past a sync
barrier can stall its peers** (their release check never fires). Fixing both
makes pause → drag playhead → resume work honestly — the interaction a debug
tool needs — and fixes a latent public-API defect independent of the
inspector.

## Current state

Verified at `4d16091`. Paths relative to `packages/motor`.

- The scrub/resume pair:

```269:288:packages/motor/lib/src/controllers/track_controller.dart
  /// Evaluates active tracks at [t] without starting the ticker.
  ///
  /// Seeking treats sync barriers as zero-duration holds and passes through
  /// them freely (see [StepSync]); tracks scrubbed past a barrier will not wait
  /// for their peers.
  void scrubTo(Duration t) {
    for (final track in _activeTracks) {
      _slots[track]?.scrubTo(t);
    }
    notifyListeners();
  }

  /// Resumes the ticker if any slots are active.
  void resume() {
    if (_activeTracks.any((track) => _slots[track]?.isAnimating ?? false)) {
      _status = AnimationStatus.forward;
      _startTicker();
      _checkStatusChanged();
    }
  }
```

- THE REWIND BUG's mechanism: `_startTicker` resets the elapsed mirror when
  the ticker was stopped —

```540:547:packages/motor/lib/src/controllers/track_controller.dart
      return _tickerFuture ??= TickerFuture.complete();
    }
    // A restarted Ticker reports elapsed from zero again (stop() nulls its
    // start time). Reset our mirror so animations started later in the same
    // frame use a correct zero start offset instead of a stale elapsed value.
    _lastElapsed = Duration.zero;
    return _tickerFuture = ticker.start();
```

  After resume, `_tick` feeds slot-local seconds computed from
  `elapsed - _startOffset` (`_track_slot.dart:73–77`) — with a restarted
  ticker, elapsed restarts near zero while `_startOffset` still holds the
  OLD run's offset, so `StepPlayback.advanceTo` receives a time far earlier
  than `_lastElapsedSeconds`, and backward `advanceTo` triggers a re-seek
  from zero (`step_playback.dart:183–185`) → visible rewind.
- Slot state: `_startOffset` (`_track_slot.dart:23`) is the ticker-elapsed
  at which the slot's animation began; slot-local playhead after a scrub is
  `StepPlayback._lastElapsedSeconds` (`step_playback.dart:128`, updated by
  `seekTo`).
- THE BARRIER STALL: `seekTo`'s `_reset()` clears the slot's wait flag and
  sails through barriers (`step_playback.dart:245, 253–265`), but the
  controller's `_tokenParticipants` (line 50) still lists the track. The
  release check in `_tick` (584–607) frees a token only when every
  participant `isWaitingForSync` or is no longer animating; a scrubbed track
  that is mid-flight past the barrier is neither, so a peer waiting at that
  token stalls until the scrubbed track finishes entirely.
  `_releaseWaitingSyncBarriers` (518–533) is only invoked from stop paths.
- Status-semantics constraints you MUST NOT violate (deliberate 2026
  behavior, pinned in `test/src/controllers/status_semantics_test.dart`):
  canceled stops are silent; looping phase playback reports exactly one
  `forward` across cycles; graceful stop reports one `completed` after
  settling. `resume()` today sets `_status = forward` + notifies — a
  pause/resume cycle must not produce spurious `completed`/`forward` pairs
  beyond the single `forward` a genuine resumption implies.
- Existing characterization tests to keep green and extend:
  `test/src/controllers/track_controller_scrub_resume_test.dart` (scrub
  mid-animation, scrub-after-canceled-stop is a no-op, resume, resync) and
  `test/src/step_playback_seek_parity_test.dart` (seekTo/advanceTo parity).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Deps    | copy maintainer `pubspec.lock` to worktree root, then `flutter pub get` (repo root) | exit 0 |
| Analyze | `cd packages/motor && dart analyze --fatal-infos` | exit 0 |
| Tests   | `cd packages/motor && flutter test` | all pass |
| Focused | `flutter test test/src/controllers/track_controller_scrub_resume_test.dart test/src/controllers/status_semantics_test.dart` | all pass |
| Example gate | `cd packages/motor/example && dart analyze --fatal-infos && flutter test` | exit 0, all pass |

## Scope

**In scope**:
- `packages/motor/lib/src/controllers/track_controller.dart` (pause(),
  resume() re-basing, post-scrub barrier re-check)
- `packages/motor/lib/src/controllers/_track_slot.dart` (offset re-basing
  helper)
- `packages/motor/test/src/controllers/track_controller_scrub_resume_test.dart`
  (extend)
- `packages/motor/CHANGELOG.md`

**Out of scope**:
- `step_playback.dart` — the seek machinery is correct; the bugs are at the
  controller/ticker layer. If you believe otherwise, STOP and report.
- The inspection API (plan 018) and the example app.
- Any change to scrub-through-barrier semantics themselves (pass-through is
  documented API; we fix the PEER stall, not the pass-through).
- Live scrubbing while the ticker runs (deliberately out of scope for v1).

## Design (what to build)

1. **`pause()`** — new public method: stops the ticker WITHOUT clearing any
   playback state (unlike `stop`, which settles or hard-stops tracks).
   Status: dispatch no status event on pause (pausing is an
   inspection/authoring act, not an animation outcome — mirroring how
   canceled stops are silent). `isAnimating` semantics: the ticker is not
   ticking, so `isAnimating` (which reflects ticker activity — verify at
   line 72) will read false while paused; document this on the method.
2. **Resume re-basing** — `resume()` must continue from each slot's current
   position. Mechanism: before restarting the ticker, re-base every active
   slot's `_startOffset` so that `newTickerElapsed(=0) - _startOffset ==`
   the slot's current local playhead. I.e. `_startOffset = -localPlayhead`
   (negative Durations are valid). Add a slot method
   (`rebaseTo(Duration tickerElapsed)` or similar) that reads its playback's
   `_lastElapsedSeconds`; do the arithmetic in one place, with a comment
   explaining the axis math. `resume()` keeps its existing single `forward`
   status dispatch — but ONLY when the ticker was actually stopped
   (resuming a running controller stays a no-op; verify current guard).
3. **Post-scrub barrier re-check** — after `scrubTo` seeks slots, re-run the
   barrier release logic so peers don't stall: factor the token-release
   check out of `_tick` (584–607) into a private
   `_releaseSatisfiedBarriers()` and call it from both `_tick` and the end
   of `scrubTo`. The rule is unchanged: release when every participant
   is waiting or not animating. A scrubbed-past-the-barrier track is
   mid-flight-not-waiting — it must count as *satisfied* for tokens whose
   sync step index is BEHIND its current step index. Determining "behind":
   use the slot's `StepPlayback.currentStepIndex` vs the index of the sync
   step carrying that token in its `_steps` — expose what you need as
   `@internal` on `StepPlayback` (pattern: plan 018's getters; if 018 has
   landed, reuse its views instead of adding duplicates).
4. **Scrub clamping** — `scrubTo` beyond the plan's end currently leaves a
   half-cleared state (slot idle but still in `_activeTracks`, no
   status/complete, stopped controller stuck in-between). Clamp or complete:
   when a seek lands every simulation at done, run the same completion path
   `_tick` uses (status `completed` unless `onPlaybackCompleted()` claims
   it; clear `_activeTracks`; stop ticker if running). Keep it ONE shared
   code path with `_tick`'s completion block — factor, don't duplicate.

## Steps

### Step 1: Characterize the two bugs (red tests first)

Extend `track_controller_scrub_resume_test.dart` with failing tests:
- `resume after scrub continues from the scrubbed position`: play a 1s
  linear two-step plan, pump 200ms, `scrubTo(600ms)`, `resume()`, pump one
  frame → track value must be ≥ its 600ms value (NOT back near 200ms/0).
- `scrubbing past a barrier releases waiting peers`: two tracks sync on
  #meet; scrub the slow track past its barrier while the fast one waits;
  pump → the fast track must proceed (value advances beyond its barrier
  value within a few frames).
- `scrub to end completes cleanly`: scrub beyond total duration →
  `status == completed`, `isAnimating == false`, and a subsequent `animate`
  works normally.

**Verify**: the new tests FAIL on unmodified engine code (run them, record
the failure output), existing tests still pass.

### Step 2: Implement pause() and resume re-basing

Design items 1+2.

**Verify**: the resume-after-scrub test passes; `flutter test
test/src/controllers/status_semantics_test.dart` → all pass unchanged.

### Step 3: Barrier re-check + scrub completion

Design items 3+4.

**Verify**: all step-1 tests pass; full `flutter test` → all pass
(especially `sync_step_test.dart` — barrier policy was hardened by plan 005;
those tests are the guard rail that your release-check factoring changed
nothing for normal playback).

### Step 4: Docs, CHANGELOG, gates

Update `scrubTo`/`resume` dartdoc: the pause→scrub→resume contract, the
barrier pass-through note (already there) plus the new peer-release
behavior, and `pause()`'s silence. CHANGELOG under Unreleased: `FIX: resume()
after scrubTo continues from the scrubbed position instead of rewinding` /
`FIX: scrubbing past a sync barrier no longer stalls waiting peers` / `FEAT:
pause()`.

**Verify**: all command-table gates green, including the example suite.

## Test plan

Step 1's three red tests plus keep-green: `status_semantics_test.dart`
(7 cases), `sync_step_test.dart` (barrier policy), `step_playback_seek_parity_test.dart`,
and the existing scrub/resume suite. Model new tests on the existing file's
structure (manual `tester.pump` with fixed frame durations).

## Done criteria

- [ ] The three new tests pass; their step-1 red run is quoted in the
      executor report.
- [ ] Full motor suite passes; `status_semantics_test.dart` and
      `sync_step_test.dart` UNMODIFIED (`git diff --name-only -- packages/motor/test`
      shows only the scrub/resume test file).
- [ ] `pause()` exists, documented, dispatches no status event.
- [ ] `dart analyze --fatal-infos` exit 0 in motor AND example; example
      tests pass.
- [ ] CHANGELOG updated; status row updated in `plans/README.md`.

## STOP conditions

Stop and report back (do not improvise) if:

- Making resume-continue work requires changing `step_playback.dart` control
  flow (backward `advanceTo` re-seek, `_reset`) — the fix belongs at the
  offset layer; if it provably can't live there, report the analysis.
- Any `status_semantics_test.dart` or `sync_step_test.dart` case needs
  modification — those pin deliberate semantics; changing them is a
  maintainer decision.
- The "satisfied barrier" rule (design item 3) turns out ambiguous for
  pingPong reverse legs or `.at` steps — report the ambiguous case with a
  concrete timeline instead of picking silently.
- Drift at the excerpted locations.

## Maintenance notes

- Plan example/007's scrub UI is the consumer: it will call
  `pause()` → repeated `scrubTo` → `resume()`. If you change that contract,
  update that plan.
- The factored `_releaseSatisfiedBarriers()` is now the ONLY barrier-release
  site; future barrier work (e.g. parent plans 005/017 follow-ups) lands
  there.
- Reviewer: watch for spurious status notifications in the pause/resume
  cycle — the status dedup (`_checkStatusChanged`) hides double-sets from
  listeners but the sequence still matters for `AnimationStatus` consumers.
