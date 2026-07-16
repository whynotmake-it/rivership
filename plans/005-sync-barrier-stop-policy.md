# Plan 005: Define and implement the sync-barrier policy for stopped participants

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 1a2538f..HEAD -- packages/motor/lib/src/controllers/track_controller.dart packages/motor/lib/src/step.dart packages/motor/test/src/sync_step_test.dart`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S–M
- **Risk**: MED (stricter release rules can deadlock if cleanup is missed)
- **Depends on**: plans/001-pingpong-sync-seek-characterization-tests.md
  (landed as `f52de64`; its B12 test is rewritten here). Plans 014, 015, and
  016 have also landed and reshape this plan's surroundings — see "New
  stakeholders" below.
- **Category**: bug
- **Planned at**: commit `1a2538f`, 2026-07-16 (originally `d36d4cb`,
  2026-07-14)
- **Refreshed**: 2026-07-16 against `1a2538f` — re-excerpted `_tick`,
  `_hardStop` (which no longer sets `completed` since plan 016), and
  `_mergeTokenParticipants` with current line numbers; corrected the B12
  description (its two-track scenario cannot distinguish the new policy — it
  must be rewritten, not flipped); extended Step 1 to also consolidate the
  inline prune loop plan 014 added to `forgetTrack`; added the plan-015
  legacy-semantics gate and plan-016 status-semantics gate as verification
  gates and STOP conditions; scoped the `plans/005` grep done-criterion to
  `sync_step_test.dart` (plan 001 also left unrelated `plans/005` markers in
  `track_controller_scrub_resume_test.dart`).

## Why this matters

Sync barriers keep independent tracks in lockstep: a track reaching
`Step.sync(token:)` waits until every participant of that token arrives, then
all are released together. The current readiness rule counts any participant
that is *not animating* as "arrived". Combined with `stop()` not pruning
`_tokenParticipants`, this means: hard-stopping one participant before it
reaches the barrier instantly releases every other track waiting on that token
— they continue while visually out of lockstep, which is exactly what sync
barriers exist to prevent. The behavior is accidental (a deadlock-avoidance
shortcut), not documented, and surprising.

The chosen policy (see "Decision" below): **a stopped participant is removed
from the barrier's participant set; remaining participants still wait for each
other.** This keeps the deadlock-avoidance property (a token whose only
missing participant was stopped releases as soon as the remaining tracks
arrive) while never releasing a barrier *early*.

## Current state

`packages/motor/lib/src/controllers/track_controller.dart`.

The readiness rule inside `_tick`:

```554:577:packages/motor/lib/src/controllers/track_controller.dart
    for (final token in syncTokens) {
      final participants = _tokenParticipants[token];
      if (participants == null) continue;

      // Release when every track that participates in this token is either
      // waiting at the barrier for this token, or no longer animating.
      final allReady = participants.every((track) {
        final slot = _slots[track];
        if (slot == null) return true;
        if (!slot.isAnimating) return true;
        return slot.isWaitingForSync && slot.syncToken == token;
      });
      if (allReady) {
        for (final track in participants) {
          final slot = _slots[track];
          if (slot != null &&
              slot.isWaitingForSync &&
              slot.syncToken == token) {
            slot.releaseSync();
          }
        }
        onSyncReleased(token);
      }
    }
```

`stop()` paths that fail to prune participants. Note that since plan 016,
`_hardStop` is **status-silent**: it does not set `_status`, does not call
`_checkStatusChanged()`, and must stay that way (see "New stakeholders"):

```310:327:packages/motor/lib/src/controllers/track_controller.dart
  TickerFuture _hardStop(List<Track>? tracks) {
    if (tracks == null) {
      for (final slot in _slots.values) {
        slot.stop(canceled: true);
      }
      _activeTracks.clear();
    } else {
      for (final track in tracks) {
        _slots[track]?.stop(canceled: true);
        _activeTracks.remove(track);
      }
    }
    if (_activeTracks.isEmpty) {
      _ticker?.stop(canceled: true);
    }
    notifyListeners();
    return TickerFuture.complete();
  }
