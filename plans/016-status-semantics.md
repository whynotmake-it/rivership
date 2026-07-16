# Plan 016 (retroactive record): Status-semantics fixes

> Executed 2026-07-15 from an inline reviewer brief (no pre-written plan
> file); this file records the finding, the decided semantics, and the
> landed implementation for future reconcile runs. Status: DONE, merged
> into the stack as `8f16cb58` (originally `110ab24` on
> `agent/plan-016-status-semantics`).

## The two findings (surfaced by plan 015's shim analysis)

1. **Canceled stops reported `AnimationStatus.completed`.**
   `TrackController._hardStop` set and notified `completed` even for
   `stop(canceled: true)` — unlike Flutter's `AnimationController`, which
   deliberately stays silent on canceled stops. Symptom: swapping a
   `MotionController`'s converter mid-animation fired a spurious
   `completed`; plan 015's `SequenceMotionController` needed a converter
   override to defend against it.
2. **Looping phase playback flapped status every cycle.**
   `PhaseTrackController` drove loop/pingPong/seamless cycles from a status
   listener keyed on `completed`, so external listeners saw
   `completed → forward` once per cycle. The legacy sequence controller
   held `forward` for a looping sequence's whole life — the correct model.

## Decided semantics

- `stop(canceled: true)`: stops without any status notification; status
  keeps its last reported value; `isAnimating` goes false.
- Graceful settle and natural completion: still report `completed`.
- Looping `playPhases`: external listeners see one `forward` at start and
  nothing between cycles; non-looping playback ends with one `completed`.
- `PhaseTransitioning`/`PhaseSettled` events and `TickerFuture` semantics:
  unchanged (futures are not status notifications).

## Implementation (commit `8f16cb58`)

- `_hardStop` no longer sets/notifies `completed`.
- New `@protected @visibleForOverriding bool onPlaybackCompleted()` on
  `TrackController`, called in `_tick` when all tracks finish, BEFORE the
  status notification. Returning true means "a continuation was started
  synchronously; hide this run boundary from status listeners."
- `PhaseTrackController` replaced its status-listener self-subscription
  with an `onPlaybackCompleted` override: returns true for loop/pingPong/
  seamless continuations, false when genuinely settled (base then reports
  `completed`). The constructor/dispose listener pair was removed.
- New `test/src/controllers/status_semantics_test.dart` (190 lines) pins:
  silent canceled stop; converter swap emits no completion; loop and
  pingPong record exactly `[forward]` over multiple cycles with unchanged
  transition events; non-looping playback reports one `completed`;
  graceful stop still reports `completed`.
- Zero existing-test edits; goldens untouched; 015's semantics gate green.

## Notes for future work

- `SequenceMotionController.converter=` override is now redundant as a
  status defense but still required for sequence bookkeeping — kept.
- Plan 005 (sync-barrier stop policy, still TODO) touches `_hardStop`'s
  surroundings; its executor must rebase over this change and re-run
  `status_semantics_test.dart` plus the legacy semantics gate.