```

(`_gracefulStop`, lines 329–359, has the same pruning gap: a settling track
replaced its steps with `[Step.to(value)]` via `slot.settle`, so it will never
reach its old barrier, yet it remains in `_tokenParticipants`. Unlike
`_hardStop`, `_gracefulStop` DOES still set
`_status = AnimationStatus.completed` and notify when everything is idle
(lines 345–351) — that is deliberate, 016-sanctioned behavior; keep it.)

Participant bookkeeping — `_mergeTokenParticipants` (lines 488–503) already
implements the correct pattern for the `animate()` path: named tracks are
removed from every token set (lines 492–494), the new animations'
participants are re-added (lines 495–501), and empty tokens are dropped by a
trailing `removeWhere` (line 502). Reuse this shape.

`forgetTrack` (lines 366–376, added by plan 014 for converter swaps) already
contains an **inline copy** of the same prune pattern for a single track
(lines 372–375: a remove loop over `_tokenParticipants.values` plus the
`removeWhere`). Step 1 consolidates it onto the extracted helper.

Important nuance: a track that *finishes all its steps naturally* has passed
its sync steps already, so "finished ⇒ ready" is correct for natural
completion. The bug is only about tracks that were **stopped or redirected**
so their barrier steps will never be reached. After this plan, that case is
handled by pruning at stop-time, so the `!slot.isAnimating` fallback in the
readiness check becomes unreachable for stopped tracks — but keep it as a
safety net for natural completion (a completed slot is idle and its remaining
participants entry, if any, would otherwise deadlock; natural completion means
it passed the barrier, so counting it ready remains correct).

### Characterization test to rewrite

Plan 001's **B12** exists at
`packages/motor/test/src/sync_step_test.dart:397-426`
("B12: stopped participant no longer blocks the barrier") with a
`CHARACTERIZATION` comment referencing plans/005 at lines 418–419. **Its
scenario has only two participants** (trackA stopped at 30 ms before reaching
the barrier; trackB then passes through at ~150 ms). That scenario does NOT
distinguish the old policy from the new one: under the new policy the stopped
trackA is pruned, leaving trackB as the *sole* remaining participant, which
therefore still releases the tick it arrives — the same observable timing the
test asserts today. So B12 is not "flipped"; Step 3 **rewrites** it into a
three-participant scenario where the difference is observable, and removes
the marker comment.

Note: `packages/motor/test/src/controllers/track_controller_scrub_resume_test.dart`
(lines 82, 97) also contains `CHARACTERIZATION` comments referencing
plans/005, but they characterize stop/scrub/resume value-freezing behavior
that this plan does **not** change. Leave that file untouched (it is out of
scope); mention the stale cross-references in your completion report.

### New stakeholders (landed after this plan was first written)

1. **Plan 015 — `SequenceMotionController` now runs on this engine.**
   `packages/motor/lib/src/controllers/sequence_motion_controller.dart`
   (a `part` of `motion_controller.dart`) builds **single-track** chains that
   alternate `Step.to` and `Step.sync(token: Object())` (`_playChain`, lines
   120–172). Its timing contract — "a single-track barrier releases in the
   same tick it is reached" (doc comment, lines 104–114) — is pinned
   numerically by `test/src/controllers/legacy_sequence_semantics_test.dart`,
   which must pass **unchanged**.

   Why the new policy is a no-op there (reason this through yourself before
   Step 2; if you conclude otherwise, STOP): each token's participant set is
   `{the single track}`. (a) Release timing: the barrier releases when every
   participant waits at it; with one participant that is the tick the track
   arrives — identical before and after this plan. (b) Stopping: pruning
   removes the sole participant, leaving the token empty and dropped;
   previously the stale set lingered but was harmless because the slot was
   stopped. No sibling tracks exist to be released early or late.

2. **Plan 016 — status semantics.** `_hardStop` was deliberately made silent
   ("canceled stops are silent"): it no longer sets `_status = completed` or
   notifies status listeners. Step 2 edits `_hardStop` — it MUST NOT
   reintroduce any status mutation or `_checkStatusChanged()` call there.
   Pinned by `test/src/controllers/status_semantics_test.dart` ("canceled
   TrackController stop is silent"), which must pass **unchanged**.

3. **`onPlaybackCompleted()` (plan 016)** — the `@protected` hook on
   `TrackController` (lines 527–534) is called only from `_tick` (line 582)
   when every track finishes; `PhaseTrackController` overrides it to chain
   looping phase playback. The stop paths never call it, and this plan must
   keep it that way. The synchronous barrier release added in Step 2 keeps
   released tracks in `_activeTracks`, so the ticker keeps running and their
   eventual natural completion still routes through `onPlaybackCompleted` in
   `_tick` — no extra handling needed. One reviewable side effect: the
   release loop calls `onSyncReleased(token)`, so a partial `stop(tracks:)`
   can now fire `PhaseTrackController`'s phase-transition callback
   synchronously from inside `stop()`. That is consistent semantics (the
   remaining tracks really do enter the next phase) — note it in the PR
   description for the reviewer.

## Decision (already made — do not re-litigate)

- `stop(tracks: [...])` (hard or graceful) removes those tracks from every
  `_tokenParticipants` set, dropping now-empty tokens.
- `stop()` with no `tracks` clears `_tokenParticipants` entirely.
- Remaining waiters at a token still wait for all *remaining* participants.
- If pruning leaves a token where every remaining participant is already
  waiting, that barrier releases on the next tick (no extra wake-up machinery
  needed — the ticker is still running because waiters return `false` from
  `slot.tick`).
- Edge case: if *all* remaining participants of a token are waiting and the
  ticker is NOT running (e.g. the stopped track was the only animating one),
  release them synchronously inside `stop()` before deciding whether to stop
  the ticker.

## Commands you will need

| Purpose | Command (from `packages/motor/`) | Expected on success |
|---------|----------------------------------|---------------------|
| Targeted tests | `flutter test test/src/sync_step_test.dart` | all pass |
| Legacy semantics gate (015) | `flutter test test/src/controllers/legacy_sequence_semantics_test.dart` | all pass, zero expectation edits |
| Status semantics gate (016) | `flutter test test/src/controllers/status_semantics_test.dart` | all pass, zero expectation edits |
| Full package tests | `flutter test` | all pass |
| Analyze | `dart analyze --fatal-infos` | exit 0 |

## Scope

**In scope**:
- `packages/motor/lib/src/controllers/track_controller.dart`
- `packages/motor/test/src/sync_step_test.dart`
- `packages/motor/lib/src/step.dart` (dartdoc on `SyncStep` documenting the
  stop policy — 2–3 sentences)
- `packages/motor/CHANGELOG.md`

**Out of scope** (do NOT touch):
- `_track_slot.dart`, `step_playback.dart` — the release mechanics inside a
  slot are fine; only controller-level bookkeeping changes.
- `phase_track_controller.dart` — phase barriers benefit automatically.
- `sequence_motion_controller.dart` / `motion_controller.dart` — the legacy
  controller consumes barriers but must not change; its gate test proves the
  policy is a no-op for single-track chains.
- `test/src/controllers/legacy_sequence_semantics_test.dart` and
  `test/src/controllers/status_semantics_test.dart` — behavior gates; any
  needed edit there is a STOP condition, not a change to make.
- `test/src/controllers/track_controller_scrub_resume_test.dart` — its
  `plans/005` comments describe stop/scrub behavior this plan doesn't change.

## Git workflow

Colocated jj repo: use `jj` for VCS mutations in the main workspace; plain git
in an isolated worktree. Message:
`fix(motor): stopped tracks no longer release sync barriers early`.

## Steps

### Step 1: Extract and reuse participant pruning

In `track_controller.dart`, add a private helper:

```dart
/// Removes [tracks] from every sync-token participant set, dropping tokens
/// left without participants. Stopped/redirected tracks will never reach
/// their old barriers, so they must not hold (or trivially satisfy) them.
void _pruneTokenParticipants(Iterable<Track> tracks) {
  for (final participants in _tokenParticipants.values) {
    participants.removeAll(tracks);
  }
  _tokenParticipants.removeWhere((_, participants) => participants.isEmpty);
}
```

Refactor both existing inline copies of this pattern to call it:

1. `_mergeTokenParticipants` (lines 488–503): replace the leading
   remove-loop (lines 492–494) with `_pruneTokenParticipants(timelineTracks)`
   and delete the trailing `removeWhere` (line 502). Behavior is identical —
   dropping emptied tokens before the re-add loop is safe because the re-add
   uses `??= {}`.
2. `forgetTrack` (lines 366–376, from plan 014): replace its inline prune
   (the loop at 372–374 plus the `removeWhere` at 375) with
   `_pruneTokenParticipants([track])`. This is a small in-scope
   consolidation, not new behavior.

**Verify**: `flutter test test/src/sync_step_test.dart` → all pass (pure
refactor; `forgetTrack`'s coverage is exercised again by the full suite in
Step 4).

### Step 2: Prune on stop

- In `_hardStop`: call `_pruneTokenParticipants(tracks)` for the targeted
  tracks, or `_tokenParticipants.clear()` when `tracks == null`. Do NOT add
  any `_status` assignment or `_checkStatusChanged()` call — canceled stops
  stay silent (plan 016).
- In `_gracefulStop`: same, for the `targets` list (a settling track's new
  steps are `[Step.to(value)]` with no sync steps — it must leave its old
  barriers). Keep its existing completed-status reporting when everything is
  idle (lines 345–351) untouched.
- After pruning in both paths, and **before** the "is everything idle" check
  (`if (_activeTracks.isEmpty)` at line 322 in `_hardStop`, line 345 in
  `_gracefulStop`), release any token whose remaining participants are all
  waiting: iterate `_tokenParticipants` entries; if every participant's slot
  `isWaitingForSync && syncToken == token`, release them (same loop body as
  in `_tick`, including the `onSyncReleased(token)` call). Waiting slots are
  animating and stay in `_activeTracks`, so this also prevents the "stop the
  ticker while others wait" edge case.

**Verify**: `dart analyze --fatal-infos` → exit 0.

### Step 3: Rewrite B12 and add policy tests

In `sync_step_test.dart`:

1. Rewrite B12 (currently lines 397–426; two participants — see Current
   state for why that scenario cannot observe the policy change): use three
   tracks A (fast), B (slow), and C sharing token `#barrier`, stop C
   (`stop(tracks: [c], canceled: true)`) before it reaches the barrier, and
   assert A still **waits** at the barrier until B arrives, then both release
   together. Remove the `CHARACTERIZATION` comment (lines 418–419). Model
   the track/step setup on B11 (lines 354–395), which already uses three
   participants.
2. New: stop the *only* not-yet-waiting participant while the other two wait →
   assert both release promptly (within one pump) rather than deadlocking.
3. New: `stop()` (all tracks) while some wait at a barrier → assert everything
   is idle, no exceptions, and a subsequent `animate` with fresh sync steps
   works (no stale token state).
4. New: graceful stop (`stop(tracks: [a])` without `canceled`) on a
   spring-motion track that has not reached its barrier → assert remaining
   participants are not released early while `a` settles.

**Verify**: `flutter test test/src/sync_step_test.dart` → all pass.

### Step 4: Gates, docs, CHANGELOG

- Run both behavior gates with **zero edits** to their files:
  `flutter test test/src/controllers/legacy_sequence_semantics_test.dart test/src/controllers/status_semantics_test.dart`
  → all pass. If either fails, STOP (see STOP conditions).
- `SyncStep` dartdoc (`step.dart` — doc block at lines 151–163, above
  `class SyncStep` at line 165): add the policy sentence — "Tracks stopped or
  redirected before reaching their barrier are removed from the barrier's
  participant set; remaining tracks keep waiting for each other."
- CHANGELOG "Unreleased" → "### Fixes": stopping a track no longer releases
  sync barriers early for the remaining tracks.

**Verify**: `flutter test` (whole package) → all pass.

## Test plan

Four cases in `sync_step_test.dart` (Step 3), plus the untouched existing sync
suite as the regression net, plus the two untouched behavior gates
(`legacy_sequence_semantics_test.dart`, `status_semantics_test.dart`). Full
suite green.

## Done criteria

- [ ] `flutter test` exits 0
- [ ] `dart analyze --fatal-infos` exits 0
- [ ] `grep -rn "plans/005" packages/motor/test/src/sync_step_test.dart`
      returns no matches (characterization marker resolved; the markers in
      `track_controller_scrub_resume_test.dart` are out of scope and remain)
- [ ] `git diff --stat` shows zero changes to
      `test/src/controllers/legacy_sequence_semantics_test.dart` and
      `test/src/controllers/status_semantics_test.dart`
- [ ] No changes outside the in-scope list (`git status`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back if:

- The excerpts in "Current state" no longer match
  `track_controller.dart` at the cited lines (drift since 2026-07-16).
- `legacy_sequence_semantics_test.dart` fails after Step 2 — that would mean
  the policy is NOT a no-op for single-track chains (contradicting the
  reasoning in "New stakeholders" §1); report the failing expectation and the
  timing delta instead of adjusting either the test or the policy.
- `status_semantics_test.dart` fails — Step 2 leaked a status change into a
  canceled stop; report rather than weakening the test.
- Any existing sync test (B1–B14 range) needs its expectations changed other
  than the B12 rewrite — the policy change should be invisible to scenarios
  without stopped participants.
- The synchronous-release edge in Step 2 requires restructuring `_tick` —
  report a design note instead of refactoring the tick loop.

## Maintenance notes

- The `!slot.isAnimating ⇒ ready` clause in `_tick` remains as the
  natural-completion path; if someone later removes it, tracks that finish
  after passing their barrier would deadlock others — the new tests won't
  catch that unless a natural-completion case is added; consider one in review.
- Plan 002 (pingPong phase loops) landed as `6cd6684`; its reversed-timeline
  phase barriers ride on the same token bookkeeping — the full sync suite in
  Step 4 covers the combination.
- A partial `stop(tracks:)` can now emit a `PhaseTransitioning` callback
  synchronously (via `onSyncReleased`) — flag this to the reviewer.
- The `plans/005` comments in `track_controller_scrub_resume_test.dart`
  become stale once this lands (the behavior they describe is unchanged, but
  the "see plans/005" pointer stops being forward-looking); the maintainer
  may want a follow-up comment sweep — do not do it in this plan.
